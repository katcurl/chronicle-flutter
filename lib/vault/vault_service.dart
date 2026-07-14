import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../features/notes/note_document.dart';
import '../models/app_models.dart';
import '../sync/sync_models.dart';
import 'vault_backend.dart';
import 'vault_models.dart';

class VaultService {
  VaultService({VaultBackend? backend}) : _backend = backend ?? VaultBackend();

  static const int backupFormatVersion = 1;
  static const String _indexPath = '.chronicle/vault-index.json';
  static const String _manifestPath = 'manifest.json';

  final VaultBackend _backend;

  Future<VaultStatus> writeMirror(AppData data) async {
    final rootPath = await _backend.resolveRootPath();
    if (rootPath == null || rootPath.isEmpty) {
      return const VaultStatus.unavailable(
        message: 'Файловый Vault недоступен на этой платформе.',
      );
    }

    final built = _buildVaultFiles(data);
    final previousIndexRaw = await _backend.readTextFile(rootPath, _indexPath);
    final previousManagedPaths = _managedPathsFromIndex(previousIndexRaw);
    final currentManagedPaths = built.notePaths.toSet();
    final stalePaths = previousManagedPaths.difference(currentManagedPaths);

    await _backend.writeFiles(
      rootPath: rootPath,
      files: built.files,
      staleManagedPaths: stalePaths,
    );

    return VaultStatus(
      supported: true,
      rootPath: rootPath,
      noteCount: data.notes.length,
      fileCount: built.files.length,
      lastWrittenAt: built.generatedAt,
      message: 'Markdown Vault обновлён без удаления данных из базы.',
    );
  }

  Future<VaultStatus> inspect() async {
    final rootPath = await _backend.resolveRootPath();
    if (rootPath == null || rootPath.isEmpty) {
      return const VaultStatus.unavailable(
        message: 'Файловый Vault недоступен на этой платформе.',
      );
    }

    final raw = await _backend.readTextFile(rootPath, _manifestPath);
    if (raw == null) {
      return VaultStatus(
        supported: true,
        rootPath: rootPath,
        noteCount: 0,
        fileCount: 0,
        message: 'Vault ещё не создавался.',
      );
    }

    try {
      final manifest = jsonDecode(raw) as Map<String, dynamic>;
      return VaultStatus(
        supported: true,
        rootPath: rootPath,
        noteCount: _readInt(manifest['noteCount']),
        fileCount: _readInt(manifest['fileCount']),
        lastWrittenAt: DateTime.tryParse(
          manifest['generatedAt']?.toString() ?? '',
        ),
      );
    } on Object {
      return VaultStatus(
        supported: true,
        rootPath: rootPath,
        noteCount: 0,
        fileCount: 0,
        message: 'Манифест Vault повреждён; его можно пересоздать.',
      );
    }
  }

  Future<VaultStatus?> chooseRootAndWrite(AppData data) async {
    final selected = await _backend.chooseRootPath();
    if (selected == null) {
      return null;
    }
    return writeMirror(data);
  }

