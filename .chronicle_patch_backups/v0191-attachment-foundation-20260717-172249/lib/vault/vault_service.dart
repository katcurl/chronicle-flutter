import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../features/notes/note_document.dart';
import '../models/app_models.dart';
import '../sync/sync_models.dart';
import 'vault_backend.dart';
import 'vault_models.dart';

class VaultService {
  VaultService({VaultBackend? backend}) : _backend = backend ?? VaultBackend();

  static const int backupFormatVersion = 2;
  static const String _indexPath = '.chronicle/vault-index.json';
  static const String _manifestPath = 'manifest.json';

  final VaultBackend _backend;
  final Uuid _uuid = const Uuid();

  Future<VaultStatus> writeMirror(AppData data, {bool force = false}) async {
    final rootPath = await _backend.resolveRootPath();
    if (rootPath == null || rootPath.isEmpty) {
      return const VaultStatus.unavailable(
        message: 'Файловый Vault недоступен на этой платформе.',
      );
    }

    if (!force) {
      final scanResult = await scan(data);
      if (scanResult.hasChanges) {
        final current = await inspect();
        return current.copyWith(
          noteCount: data.notes.length,
          pendingChangeCount: scanResult.pendingCount,
          conflictCount: scanResult.conflicts.length,
          missingFileCount: scanResult.missingFiles.length,
          message:
              'Vault изменён вне Chronicle. Автоматическая запись '
              'приостановлена до просмотра изменений.',
        );
      }
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
    final attachments = await _backend.listBinaryFiles(
      rootPath: rootPath,
      directory: 'Attachments',
    );

    return VaultStatus(
      supported: true,
      rootPath: rootPath,
      noteCount: data.notes.length,
      fileCount: built.files.length + attachments.length,
      lastWrittenAt: built.generatedAt,
      message: 'Chronicle и Markdown Vault синхронизированы.',
      attachmentCount: attachments.length,
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
      final attachments = await _backend.listBinaryFiles(
        rootPath: rootPath,
        directory: 'Attachments',
      );
      return VaultStatus(
        supported: true,
        rootPath: rootPath,
        noteCount: _readInt(manifest['noteCount']),
        fileCount: _readInt(manifest['fileCount']) + attachments.length,
        attachmentCount: attachments.length,
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

  Future<VaultScanResult> scan(AppData data) async {
    final rootPath = await _backend.resolveRootPath();
    if (rootPath == null || rootPath.isEmpty) {
      throw UnsupportedError('Не удалось определить папку Vault.');
    }

    final indexRaw = await _backend.readTextFile(rootPath, _indexPath);
    final index = _readIndex(indexRaw);
    final indexById = {for (final entry in index) entry.noteId: entry};
    final files = await _backend.listTextFiles(
      rootPath: rootPath,
      directory: 'Notes',
      extension: '.md',
    );
    final currentById = {for (final note in data.notes) note.id: note};
    final seenIds = <String>{};
    final changes = <VaultNoteChange>[];

    final sortedPaths = files.keys.toList()..sort();
    for (final relativePath in sortedPaths) {
      final raw = files[relativePath]!;
      final parsed = _parseVaultNote(
        raw: raw,
        relativePath: relativePath,
        data: data,
      );
      final proposed = parsed.note;
      final current = currentById[proposed.id];
      final previous = indexById[proposed.id];
      final fileHash = _sha256Text(raw);

      if (current == null) {
        changes.add(
          VaultNoteChange(
            kind: VaultChangeKind.newNote,
            relativePath: relativePath,
            proposedNote: proposed,
            fileHash: fileHash,
            previousPath: previous?.relativePath,
            baselineHash: previous?.sha256,
          ),
        );
        seenIds.add(proposed.id);
        continue;
      }

      seenIds.add(current.id);
      final databaseRaw = _renderNote(current);
      final databaseHash = _sha256Text(databaseRaw);
      final moved = previous != null && previous.relativePath != relativePath;
      final baselineHash = previous?.sha256;
      final externalChanged =
          previous == null || fileHash != baselineHash || moved;
      final databaseChanged = previous != null && databaseHash != baselineHash;

      if (!externalChanged) {
        continue;
      }

      if (moved) {
        final inferredTitle = _titleFromPath(relativePath);
        final inferredFolder = _folderFromPath(relativePath);
        if (proposed.title == current.title &&
            inferredTitle.isNotEmpty &&
            inferredTitle != current.title) {
          proposed.title = inferredTitle;
        }
        if (proposed.folderPath == current.folderPath &&
            inferredFolder != current.folderPath) {
          proposed.folderPath = inferredFolder;
        }
        proposed.body = NoteDocument.serialize(
          proposed,
          NoteDocument.parse(proposed.body).content,
        );
      }

      if (_notesEquivalent(current, proposed) && !moved) {
        continue;
      }

      final conflict = databaseChanged && fileHash != databaseHash;
      changes.add(
        VaultNoteChange(
          kind:
              conflict
                  ? VaultChangeKind.conflict
                  : moved
                  ? VaultChangeKind.movedOrRenamed
                  : VaultChangeKind.externalUpdate,
          relativePath: relativePath,
          proposedNote: proposed,
          currentNoteId: current.id,
          previousPath: previous?.relativePath,
          fileHash: fileHash,
          baselineHash: baselineHash,
          databaseHash: databaseHash,
        ),
      );
    }

    final missingFiles = <VaultMissingFile>[];
    for (final entry in index) {
      if (seenIds.contains(entry.noteId)) {
        continue;
      }
      if (currentById.containsKey(entry.noteId)) {
        missingFiles.add(
          VaultMissingFile(
            noteId: entry.noteId,
            relativePath: entry.relativePath,
          ),
        );
      }
    }

    return VaultScanResult(
      rootPath: rootPath,
      scannedAt: DateTime.now(),
      changes: changes,
      missingFiles: missingFiles,
    );
  }

  Future<VaultStatus> rewriteAfterApply(
    AppData data,
    VaultScanResult scan,
  ) async {
    final rootPath = await _backend.resolveRootPath();
    if (rootPath == null || rootPath.isEmpty) {
      throw UnsupportedError('Не удалось определить папку Vault.');
    }
    await _backend.deleteFiles(
      rootPath: rootPath,
      relativePaths: scan.changes.map((change) => change.relativePath).toSet(),
    );
    return writeMirror(data, force: true);
  }

  Future<AttachmentImportResult?> pickAndStoreAttachment(Note note) async {
    final rootPath = await _backend.resolveRootPath();
    if (rootPath == null || rootPath.isEmpty) {
      throw UnsupportedError('Не удалось определить папку Vault.');
    }
    final picked = await _backend.pickAttachment();
    if (picked == null) {
      return null;
    }

    final originalExtension = p.extension(picked.name).toLowerCase();
    final originalBase = p.basenameWithoutExtension(picked.name);
    final safeBase =
        _safeSegment(originalBase).isEmpty
            ? 'attachment'
            : _safeSegment(originalBase);
    final contentHash = sha256.convert(picked.bytes).toString();
    final fileName =
        '$safeBase--${contentHash.substring(0, 8)}'
        '${_safeExtension(originalExtension)}';
    final relativePath = 'Attachments/$fileName';

    await _backend.writeBinaryFile(
      rootPath: rootPath,
      relativePath: relativePath,
      bytes: picked.bytes,
    );

    final folderDepth =
        note.folderPath
            .split(RegExp(r'[/\\]+'))
            .where((segment) => segment.trim().isNotEmpty)
            .length;
    final noteDirectoryDepth = 1 + (folderDepth == 0 ? 1 : folderDepth);
    final prefix = List.filled(noteDirectoryDepth, '../').join();
    final encodedName = Uri.encodeComponent(fileName);
    final linkTarget = '${prefix}Attachments/$encodedName';
    final label = picked.name.replaceAll(']', r'\]');
    final isImage = _imageExtensions.contains(originalExtension);
    final markdown =
        isImage ? '![$label]($linkTarget)' : '[$label]($linkTarget)';

    return AttachmentImportResult(
      fileName: fileName,
      relativePath: relativePath,
      markdown: markdown,
      byteLength: picked.bytes.length,
      isImage: isImage,
    );
  }

  Future<BackupExportResult?> exportBackup({
    required AppData data,
    DeviceIdentity? identity,
  }) async {
    final package = await _buildBackupPackage(data: data, identity: identity);
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

  Future<BackupExportResult> createAutomaticBackup({
    required AppData data,
    DeviceIdentity? identity,
    int maxFiles = 5,
  }) async {
    final rootPath = await _backend.resolveRootPath();
    if (rootPath == null || rootPath.isEmpty) {
      throw UnsupportedError('Не удалось определить папку Vault.');
    }
    final package = await _buildBackupPackage(data: data, identity: identity);
    final fileName = _backupFileName('automatic-backup');
    final path = await _backend.writeAutomaticBackup(
      rootPath: rootPath,
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(package.raw)),
      maxFiles: maxFiles,
    );
    return BackupExportResult(
      path: path,
      fileName: fileName,
      preview: package.preview,
    );
  }

  Future<List<BackupCatalogEntry>> listAutomaticBackups() async {
    final rootPath = await _backend.resolveRootPath();
    if (rootPath == null || rootPath.isEmpty) {
      return const <BackupCatalogEntry>[];
    }
    final files = await _backend.listAutomaticBackups(rootPath: rootPath);
    final entries = <BackupCatalogEntry>[];
    for (final file in files) {
      try {
        final picked = await _backend.readBackupPath(file.path);
        if (picked == null) {
          throw const FormatException('Файл резервной копии недоступен.');
        }
        final raw = utf8.decode(picked.bytes, allowMalformed: false);
        final payload = inspectBackup(raw, sourceName: file.name);
        entries.add(
          BackupCatalogEntry(
            path: file.path,
            fileName: file.name,
            modifiedAt: file.modifiedAt,
            byteLength: file.byteLength,
            preview: payload.preview,
          ),
        );
      } on Object catch (error) {
        entries.add(
          BackupCatalogEntry(
            path: file.path,
            fileName: file.name,
            modifiedAt: file.modifiedAt,
            byteLength: file.byteLength,
            validationError: _backupValidationMessage(error),
          ),
        );
      }
    }
    return entries;
  }

  Future<BackupImportPayload> loadAutomaticBackup(
    BackupCatalogEntry entry,
  ) async {
    final picked = await _backend.readBackupPath(entry.path);
    if (picked == null) {
      throw const FormatException('Файл резервной копии больше недоступен.');
    }
    final raw = utf8.decode(picked.bytes, allowMalformed: false);
    return inspectBackup(raw, sourceName: entry.fileName);
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
        expectedDatabaseHash != _sha256Text(databaseJson)) {
      throw const FormatException(
        'Контрольная сумма database.json не совпадает.',
      );
    }
    for (final entry in vaultFiles.entries) {
      final expected = checksums[entry.key];
      if (expected == null || expected != _sha256Text(entry.value)) {
        throw FormatException('Контрольная сумма ${entry.key} не совпадает.');
      }
    }

    final rawAttachments = decoded['attachmentsBase64'];
    final attachments = <String, Uint8List>{};
    if (rawAttachments is Map) {
      for (final entry in rawAttachments.entries) {
        final relativePath = entry.key.toString();
        if (!_validAttachmentPath(relativePath)) {
          throw FormatException('Некорректный путь вложения: $relativePath');
        }
        try {
          final bytes = base64Decode(entry.value.toString());
          final expected = checksums[relativePath];
          final actual = sha256.convert(bytes).toString();
          if (expected == null || expected != actual) {
            throw FormatException(
              'Контрольная сумма $relativePath не совпадает.',
            );
          }
          attachments[relativePath] = bytes;
        } on FormatException {
          rethrow;
        } on Object {
          throw FormatException('Вложение $relativePath повреждено.');
        }
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
        attachmentCount: attachments.length,
      ),
      attachments: attachments,
    );
  }

  Future<void> restoreAttachments(BackupImportPayload payload) {
    return replaceAttachments(payload);
  }

  Future<void> replaceAttachments(BackupImportPayload payload) async {
    final rootPath = await _backend.resolveRootPath();
    if (rootPath == null || rootPath.isEmpty) {
      if (payload.attachments.isEmpty) {
        return;
      }
      throw UnsupportedError('Не удалось определить папку Vault.');
    }

    for (final relativePath in payload.attachments.keys) {
      if (!_validAttachmentPath(relativePath)) {
        throw FormatException('Некорректный путь вложения: $relativePath');
      }
    }

    final existing = await _backend.listBinaryFiles(
      rootPath: rootPath,
      directory: 'Attachments',
    );
    if (existing.isNotEmpty) {
      await _backend.deleteFiles(
        rootPath: rootPath,
        relativePaths: existing.keys.toSet(),
      );
    }

    for (final entry in payload.attachments.entries) {
      await _backend.writeBinaryFile(
        rootPath: rootPath,
        relativePath: entry.key,
        bytes: entry.value,
      );
    }
  }

  Future<EmergencyBackupSnapshot> createEmergencyBackupSnapshot({
    required AppData data,
    DeviceIdentity? identity,
  }) async {
    final rootPath = await _backend.resolveRootPath();
    if (rootPath == null || rootPath.isEmpty) {
      throw UnsupportedError('Не удалось определить папку Vault.');
    }
    final package = await _buildBackupPackage(data: data, identity: identity);
    final fileName = _backupFileName('pre-import-backup');
    final path = await _backend.writeEmergencyBackup(
      rootPath: rootPath,
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(package.raw)),
    );
    return EmergencyBackupSnapshot(
      path: path,
      payload: inspectBackup(package.raw, sourceName: fileName),
    );
  }

  Future<String> createEmergencyBackup({
    required AppData data,
    DeviceIdentity? identity,
  }) async {
    final snapshot = await createEmergencyBackupSnapshot(
      data: data,
      identity: identity,
    );
    return snapshot.path;
  }

  Future<_BuiltBackup> _buildBackupPackage({
    required AppData data,
    DeviceIdentity? identity,
  }) async {
    final generated = _buildVaultFiles(data);
    final rootPath = await _backend.resolveRootPath();
    final attachments =
        rootPath == null || rootPath.isEmpty
            ? <String, Uint8List>{}
            : await _backend.listBinaryFiles(
              rootPath: rootPath,
              directory: 'Attachments',
            );
    final databaseJson = data.encode();
    final exportedAt = DateTime.now().toUtc();
    final checksums = <String, String>{
      'database.json': _sha256Text(databaseJson),
      for (final entry in generated.files.entries)
        entry.key: _sha256Text(entry.value),
      for (final entry in attachments.entries)
        entry.key: sha256.convert(entry.value).toString(),
    };

    final payload = <String, dynamic>{
      'format': 'chronicle-portable-backup',
      'formatVersion': backupFormatVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'sourceDeviceId': identity?.deviceId,
      'sourceDeviceName': identity?.displayName,
      'databaseJson': databaseJson,
      'vaultFiles': generated.files,
      'attachmentsBase64': {
        for (final entry in attachments.entries)
          entry.key: base64Encode(entry.value),
      },
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
      attachmentCount: attachments.length,
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
      final compactId = note.id.replaceAll('-', '').padRight(8, '0');
      final shortId = compactId.substring(0, 8);
      final safeTitle = _safeSegment(note.title);
      final baseName = safeTitle.isEmpty ? 'Без названия' : safeTitle;
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
        'sha256': _sha256Text(markdown),
      });
    }

    final index = <String, dynamic>{
      'format': 'chronicle-vault-index',
      'version': 2,
      'generatedAt': generatedAt.toIso8601String(),
      'notes': noteIndex,
    };
    files[_indexPath] = const JsonEncoder.withIndent('  ').convert(index);
    files['Templates/README.md'] = _templatesReadme;

    final manifest = <String, dynamic>{
      'format': 'chronicle-vault',
      'version': 2,
      'generatedAt': generatedAt.toIso8601String(),
      'noteCount': data.notes.length,
      'fileCount': files.length + 1,
      'twoWayVault': true,
      'readme':
          'Chronicle импортирует внешние изменения только после просмотра.',
    };
    files[_manifestPath] = const JsonEncoder.withIndent('  ').convert(manifest);

    return _BuiltVault(
      files: files,
      notePaths: noteIndex.map((entry) => entry['path']! as String).toList(),
      generatedAt: generatedAt,
    );
  }

