import 'dart:async';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../data/repositories/app_repository.dart';
import '../../features/notes/note_document.dart';
import '../../models/app_models.dart';
import '../../sync/sync_models.dart';
import '../../vault/vault_models.dart';
import '../../vault/vault_service.dart';

final class VaultCoordinator {
  VaultCoordinator({
    required AppRepository repository,
    required VaultService vaultService,
    required AppData Function() currentData,
    required DeviceIdentity? Function() currentIdentity,
    required bool Function() isBusy,
    required void Function(bool value) setBusy,
    required Future<void> Function() rebuildAllNoteLinks,
    required Future<void> Function() refreshSyncFoundation,
    required void Function(String path) onEmergencyBackupCreated,
    required void Function() onAttachmentRefresh,
    required void Function() notifyListeners,
    Uuid uuid = const Uuid(),
  }) : _repository = repository,
       _vaultService = vaultService,
       _currentData = currentData,
       _currentIdentity = currentIdentity,
       _isBusy = isBusy,
       _setBusy = setBusy,
       _rebuildAllNoteLinks = rebuildAllNoteLinks,
       _refreshSyncFoundation = refreshSyncFoundation,
       _onEmergencyBackupCreated = onEmergencyBackupCreated,
       _onAttachmentRefresh = onAttachmentRefresh,
       _notifyListeners = notifyListeners,
       _uuid = uuid;

  final AppRepository _repository;
  final VaultService _vaultService;
  final AppData Function() _currentData;
  final DeviceIdentity? Function() _currentIdentity;
  final bool Function() _isBusy;
  final void Function(bool value) _setBusy;
  final Future<void> Function() _rebuildAllNoteLinks;
  final Future<void> Function() _refreshSyncFoundation;
  final void Function(String path) _onEmergencyBackupCreated;
  final void Function() _onAttachmentRefresh;
  final void Function() _notifyListeners;
  final Uuid _uuid;
  Timer? _mirrorDebounce;

  VaultStatus status = const VaultStatus.unavailable();
  VaultScanResult? pendingScan;

  Future<void> initialize({required bool allowAutomaticWrite}) async {
    try {
      status = await _vaultService.inspect();
      if (status.supported) {
        pendingScan = await _vaultService.scan(_currentData());
        if (allowAutomaticWrite && !pendingScan!.hasChanges) {
          status = await _vaultService.writeMirror(_currentData());
          pendingScan = await _vaultService.scan(_currentData());
        }
        mergePendingScan(
          messageOverride:
              !allowAutomaticWrite
                  ? pendingScan!.hasChanges
                      ? 'Найдены данные Vault. Автоматическая запись отключена '
                          'до просмотра изменений.'
                      : 'Новая локальная база создана. Автоматическая запись '
                          'в Vault пропущена для защиты существующих файлов.'
                  : null,
        );
      }
    } on Object catch (error) {
      status = VaultStatus.unavailable(message: error.toString());
      pendingScan = null;
    }
  }

  Future<void> refreshStatus({bool notify = true}) async {
    try {
      status = await _vaultService.inspect();
      if (status.supported) {
        pendingScan = await _vaultService.scan(_currentData());
        mergePendingScan();
      }
    } on Object catch (error) {
      status = VaultStatus.unavailable(message: error.toString());
      pendingScan = null;
    }
    if (notify) {
      _notifyListeners();
    }
  }

  Future<VaultScanResult> scanChanges({bool notify = true}) async {
    final scan = await _vaultService.scan(_currentData());
    pendingScan = scan;
    mergePendingScan();
    if (notify) {
      _notifyListeners();
    }
    return scan;
  }

  void mergePendingScan({String? messageOverride}) {
    final scan = pendingScan;
    if (scan == null) {
      return;
    }
    status = status.copyWith(
      pendingChangeCount: scan.pendingCount,
      conflictCount: scan.conflicts.length,
      missingFileCount: scan.missingFiles.length,
      message:
          messageOverride ??
          (scan.hasChanges
              ? 'Найдены внешние изменения. Просмотри их перед импортом.'
              : 'Chronicle и Markdown Vault синхронизированы.'),
    );
  }

  Future<void> writeMirror() async {
    if (_isBusy()) {
      return;
    }
    _setBusy(true);
    _notifyListeners();
    try {
      status = await _vaultService.writeMirror(_currentData());
      pendingScan = await _vaultService.scan(_currentData());
      mergePendingScan();
    } finally {
      _setBusy(false);
      _notifyListeners();
    }
  }