  Future<BackupExportResult?> exportBackup({
    required AppData data,
    DeviceIdentity? identity,
  }) async {
    final package = _buildBackupPackage(data: data, identity: identity);
    final fileName = _backupFileName('chronicle-backup');
    final path = await _backend.saveBackup(
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(package.raw)),
    );
    if (path == null) {
      return null;
    }
    return BackupExportResult(
      path: path,
      fileName: fileName,
      preview: package.preview,
    );
  }

  Future<BackupImportPayload?> pickBackup() async {
    final selected = await _backend.pickBackup();
    if (selected == null) {
      return null;
    }
    final raw = utf8.decode(selected.bytes, allowMalformed: false);
    return inspectBackup(raw, sourceName: selected.name);
  }

  BackupImportPayload inspectBackup(
    String raw, {
    String sourceName = 'backup.chronicle',
  }) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Некорректная структура резервной копии.');
    }
    if (decoded['format'] != 'chronicle-portable-backup') {
      throw const FormatException('Это не резервная копия Chronicle.');
    }

    final formatVersion = _readInt(decoded['formatVersion']);
    if (formatVersion < 1 || formatVersion > backupFormatVersion) {
      throw FormatException(
        'Версия резервной копии $formatVersion не поддерживается.',
      );
    }

    final databaseJson = decoded['databaseJson'];
    if (databaseJson is! String || databaseJson.isEmpty) {
      throw const FormatException('В копии отсутствуют рабочие данные.');
    }

    final rawVaultFiles = decoded['vaultFiles'];
    final vaultFiles =
        rawVaultFiles is Map
            ? rawVaultFiles.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
            : <String, String>{};
    final rawChecksums = decoded['checksums'];
    final checksums =
        rawChecksums is Map
            ? rawChecksums.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
            : <String, String>{};

    final expectedDatabaseHash = checksums['database.json'];
    if (expectedDatabaseHash == null ||
        expectedDatabaseHash != _sha256(databaseJson)) {
      throw const FormatException(
        'Контрольная сумма database.json не совпадает.',
      );
    }
    for (final entry in vaultFiles.entries) {
      final expected = checksums[entry.key];
      if (expected == null || expected != _sha256(entry.value)) {
        throw FormatException('Контрольная сумма ${entry.key} не совпадает.');
      }
    }

    final appData = AppData.decode(databaseJson);
    final exportedAt = DateTime.tryParse(
      decoded['exportedAt']?.toString() ?? '',
    );
    if (exportedAt == null) {
      throw const FormatException('Некорректная дата резервной копии.');
    }

    return BackupImportPayload(
      databaseJson: databaseJson,
      sourceName: sourceName,
      preview: BackupPreview(
        formatVersion: formatVersion,
        exportedAt: exportedAt,
        projectCount: appData.projects.length,
        taskCount: appData.tasks.length,
        noteCount: appData.notes.length,
        entryCount: appData.entries.length,
        checksumsVerified: true,
        sourceDeviceId: decoded['sourceDeviceId'] as String?,
        sourceDeviceName: decoded['sourceDeviceName'] as String?,
      ),
    );
  }

  Future<String> createEmergencyBackup({
    required AppData data,
    DeviceIdentity? identity,
  }) async {
    final rootPath = await _backend.resolveRootPath();
    if (rootPath == null || rootPath.isEmpty) {
      throw UnsupportedError('Не удалось определить папку Vault.');
    }
    final package = _buildBackupPackage(data: data, identity: identity);
    final fileName = _backupFileName('pre-import-backup');
    return _backend.writeEmergencyBackup(
      rootPath: rootPath,
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(package.raw)),
    );
  }

  _BuiltBackup _buildBackupPackage({
    required AppData data,
    DeviceIdentity? identity,
  }) {
    final generated = _buildVaultFiles(data);
    final databaseJson = data.encode();
    final exportedAt = DateTime.now().toUtc();
    final checksums = <String, String>{
      'database.json': _sha256(databaseJson),
      for (final entry in generated.files.entries)
        entry.key: _sha256(entry.value),
    };

    final payload = <String, dynamic>{
      'format': 'chronicle-portable-backup',
      'formatVersion': backupFormatVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'sourceDeviceId': identity?.deviceId,
      'sourceDeviceName': identity?.displayName,
      'databaseJson': databaseJson,
      'vaultFiles': generated.files,
      'checksums': checksums,
    };
    final raw = const JsonEncoder.withIndent('  ').convert(payload);
    final preview = BackupPreview(
      formatVersion: backupFormatVersion,
      exportedAt: exportedAt,
      projectCount: data.projects.length,
      taskCount: data.tasks.length,
      noteCount: data.notes.length,
      entryCount: data.entries.length,
      checksumsVerified: true,
      sourceDeviceId: identity?.deviceId,
      sourceDeviceName: identity?.displayName,
    );
    return _BuiltBackup(raw: raw, preview: preview);
  }

  _BuiltVault _buildVaultFiles(AppData data) {
    final generatedAt = DateTime.now().toUtc();
    final files = <String, String>{};
    final noteIndex = <Map<String, dynamic>>[];
    final usedPaths = <String>{};

    for (final note in data.notes) {
      final folderSegments = note.folderPath
          .split(RegExp(r'[/\\]+'))
          .map(_safeSegment)
          .where((segment) => segment.isNotEmpty)
          .toList(growable: false);
      final folder =
          folderSegments.isEmpty ? 'Без папки' : folderSegments.join('/');
      final shortId = note.id
          .replaceAll('-', '')
          .padRight(8, '0')
          .substring(0, 8);
      final baseName =
          _safeSegment(note.title).isEmpty
              ? 'Без названия'
              : _safeSegment(note.title);
      var relativePath = 'Notes/$folder/$baseName--$shortId.md';
      var collision = 2;
      while (!usedPaths.add(relativePath.toLowerCase())) {
        relativePath = 'Notes/$folder/$baseName--$shortId-$collision.md';
        collision++;
      }

      final markdown = _renderNote(note);
      files[relativePath] = markdown;
      noteIndex.add({
        'id': note.id,
        'title': note.title,
        'path': relativePath,
        'revision': note.revision,
        'updatedAt': note.updatedAt.toUtc().toIso8601String(),
        'sha256': _sha256(markdown),
      });
    }

    final index = <String, dynamic>{
      'format': 'chronicle-vault-index',
      'version': 1,
      'generatedAt': generatedAt.toIso8601String(),
      'notes': noteIndex,
    };
    files[_indexPath] = const JsonEncoder.withIndent('  ').convert(index);
    files['Templates/README.md'] = _templatesReadme;

    final manifest = <String, dynamic>{
      'format': 'chronicle-vault',
      'version': 1,
      'generatedAt': generatedAt.toIso8601String(),
      'noteCount': data.notes.length,
      'fileCount': files.length + 1,
      'databaseIsSourceOfTruth': true,
      'readme': 'Markdown-файлы являются безопасным открытым зеркалом базы.',
    };
    files[_manifestPath] = const JsonEncoder.withIndent('  ').convert(manifest);

    return _BuiltVault(
      files: files,
      notePaths: noteIndex.map((entry) => entry['path']! as String).toList(),
      generatedAt: generatedAt,
    );
  }

  Set<String> _managedPathsFromIndex(String? raw) {
    if (raw == null || raw.isEmpty) {
      return <String>{};
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final notes = decoded['notes'] as List<dynamic>? ?? const [];
      return notes
          .whereType<Map>()
          .map((item) => item['path']?.toString() ?? '')
          .where((path) => path.startsWith('Notes/') && path.endsWith('.md'))
          .toSet();
    } on Object {
      return <String>{};
    }
  }

  String _renderNote(Note note) {
    final parsed = NoteDocument.parse(note.body);
    final customProperties = <String, String>{
      ...parsed.frontMatter,
      ...note.properties,
    };
    const reserved = {
      'chronicle_id',
      'title',
      'project_id',
      'folder',
      'type',
      'status',
      'tags',
      'pinned',
      'revision',
      'created_at',
      'updated_at',
    };

    final lines = <String>[
      '---',
      'chronicle_id: ${_yamlString(note.id)}',
      'title: ${_yamlString(note.title)}',
      'project_id: ${_yamlString(note.projectId)}',
      'folder: ${_yamlString(note.folderPath)}',
      'type: ${_yamlString(note.noteType)}',
      'status: ${_yamlString(note.status)}',
      'tags: ${jsonEncode(note.tags)}',
      'pinned: ${note.pinned}',
      'revision: ${note.revision}',
      'created_at: ${_yamlString(note.createdAt.toUtc().toIso8601String())}',
      'updated_at: ${_yamlString(note.updatedAt.toUtc().toIso8601String())}',
      for (final entry in customProperties.entries)
        if (!reserved.contains(entry.key.trim().toLowerCase()) &&
            _validYamlKey(entry.key))
          '${entry.key.trim()}: ${_yamlString(entry.value)}',
      '---',
      '',
      parsed.content.trimLeft(),
    ];
    return '${lines.join('\n').trimRight()}\n';
  }

  bool _validYamlKey(String key) {
    return RegExp(r'^[A-Za-zА-Яа-яЁё0-9_.-]+$').hasMatch(key.trim());
  }

  String _yamlString(String value) => jsonEncode(value);

  String _safeSegment(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[. ]+$'), '');
    if (cleaned.isEmpty) {
      return '';
    }
    const reserved = {
      'CON',
      'PRN',
      'AUX',
      'NUL',
      'COM1',
      'COM2',
      'COM3',
      'COM4',
      'COM5',
      'COM6',
      'COM7',
      'COM8',
      'COM9',
      'LPT1',
      'LPT2',
      'LPT3',
      'LPT4',
      'LPT5',
      'LPT6',
      'LPT7',
      'LPT8',
      'LPT9',
    };
    final safe =
        reserved.contains(cleaned.toUpperCase()) ? '_$cleaned' : cleaned;
    return safe.length <= 96 ? safe : safe.substring(0, 96).trimRight();
  }

  String _backupFileName(String prefix) {
    final now = DateTime.now().toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${now.year}-${two(now.month)}-${two(now.day)}_'
        '${two(now.hour)}-${two(now.minute)}-${two(now.second)}';
    return '$prefix-$stamp.chronicle';
  }

  String _sha256(String value) => sha256.convert(utf8.encode(value)).toString();

  int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static const _templatesReadme = '''# Templates

Эта папка зарезервирована для пользовательских шаблонов Chronicle.

В Chronicle v0.13 база данных остаётся источником истины, а Markdown Vault —
открытым зеркалом. Двустороннее отслеживание изменений появится в следующей
версии Vault.
''';
}

class _BuiltVault {
  const _BuiltVault({
    required this.files,
    required this.notePaths,
    required this.generatedAt,
  });

  final Map<String, String> files;
  final List<String> notePaths;
  final DateTime generatedAt;
}

class _BuiltBackup {
  const _BuiltBackup({required this.raw, required this.preview});

  final String raw;
  final BackupPreview preview;
}