  List<_VaultIndexEntry> _readIndex(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final notes = decoded['notes'] as List<dynamic>? ?? const [];
      return notes
          .whereType<Map>()
          .map((item) {
            return _VaultIndexEntry(
              noteId: item['id']?.toString() ?? '',
              relativePath: item['path']?.toString() ?? '',
              sha256: item['sha256']?.toString() ?? '',
            );
          })
          .where((entry) {
            return entry.noteId.isNotEmpty && entry.relativePath.isNotEmpty;
          })
          .toList(growable: false);
    } on Object {
      return const [];
    }
  }

  Set<String> _managedPathsFromIndex(String? raw) {
    return _readIndex(raw)
        .map((entry) => entry.relativePath)
        .where((path) => path.startsWith('Notes/') && path.endsWith('.md'))
        .toSet();
  }

  _ParsedVaultNote _parseVaultNote({
    required String raw,
    required String relativePath,
    required AppData data,
  }) {
    final document = NoteDocument.parse(raw);
    final frontMatter = Map<String, String>.from(document.frontMatter);
    final existingId = _cleanScalar(frontMatter.remove('chronicle_id'));
    final id = existingId.isEmpty ? _uuid.v4() : existingId;
    final inferredTitle = _titleFromPath(relativePath);
    final titleValue = _cleanScalar(frontMatter.remove('title'));
    final title =
        titleValue.isEmpty
            ? inferredTitle.isEmpty
                ? 'Без названия'
                : inferredTitle
            : titleValue;

    final requestedProject = _cleanScalar(frontMatter.remove('project_id'));
    final projectId =
        data.projects.any((project) => project.id == requestedProject)
            ? requestedProject
            : data.projects.isEmpty
            ? requestedProject
            : data.projects.first.id;
    final folderValue = _cleanScalar(frontMatter.remove('folder'));
    final folder =
        folderValue.isEmpty ? _folderFromPath(relativePath) : folderValue;
    final noteType = _cleanScalar(frontMatter.remove('type'));
    final status = _cleanScalar(frontMatter.remove('status'));
    final tags = _readTags(frontMatter.remove('tags'));
    final pinned = _readBool(frontMatter.remove('pinned'));
    final revision = _readInt(frontMatter.remove('revision'), fallback: 1);
    final createdAt =
        DateTime.tryParse(_cleanScalar(frontMatter.remove('created_at'))) ??
        DateTime.now();
    final updatedAt =
        DateTime.tryParse(_cleanScalar(frontMatter.remove('updated_at'))) ??
        DateTime.now();

    final properties = <String, String>{
      for (final entry in frontMatter.entries)
        if (entry.key.trim().isNotEmpty)
          entry.key.trim(): _cleanScalar(entry.value),
    };
    final note = Note(
      id: id,
      title: title,
      projectId: projectId,
      body: '',
      tags: tags,
      status: status.isEmpty ? 'draft' : status,
      folderPath: folder,
      noteType: noteType.isEmpty ? 'note' : noteType,
      properties: properties,
      pinned: pinned,
      revision: revision < 1 ? 1 : revision,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
    note.body = NoteDocument.serialize(note, document.content);
    return _ParsedVaultNote(note: note);
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

  bool _notesEquivalent(Note a, Note b) {
    return a.title == b.title &&
        a.projectId == b.projectId &&
        NoteDocument.parse(a.body).content.replaceAll('\r\n', '\n') ==
            NoteDocument.parse(b.body).content.replaceAll('\r\n', '\n') &&
        _listEquals(a.tags, b.tags) &&
        a.status == b.status &&
        a.folderPath == b.folderPath &&
        a.noteType == b.noteType &&
        _mapEquals(a.properties, b.properties) &&
        a.pinned == b.pinned;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
  }

  bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  List<String> _readTags(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList(growable: false);
      }
    } on FormatException {
      // Fall through to the permissive front-matter parser.
    }
    return NoteDocument.parseTags(raw)
        .map(_cleanScalar)
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  String _titleFromPath(String relativePath) {
    var name = p.posix.basenameWithoutExtension(relativePath);
    name = name.replaceFirst(RegExp(r'--[A-Za-z0-9]{8}(?:-\d+)?$'), '');
    return name.trim();
  }

  String _folderFromPath(String relativePath) {
    final segments = p.posix.split(relativePath);
    if (segments.length <= 2) {
      return '';
    }
    final folder = segments.sublist(1, segments.length - 1).join('/');
    return folder == 'Без папки' ? '' : folder;
  }

  String _cleanScalar(String? value) {
    if (value == null) {
      return '';
    }
    final trimmed = value.trim();
    if (trimmed.length >= 2) {
      final first = trimmed[0];
      final last = trimmed[trimmed.length - 1];
      if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
        final inner = trimmed.substring(1, trimmed.length - 1);
        if (first == '"') {
          try {
            return jsonDecode(trimmed) as String;
          } on Object {
            return inner;
          }
        }
        return inner;
      }
    }
    return trimmed;
  }

  bool _readBool(Object? value) {
    if (value is bool) {
      return value;
    }
    final normalized = _cleanScalar(value?.toString()).toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  bool _validAttachmentPath(String relativePath) {
    final normalized = relativePath.replaceAll('\\', '/');
    return normalized.startsWith('Attachments/') &&
        !normalized.contains('../') &&
        !normalized.startsWith('/') &&
        normalized.length > 'Attachments/'.length;
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

  String _safeExtension(String extension) {
    if (extension.isEmpty ||
        !RegExp(r'^\.[A-Za-z0-9]{1,12}$').hasMatch(extension)) {
      return '';
    }
    return extension;
  }

  String _backupFileName(String prefix) {
    final now = DateTime.now().toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${now.year}-${two(now.month)}-${two(now.day)}_'
        '${two(now.hour)}-${two(now.minute)}-${two(now.second)}';
    return '$prefix-$stamp.chronicle';
  }

  String _sha256Text(String value) {
    final normalized = value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  String _backupValidationMessage(Object error) {
    final message = error.toString().trim();
    return message.replaceFirst(RegExp(r'^FormatException:\s*'), '');
  }

  int _readInt(Object? value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(_cleanScalar(value?.toString())) ?? fallback;
  }

  static const _imageExtensions = {
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.webp',
    '.bmp',
  };

  static const _templatesReadme = '''# Templates

Эта папка зарезервирована для пользовательских шаблонов Chronicle.

В Chronicle v0.19 Markdown Vault работает в обе стороны. Внешние изменения
сначала обнаруживаются и показываются пользователю; Chronicle никогда не
перезаписывает конфликт молча. Удаление управляемого Markdown-файла можно
безопасно превратить в синхронизируемое удаление заметки: перед этим Chronicle
создаёт страховочную копию. Вложения хранятся в папке `Attachments`.
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

class _VaultIndexEntry {
  const _VaultIndexEntry({
    required this.noteId,
    required this.relativePath,
    required this.sha256,
  });

  final String noteId;
  final String relativePath;
  final String sha256;
}

class _ParsedVaultNote {
  const _ParsedVaultNote({required this.note});

  final Note note;
}
