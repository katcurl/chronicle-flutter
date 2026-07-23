import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../features/notes/note_document.dart';
import '../models/app_models.dart';
import '../sync/attachment_sync_models.dart';
import '../sync/sync_models.dart';
import 'vault_backend.dart';
import 'vault_models.dart';

class VaultService {
  VaultService({VaultBackend? backend}) : _backend = backend ?? VaultBackend();

  static const int backupFormatVersion = 2;
  static const int currentVaultFormatVersion = 2;
  static const int minimumReadableVaultFormatVersion = 1;
  static const String _indexPath = '.chronicle/vault-index.json';
  static const String _attachmentIndexPath =
      '.chronicle/attachments-index.json';
  static const int maxAttachmentBytes = 100 * 1024 * 1024;
  static const String _manifestPath = 'manifest.json';

  final VaultBackend _backend;
  final Uuid _uuid = const Uuid();

  Future<bool> hasExistingNoteContent() async {
    try {
      final rootPath = await _backend.resolveRootPath();
      if (rootPath == null || rootPath.isEmpty) {
        return false;
      }
      final indexRaw = await _backend.readTextFile(rootPath, _indexPath);
      if (_managedPathsFromIndex(indexRaw).isNotEmpty) {
        return true;
      }
      final files = await _backend.listTextFiles(
        rootPath: rootPath,
        directory: 'Notes',
        extension: '.md',
      );
      return files.isNotEmpty;
    } on Object {
      // When the Vault cannot be inspected, fail closed: do not let a new
      // database overwrite files whose state is unknown.
      return true;
    }
  }