  Future<bool> chooseFolder() async {
    if (_isBusy()) {
      return false;
    }
    _setBusy(true);
    _notifyListeners();
    try {
      final result = await _vaultService.chooseRootAndWrite(_currentData());
      if (result == null) {
        return false;
      }
      status = result;
      pendingScan = await _vaultService.scan(_currentData());
      mergePendingScan();
      return true;
    } finally {
      _setBusy(false);
      _notifyListeners();
    }
  }

  Future<Uint8List?> readManagedAttachment(String relativePath) {
    return _vaultService.readManagedAttachment(relativePath);
  }

  Future<AttachmentImportResult?> pickAttachmentForNote(Note note) async {
    final result = await _vaultService.pickAndStoreAttachment(note);
    if (result != null) {
      _onAttachmentRefresh();
    }
    return result;
  }

  Future<AttachmentImportResult> storeAttachmentBytesForNote(
    Note note, {
    required String fileName,
    required Uint8List bytes,
  }) async {
    final result = await _vaultService.storeAttachmentBytes(
      note: note,
      originalName: fileName,
      bytes: bytes,
    );
    _onAttachmentRefresh();
    return result;
  }

  Future<List<AttachmentImportResult>> storeAttachmentBatchForNote(
    Note note, {
    required List<String> fileNames,
    required List<Uint8List> fileBytes,
  }) async {
    if (fileNames.length != fileBytes.length) {
      throw ArgumentError('Количество имён и файлов должно совпадать.');
    }
    final results = <AttachmentImportResult>[];
    for (var index = 0; index < fileNames.length; index++) {
      results.add(
        await _vaultService.storeAttachmentBytes(
          note: note,
          originalName: fileNames[index],
          bytes: fileBytes[index],
        ),
      );
    }
    if (results.isNotEmpty) {
      _onAttachmentRefresh();
    }
    return List<AttachmentImportResult>.unmodifiable(results);
  }

  Future<VaultApplyResult> applyChanges(
    VaultScanResult scan, {
    required VaultConflictResolution conflictResolution,
    Map<String, VaultConflictResolution> conflictResolutions =
        const <String, VaultConflictResolution>{},
    VaultMissingFileResolution missingFileResolution =
        VaultMissingFileResolution.restoreFiles,
  }) async {
    if (_isBusy()) {
      throw StateError('Vault уже занят другой операцией.');
    }
    _setBusy(true);
    _notifyListeners();

    var createdCount = 0;
    var updatedCount = 0;
    var duplicatedCount = 0;
    var keptChronicleCount = 0;
    var deletedCount = 0;
    String? safetyBackupPath;

    try {
      await _vaultService.verifyRevision(scan.revision);
      final needsSafetyBackup =
          scan.conflicts.isNotEmpty ||
          (missingFileResolution == VaultMissingFileResolution.deleteNotes &&
              scan.missingFiles.isNotEmpty);
      if (needsSafetyBackup) {
        final snapshot = await _vaultService.createEmergencyBackupSnapshot(
          data: _currentData(),
          identity: _currentIdentity(),
        );
        safetyBackupPath = snapshot.path;
        _onEmergencyBackupCreated(snapshot.path);
      }
      for (final change in scan.safeChanges) {
        if (change.isNew || _noteById(change.currentNoteId ?? '') == null) {
          await _createNote(change.proposedNote);
          createdCount++;
        } else {
          await _overwriteNote(
            _noteById(change.currentNoteId!)!,
            change.proposedNote,
          );
          updatedCount++;
        }
      }

      for (final conflict in scan.conflicts) {
        final current = _noteById(conflict.currentNoteId ?? '');
        if (current == null) {
          await _createNote(conflict.proposedNote);
          createdCount++;
          continue;
        }
        final resolution =
            conflictResolutions[conflict.decisionKey] ?? conflictResolution;
        switch (resolution) {
          case VaultConflictResolution.keepChronicle:
            keptChronicleCount++;
          case VaultConflictResolution.importFile:
            await _overwriteNote(current, conflict.proposedNote);
            updatedCount++;
          case VaultConflictResolution.keepBoth:
            await _createNote(
              conflict.proposedNote,
              forceNewId: true,
              titleSuffix: ' (конфликтная версия Vault)',
            );
            duplicatedCount++;
        }
      }

      if (missingFileResolution == VaultMissingFileResolution.deleteNotes) {
        for (final missing in scan.missingFiles) {
          if (_noteById(missing.noteId) == null) {
            continue;
          }
          await _deleteNote(missing.noteId);
          deletedCount++;
        }
      }

      await _rebuildAllNoteLinks();
      await _refreshSyncFoundation();
      status = await _vaultService.rewriteAfterApply(_currentData(), scan);
      pendingScan = await _vaultService.scan(_currentData());
      mergePendingScan();
      _onAttachmentRefresh();

      return VaultApplyResult(
        createdCount: createdCount,
        updatedCount: updatedCount,
        duplicatedCount: duplicatedCount,
        keptChronicleCount: keptChronicleCount,
        restoredFileCount:
            missingFileResolution == VaultMissingFileResolution.restoreFiles
                ? scan.missingFiles.length
                : 0,
        deletedCount: deletedCount,
        safetyBackupPath: safetyBackupPath,
      );
    } finally {
      _setBusy(false);
      _notifyListeners();
    }
  }