  Future<VaultStatus> writeMirror(AppData data, {bool force = false}) async {
    final rootPath = await _backend.resolveRootPath();
    if (rootPath == null || rootPath.isEmpty) {
      return const VaultStatus.unavailable(
        message: 'Файловый Vault недоступен на этой платформе.',
      );
    }

    final compatibility = await _readManifestCompatibility(rootPath);
    if (compatibility.readOnly) {
      final current = await inspect();
      return current.copyWith(
        noteCount: data.notes.length,
        message:
            current.message ??
            'Совместимость Vault нельзя безопасно подтвердить. '
                'Автоматическая запись отключена, чтобы не повредить данные.',
        readOnly: true,
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
      formatVersion: currentVaultFormatVersion,
      minimumReaderVersion: minimumReadableVaultFormatVersion,
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
      final compatibility = _VaultManifestCompatibility.fromJson(manifest);
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
        formatVersion: compatibility.formatVersion,
        minimumReaderVersion: compatibility.minimumReaderVersion,
        readOnly: compatibility.readOnly,
        message:
            compatibility.readOnly
                ? 'Vault создан более новой версией Chronicle: формат '
                    '${compatibility.formatVersion}, тогда как эта версия '
                    'поддерживает формат до $currentVaultFormatVersion. '
                    'Открыт только для чтения.'
                : null,
      );
    } on Object {
      return VaultStatus(
        supported: true,
        rootPath: rootPath,
        noteCount: 0,
        fileCount: 0,
        message:
            'Манифест Vault повреждён. Автоматическая запись отключена; '
            'сначала сохрани копию папки и восстанови совместимый манифест.',
        formatVersion: currentVaultFormatVersion,
        minimumReaderVersion: minimumReadableVaultFormatVersion,
        readOnly: true,
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
    final rootPath = await _requireVaultRoot();
    final picked = await _backend.pickAttachment();
    if (picked == null) {
      return null;
    }
    return _storeAttachmentBytes(
      rootPath: rootPath,
      note: note,
      originalName: picked.name,
      bytes: picked.bytes,
    );
  }

  Future<Uint8List?> readManagedAttachment(String relativePath) async {
    final normalized = relativePath.replaceAll('\\', '/');
    if (!_validAttachmentPath(normalized)) {
      return null;
    }
    final rootPath = await _backend.resolveRootPath();
    if (rootPath == null || rootPath.isEmpty) {
      return null;
    }
    return _backend.readBinaryFile(rootPath, normalized);
  }

  Future<AttachmentImportResult> storeAttachmentBytes({
    required Note note,
    required String originalName,
    required Uint8List bytes,
  }) async {
    final rootPath = await _requireVaultRoot();
    return _storeAttachmentBytes(
      rootPath: rootPath,
      note: note,
      originalName: originalName,
      bytes: bytes,
    );
  }

  Future<AttachmentImportResult> _storeAttachmentBytes({
    required String rootPath,
    required Note note,
    required String originalName,
    required Uint8List bytes,
  }) async {
    final originalExtension = p.extension(originalName).toLowerCase();
    final originalBase = p.basenameWithoutExtension(originalName);
    final safeBase =
        _safeSegment(originalBase).isEmpty
            ? 'attachment'
            : _safeSegment(originalBase);
    if (bytes.length > maxAttachmentBytes) {
      throw FormatException(
        'Вложение больше 100 МБ. Выбери файл меньшего размера.',
      );
    }

    final contentHash = sha256.convert(bytes).toString();
    final records = await _readAttachmentRecords(rootPath);
    VaultAttachmentRecord? duplicate;
    for (final record in records) {
      if (!record.isDeleted && record.sha256 == contentHash) {
        duplicate = record;
        break;
      }
    }

    final generatedFileName =
        '$safeBase--${contentHash.substring(0, 8)}'
        '${_safeExtension(originalExtension)}';
    final relativePath =
        duplicate?.relativePath ?? 'Attachments/$generatedFileName';
    final fileName = p.posix.basename(relativePath);
    final alreadyExisted = await _backend.fileExists(rootPath, relativePath);

    if (!alreadyExisted) {
      await _backend.writeBinaryFile(
        rootPath: rootPath,
        relativePath: relativePath,
        bytes: bytes,
      );
    }

    final mimeType =
        duplicate?.mimeType ?? _mimeTypeForExtension(originalExtension);
    await _upsertAttachmentRecord(
      rootPath,
      VaultAttachmentRecord(
        relativePath: relativePath,
        originalName: duplicate?.originalName ?? originalName,
        sha256: contentHash,
        mimeType: mimeType,
        byteLength: bytes.length,
        createdAt: DateTime.now().toUtc(),
      ),
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
    final label = originalName.replaceAll(']', r'\]');
    final isImage = _imageExtensions.contains(originalExtension);
    final markdown =
        isImage ? '![$label]($linkTarget)' : '[$label]($linkTarget)';

    return AttachmentImportResult(
      fileName: fileName,
      relativePath: relativePath,
      markdown: markdown,
      byteLength: bytes.length,
      isImage: isImage,
      sha256: contentHash,
      mimeType: mimeType,
      alreadyExisted: alreadyExisted,
    );
  }

  Future<List<VaultAttachmentRecord>> listAttachmentCatalog({
    bool includeDeleted = false,
  }) async {
    final rootPath = await _backend.resolveRootPath();
    if (rootPath == null || rootPath.isEmpty) {
      return const <VaultAttachmentRecord>[];
    }
    final records = await _readAttachmentRecords(rootPath);
    final result =
        includeDeleted
            ? records
            : records.where((record) => !record.isDeleted).toList();
    result.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return List<VaultAttachmentRecord>.unmodifiable(result);
  }

  Future<AttachmentSyncManifest> buildAttachmentSyncManifest() async {
    final rootPath = await _backend.resolveRootPath();
    if (rootPath == null || rootPath.isEmpty) {
      return AttachmentSyncManifest(generatedAt: DateTime.now().toUtc());
    }

    final records = await _readAttachmentRecords(rootPath);
    records.sort(
      (left, right) => left.relativePath.compareTo(right.relativePath),
    );
    final entries = <AttachmentSyncEntry>[];
    for (final record in records) {
      if (entries.length >= maxAttachmentSyncManifestEntries) {
        break;
      }
      if (!_validAttachmentPath(record.relativePath) ||
          !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(record.sha256) ||
          record.byteLength < 0 ||
          record.byteLength > maxAttachmentBytes) {
        continue;
      }
      if (!record.isDeleted &&
          !await _backend.fileExists(rootPath, record.relativePath)) {
        // A missing local binary must not be advertised to another device.
        // Omitting it lets a healthy peer offer the content back later.
        continue;
      }
      entries.add(
        AttachmentSyncEntry(
          relativePath: record.relativePath,
          originalName: record.originalName,
          sha256: record.sha256.toLowerCase(),
          mimeType: record.mimeType,
          byteLength: record.byteLength,
          createdAt: record.createdAt.toUtc(),
          deletedAt: record.deletedAt?.toUtc(),
        ),
      );
    }
    return AttachmentSyncManifest(
      generatedAt: DateTime.now().toUtc(),
      entries: List<AttachmentSyncEntry>.unmodifiable(entries),
    );
  }

  Future<Uint8List?> readAttachmentForSync(AttachmentSyncEntry entry) async {
    _validateActiveSyncEntry(entry);
    final rootPath = await _backend.resolveRootPath();
    if (rootPath == null || rootPath.isEmpty) {
      return null;
    }
    final records = await _readAttachmentRecords(rootPath);
    final record = _findAttachmentRecord(records, entry.relativePath);
    if (record == null ||
        record.isDeleted ||
        record.sha256.toLowerCase() != entry.sha256 ||
        record.byteLength != entry.byteLength) {
      return null;
    }
    final bytes = await _backend.readBinaryFile(rootPath, entry.relativePath);
    if (bytes == null) {
      return null;
    }
    _validateAttachmentBytes(entry, bytes);
    return bytes;
  }

  Future<AttachmentSyncApplyResult> storeAttachmentFromSync(
    AttachmentSyncEntry entry,
    Uint8List bytes,
  ) async {
    _validateActiveSyncEntry(entry);
    _validateAttachmentBytes(entry, bytes);
    final rootPath = await _requireVaultRoot();
    final records = await _readAttachmentRecords(rootPath);
    final current = _findAttachmentRecord(records, entry.relativePath);

    var needsWrite = true;
    if (current != null) {
      if (current.isDeleted) {
        throw StateError(
          'Удалённое вложение не может быть восстановлено автоматически.',
        );
      }
      if (current.sha256.toLowerCase() != entry.sha256 ||
          current.byteLength != entry.byteLength) {
        throw StateError('Путь вложения занят другим содержимым.');
      }
      if (await _backend.fileExists(rootPath, entry.relativePath)) {
        final existing = await _backend.readBinaryFile(
          rootPath,
          entry.relativePath,
        );
        if (existing != null) {
          _validateAttachmentBytes(entry, existing);
          return const AttachmentSyncApplyResult.unchanged();
        }
      }
    } else if (await _backend.fileExists(rootPath, entry.relativePath)) {
      final existing = await _backend.readBinaryFile(
        rootPath,
        entry.relativePath,
      );
      if (existing == null) {
        throw StateError('Не удалось проверить существующее вложение.');
      }
      _validateAttachmentBytes(entry, existing);
      needsWrite = false;
    }

    if (needsWrite) {
      await _backend.writeBinaryFile(
        rootPath: rootPath,
        relativePath: entry.relativePath,
        bytes: bytes,
      );
    }
    await _upsertSyncedAttachmentRecord(rootPath, entry);
    return AttachmentSyncApplyResult(
      changed: true,
      byteLength: entry.byteLength,
    );
  }

  Future<AttachmentSyncApplyResult> applyAttachmentRecordFromSync(
    AttachmentSyncEntry entry,
  ) async {
    _validateActiveSyncEntry(entry);
    final rootPath = await _requireVaultRoot();
    final records = await _readAttachmentRecords(rootPath);
    final current = _findAttachmentRecord(records, entry.relativePath);
    if (current != null) {
      if (current.isDeleted) {
        throw StateError(
          'Удалённое вложение не может быть восстановлено автоматически.',
        );
      }
      if (current.sha256.toLowerCase() != entry.sha256 ||
          current.byteLength != entry.byteLength) {
        throw StateError('Путь вложения занят другим содержимым.');
      }
      if (await _backend.fileExists(rootPath, entry.relativePath)) {
        return const AttachmentSyncApplyResult.unchanged();
      }
    }

    if (current == null &&
        await _backend.fileExists(rootPath, entry.relativePath)) {
      final existing = await _backend.readBinaryFile(
        rootPath,
        entry.relativePath,
      );
      if (existing == null) {
        throw StateError('Не удалось проверить существующее вложение.');
      }
      _validateAttachmentBytes(entry, existing);
      await _upsertSyncedAttachmentRecord(rootPath, entry);
      return const AttachmentSyncApplyResult(changed: true);
    }

    VaultAttachmentRecord? source;
    for (final record in records) {
      if (!record.isDeleted &&
          record.sha256.toLowerCase() == entry.sha256 &&
          record.byteLength == entry.byteLength &&
          await _backend.fileExists(rootPath, record.relativePath)) {
        source = record;
        break;
      }
    }
    if (source == null) {
      throw StateError('Локальная копия вложения для дедупликации не найдена.');
    }
    final bytes = await _backend.readBinaryFile(rootPath, source.relativePath);
    if (bytes == null) {
      throw StateError('Локальная копия вложения больше недоступна.');
    }
    _validateAttachmentBytes(entry, bytes);
    await _backend.writeBinaryFile(
      rootPath: rootPath,
      relativePath: entry.relativePath,
      bytes: bytes,
    );
    await _upsertSyncedAttachmentRecord(rootPath, entry);
    return AttachmentSyncApplyResult(
      changed: true,
      byteLength: entry.byteLength,
    );
  }

  Future<AttachmentSyncApplyResult> applyAttachmentTombstoneFromSync(
    AttachmentSyncEntry entry,
  ) async {
    if (!entry.isDeleted || !_validAttachmentPath(entry.relativePath)) {
      throw const FormatException('Некорректная запись удаления вложения.');
    }
    final rootPath = await _requireVaultRoot();
    final records = await _readAttachmentRecords(rootPath);
    final index = records.indexWhere(
      (record) => record.relativePath == entry.relativePath,
    );
    if (index >= 0 && records[index].isDeleted) {
      final localDeletedAt = records[index].deletedAt;
      final remoteDeletedAt = entry.deletedAt;
      if (localDeletedAt != null &&
          remoteDeletedAt != null &&
          !remoteDeletedAt.isAfter(localDeletedAt)) {
        return const AttachmentSyncApplyResult.unchanged();
      }
    }

    final existed = await _backend.fileExists(rootPath, entry.relativePath);
    if (existed) {
      await _backend.deleteFiles(
        rootPath: rootPath,
        relativePaths: <String>{entry.relativePath},
      );
    }
    final tombstone = VaultAttachmentRecord(
      relativePath: entry.relativePath,
      originalName: entry.originalName,
      sha256: entry.sha256,
      mimeType: entry.mimeType,
      byteLength: entry.byteLength,
      createdAt: entry.createdAt,
      deletedAt: entry.deletedAt,
    );
    if (index < 0) {
      records.add(tombstone);
    } else {
      records[index] = tombstone;
    }
    await _writeAttachmentRecords(rootPath, records);
    return AttachmentSyncApplyResult(changed: true);
  }

  Future<AttachmentDeleteResult> deleteManagedAttachment(
    String relativePath,
  ) async {
    if (!_validAttachmentPath(relativePath)) {
      throw FormatException('Недопустимый путь вложения.');
    }
    final rootPath = await _backend.resolveRootPath();
    if (rootPath == null || rootPath.isEmpty) {
      throw UnsupportedError('Не удалось определить папку Vault.');
    }

    final existed = await _backend.fileExists(rootPath, relativePath);
    if (existed) {
      await _backend.deleteFiles(
        rootPath: rootPath,
        relativePaths: <String>{relativePath},
      );
    }

    final records = await _readAttachmentRecords(rootPath);
    final index = records.indexWhere(
      (record) => record.relativePath == relativePath,
    );
    if (index < 0) {
      return AttachmentDeleteResult(
        relativePath: relativePath,
        deletedFile: existed,
        tombstoneCreated: false,
      );
    }

    records[index] = records[index].copyWith(deletedAt: DateTime.now().toUtc());
    await _writeAttachmentRecords(rootPath, records);
    return AttachmentDeleteResult(
      relativePath: relativePath,
      deletedFile: existed,
      tombstoneCreated: true,
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
      vaultFiles: vaultFiles,
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

    final savedIndex = payload.vaultFiles[_attachmentIndexPath];
    if (savedIndex != null && savedIndex.trim().isNotEmpty) {
      await _backend.writeTextFile(
        rootPath: rootPath,
        relativePath: _attachmentIndexPath,
        content: savedIndex,
      );
    } else {
      final restoredRecords = <VaultAttachmentRecord>[
        for (final entry in payload.attachments.entries)
          VaultAttachmentRecord(
            relativePath: entry.key,
            originalName: p.posix.basename(entry.key),
            sha256: sha256.convert(entry.value).toString(),
            mimeType: _mimeTypeForExtension(p.extension(entry.key)),
            byteLength: entry.value.length,
            createdAt: DateTime.now().toUtc(),
          ),
      ];
      await _writeAttachmentRecords(rootPath, restoredRecords);
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

  Future<_VaultManifestCompatibility> _readManifestCompatibility(
    String rootPath,
  ) async {
    final raw = await _backend.readTextFile(rootPath, _manifestPath);
    if (raw == null || raw.trim().isEmpty) {
      return const _VaultManifestCompatibility(
        formatVersion: minimumReadableVaultFormatVersion,
        minimumReaderVersion: minimumReadableVaultFormatVersion,
        readOnly: false,
      );
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('Invalid Vault manifest');
      }
      return _VaultManifestCompatibility.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } on Object {
      // A damaged or unknown manifest is not proof of compatibility. Chronicle
      // 1.0 therefore refuses automatic writes until the user has preserved
      // the folder and explicitly rebuilt or replaced the manifest.
      return const _VaultManifestCompatibility(
        formatVersion: currentVaultFormatVersion,
        minimumReaderVersion: minimumReadableVaultFormatVersion,
        readOnly: true,
      );
    }
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
    final vaultFiles = Map<String, String>.from(generated.files);
    if (rootPath != null && rootPath.isNotEmpty) {
      final attachmentIndex = await _backend.readTextFile(
        rootPath,
        _attachmentIndexPath,
      );
      if (attachmentIndex != null && attachmentIndex.trim().isNotEmpty) {
        vaultFiles[_attachmentIndexPath] = attachmentIndex;
      }
    }
    final databaseJson = data.encode();
    final exportedAt = DateTime.now().toUtc();
    final checksums = <String, String>{
      'database.json': _sha256Text(databaseJson),
      for (final entry in vaultFiles.entries)
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
      'vaultFiles': vaultFiles,
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
      'version': currentVaultFormatVersion,
      'minimumReaderVersion': minimumReadableVaultFormatVersion,
      'generatedAt': generatedAt.toIso8601String(),
      'notes': noteIndex,
    };
    files[_indexPath] = const JsonEncoder.withIndent('  ').convert(index);
    files['Templates/README.md'] = _templatesReadme;

    final manifest = <String, dynamic>{
      'format': 'chronicle-vault',
      'version': currentVaultFormatVersion,
      'minimumReaderVersion': minimumReadableVaultFormatVersion,
      'stableSince': '1.0.0',
      'generatedAt': generatedAt.toIso8601String(),
      'noteCount': data.notes.length,
      'fileCount': files.length + 1,
      'twoWayVault': true,
      'unknownFrontmatterPolicy': 'preserve',
      'conflictPolicy': 'never-silently-overwrite',
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

  Future<List<VaultAttachmentRecord>> _readAttachmentRecords(
    String rootPath,
  ) async {
    final raw = await _backend.readTextFile(rootPath, _attachmentIndexPath);
    if (raw == null || raw.trim().isEmpty) {
      return <VaultAttachmentRecord>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return <VaultAttachmentRecord>[];
      }
      final rawAttachments = decoded['attachments'];
      if (rawAttachments is! List) {
        return <VaultAttachmentRecord>[];
      }
      return rawAttachments
          .whereType<Map>()
          .map(
            (item) => VaultAttachmentRecord.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .where((record) => _validAttachmentPath(record.relativePath))
          .toList();
    } on Object {
      return <VaultAttachmentRecord>[];
    }
  }

  Future<void> _writeAttachmentRecords(
    String rootPath,
    List<VaultAttachmentRecord> records,
  ) {
    final payload = <String, dynamic>{
      'format': 'chronicle-attachment-index',
      'version': 1,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'attachments': records.map((record) => record.toJson()).toList(),
    };
    return _backend.writeTextFile(
      rootPath: rootPath,
      relativePath: _attachmentIndexPath,
      content: const JsonEncoder.withIndent('  ').convert(payload),
    );
  }

  Future<void> _upsertAttachmentRecord(
    String rootPath,
    VaultAttachmentRecord record,
  ) async {
    final records = await _readAttachmentRecords(rootPath);
    final index = records.indexWhere(
      (item) => item.relativePath == record.relativePath,
    );
    if (index < 0) {
      records.add(record);
    } else {
      records[index] = VaultAttachmentRecord(
        relativePath: record.relativePath,
        originalName: record.originalName,
        sha256: record.sha256,
        mimeType: record.mimeType,
        byteLength: record.byteLength,
        createdAt: records[index].createdAt,
      );
    }
    await _writeAttachmentRecords(rootPath, records);
  }

  Future<String> _requireVaultRoot() async {
    final rootPath = await _backend.resolveRootPath();
    if (rootPath == null || rootPath.isEmpty) {
      throw UnsupportedError('Не удалось определить папку Vault.');
    }
    return rootPath;
  }

  VaultAttachmentRecord? _findAttachmentRecord(
    List<VaultAttachmentRecord> records,
    String relativePath,
  ) {
    for (final record in records) {
      if (record.relativePath == relativePath) {
        return record;
      }
    }
    return null;
  }

  void _validateActiveSyncEntry(AttachmentSyncEntry entry) {
    if (entry.isDeleted ||
        !_validAttachmentPath(entry.relativePath) ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(entry.sha256) ||
        entry.byteLength < 0 ||
        entry.byteLength > maxAttachmentBytes) {
      throw const FormatException('Некорректное вложение для синхронизации.');
    }
  }

  void _validateAttachmentBytes(AttachmentSyncEntry entry, Uint8List bytes) {
    if (bytes.length != entry.byteLength) {
      throw const FormatException('Размер вложения не совпадает с манифестом.');
    }
    final actualHash = sha256.convert(bytes).toString();
    if (actualHash != entry.sha256) {
      throw const FormatException(
        'Контрольная сумма вложения не совпадает с манифестом.',
      );
    }
  }

  Future<void> _upsertSyncedAttachmentRecord(
    String rootPath,
    AttachmentSyncEntry entry,
  ) async {
    final records = await _readAttachmentRecords(rootPath);
    final index = records.indexWhere(
      (record) => record.relativePath == entry.relativePath,
    );
    final record = VaultAttachmentRecord(
      relativePath: entry.relativePath,
      originalName: entry.originalName,
      sha256: entry.sha256,
      mimeType: entry.mimeType,
      byteLength: entry.byteLength,
      createdAt: entry.createdAt,
    );
    if (index < 0) {
      records.add(record);
    } else {
      records[index] = record;
    }
    await _writeAttachmentRecords(rootPath, records);
  }

  String _mimeTypeForExtension(String extension) {
    return switch (extension.toLowerCase()) {
      '.png' => 'image/png',
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      '.bmp' => 'image/bmp',
      '.svg' => 'image/svg+xml',
      '.pdf' => 'application/pdf',
      '.txt' => 'text/plain',
      '.md' => 'text/markdown',
      '.csv' => 'text/csv',
      '.json' => 'application/json',
      '.zip' => 'application/zip',
      '.docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      '.pptx' =>
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      _ => 'application/octet-stream',
    };
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

Начиная с Chronicle 1.0 Markdown Vault использует стабильный формат v2 и работает в обе стороны. Внешние изменения
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

int _manifestInt(Object? value, {int fallback = 1}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

class _VaultManifestCompatibility {
  const _VaultManifestCompatibility({
    required this.formatVersion,
    required this.minimumReaderVersion,
    required this.readOnly,
  });

  final int formatVersion;
  final int minimumReaderVersion;
  final bool readOnly;

  factory _VaultManifestCompatibility.fromJson(Map<String, dynamic> json) {
    final format = json['format']?.toString();
    if (format != null && format.isNotEmpty && format != 'chronicle-vault') {
      throw FormatException('Unknown Vault format: $format');
    }
    final formatVersion = _manifestInt(json['version']);
    final minimumReaderVersion = _manifestInt(json['minimumReaderVersion']);
    if (formatVersion < VaultService.minimumReadableVaultFormatVersion ||
        minimumReaderVersion < VaultService.minimumReadableVaultFormatVersion) {
      throw const FormatException('Invalid Vault compatibility version.');
    }
    return _VaultManifestCompatibility(
      formatVersion: formatVersion,
      minimumReaderVersion: minimumReaderVersion,
      readOnly:
          formatVersion > VaultService.currentVaultFormatVersion ||
          minimumReaderVersion > VaultService.currentVaultFormatVersion,
    );
  }
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