  void scheduleMirror() {
    _mirrorDebounce?.cancel();
    _mirrorDebounce = Timer(
      const Duration(milliseconds: 700),
      () => unawaited(writeMirror()),
    );
  }

  void dispose() {
    _mirrorDebounce?.cancel();
  }

  Note? _noteById(String id) {
    for (final note in _currentData().notes) {
      if (note.id == id) {
        return note;
      }
    }
    return null;
  }

  Future<void> _createNote(
    Note source, {
    bool forceNewId = false,
    String titleSuffix = '',
  }) async {
    final data = _currentData();
    if (data.projects.isEmpty) {
      throw StateError('Сначала создай хотя бы один проект.');
    }
    final projectId =
        data.projects.any((project) => project.id == source.projectId)
            ? source.projectId
            : data.projects.first.id;
    final imported = Note(
      id: forceNewId || _noteById(source.id) != null ? _uuid.v4() : source.id,
      title: '${source.title}$titleSuffix',
      projectId: projectId,
      body: '',
      tags: List<String>.from(source.tags),
      status: source.status,
      folderPath: source.folderPath,
      noteType: source.noteType,
      properties: Map<String, String>.from(source.properties),
      pinned: source.pinned,
      revision: source.revision < 1 ? 1 : source.revision,
      createdAt: source.createdAt,
      updatedAt: DateTime.now(),
    );
    imported.body = NoteDocument.serialize(
      imported,
      NoteDocument.parse(source.body).content,
    );
    data.notes.add(imported);
    await _repository.saveNote(imported);
  }

  Future<void> _deleteNote(String noteId) async {
    final data = _currentData();
    final deletedAt = DateTime.now();
    final noteIndex = data.notes.indexWhere((note) => note.id == noteId);
    if (noteIndex < 0) {
      return;
    }
    data.notes.removeAt(noteIndex);
    data.noteLinks.removeWhere(
      (link) => link.sourceNoteId == noteId || link.targetNoteId == noteId,
    );
    for (final task in data.tasks.where((task) => task.noteId == noteId)) {
      task.noteId = null;
      task.updatedAt = deletedAt;
      await _repository.saveTask(task);
    }
    await _repository.replaceNoteLinks(noteId, const <NoteLink>[]);
    await _repository.softDeleteNote(noteId, deletedAt);
  }

  Future<void> _overwriteNote(Note current, Note source) async {
    final data = _currentData();
    final version = NoteVersion(
      id: _uuid.v4(),
      noteId: current.id,
      title: current.title,
      body: current.body,
      tags: List<String>.from(current.tags),
      status: current.status,
      folderPath: current.folderPath,
      noteType: current.noteType,
      properties: Map<String, String>.from(current.properties),
      reason: 'Перед импортом из Markdown Vault',
    );
    data.noteVersions.insert(0, version);
    await _repository.saveNoteVersion(version);

    current.title = source.title;
    current.projectId =
        data.projects.any((project) => project.id == source.projectId)
            ? source.projectId
            : current.projectId;
    current.tags = List<String>.from(source.tags);
    current.status = source.status;
    current.folderPath = source.folderPath;
    current.noteType = source.noteType;
    current.properties = Map<String, String>.from(source.properties);
    current.pinned = source.pinned;
    current.revision++;
    current.updatedAt = DateTime.now();
    current.body = NoteDocument.serialize(
      current,
      NoteDocument.parse(source.body).content,
    );
    await _repository.saveNote(current);
  }
}
