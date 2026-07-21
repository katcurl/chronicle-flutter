import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../models/app_models.dart';
import '../../sync/pairing_models.dart';
import '../../sync/sync_models.dart';
import 'app_repository.dart';

class InMemoryAppRepository implements AppRepository {
  InMemoryAppRepository({AppData? initialData})
    : _data = initialData ?? AppData.empty();

  final Uuid _uuid = const Uuid();
  AppData _data;
  bool _initialized = false;
  ActiveTimerState? _activeTimer;
  DeviceIdentity? _identity;
  DeviceKeyMaterial? _deviceKeyMaterial;
  SyncPreferences _syncPreferences = const SyncPreferences();
  final List<TrustedDevice> _trustedDevices = [];
  final List<ChangeRecord> _changes = [];
  final List<SyncCursor> _syncCursors = [];
  bool _syncJournalBootstrapped = false;

  @override
  Future<bool> isInitialized() async => _initialized;

  @override
  Future<void> markInitialized() async {
    _initialized = true;
  }

  @override
  Future<AppData> load() async {
    final copy = AppData.decode(_data.encode());
    copy.tasks.removeWhere((task) => task.deletedAt != null);
    copy.notes.removeWhere((note) => note.deletedAt != null);
    return copy;
  }

  @override
  Future<void> replaceAll(AppData data) async {
    _data = AppData.decode(data.encode());
    for (final project in _data.projects) {
      await recordLocalChange(
        entityType: 'project',
        entityId: project.id,
        operation: 'snapshot',
        payload: project.toJson(),
      );
    }
    for (final task in _data.tasks) {
      await recordLocalChange(
        entityType: 'task',
        entityId: task.id,
        operation: 'snapshot',
        payload: task.toJson(),
      );
    }
    for (final note in _data.notes) {
      await recordLocalChange(
        entityType: 'note',
        entityId: note.id,
        operation: 'snapshot',
        payload: note.toJson(),
      );
    }
    for (final entry in _data.entries) {
      await recordLocalChange(
        entityType: 'time_entry',
        entityId: entry.id,
        operation: 'snapshot',
        payload: entry.toJson(),
      );
    }
    await markSyncJournalBootstrapped();
  }

  @override
  Future<void> saveProject(Project project) async {
    _replaceById<Project>(_data.projects, project, (item) => item.id);
    await recordLocalChange(
      entityType: 'project',
      entityId: project.id,
      operation: 'upsert',
      payload: project.toJson(),
    );
  }

  @override
  Future<void> saveTask(WorkTask task) async {
    _replaceById<WorkTask>(_data.tasks, task, (item) => item.id);
    await recordLocalChange(
      entityType: 'task',
      entityId: task.id,
      operation: 'upsert',
      payload: task.toJson(),
    );
  }

  @override
  Future<void> softDeleteTask(String taskId, DateTime deletedAt) async {
    final index = _data.tasks.indexWhere((item) => item.id == taskId);
    if (index >= 0) {
      _data.tasks[index].deletedAt = deletedAt;
    }
    await recordLocalChange(
      entityType: 'task',
      entityId: taskId,
      operation: 'delete',
      payload: {'deletedAt': deletedAt.toIso8601String()},
    );
  }

  @override
  Future<void> saveNote(Note note) async {
    _replaceById<Note>(_data.notes, note, (item) => item.id);
    await recordLocalChange(
      entityType: 'note',
      entityId: note.id,
      operation: 'upsert',
      payload: note.toJson(),
    );
  }

  @override
  Future<void> saveNoteVersion(NoteVersion version) async {
    _replaceById<NoteVersion>(_data.noteVersions, version, (item) => item.id);
    await recordLocalChange(
      entityType: 'note_version',
      entityId: version.id,
      operation: 'append',
      payload: version.toJson(),
    );
  }

  @override
  Future<void> saveCitationSources(List<CitationSource> sources) async {
    _data.citationSources =
        sources
            .map((source) => CitationSource.fromJson(source.toJson()))
            .toList();
  }

  @override
  Future<void> replaceNoteLinks(String noteId, List<NoteLink> links) async {
    _data.noteLinks.removeWhere((link) => link.sourceNoteId == noteId);
    _data.noteLinks.addAll(links);
  }

  @override
  Future<void> saveTimeEntry(TimeEntry entry) async {
    _replaceById<TimeEntry>(_data.entries, entry, (item) => item.id);
    await recordLocalChange(
      entityType: 'time_entry',
      entityId: entry.id,
      operation: 'append',
      payload: entry.toJson(),
    );
  }

  @override
  Future<void> softDeleteNote(String noteId, DateTime deletedAt) async {
    final index = _data.notes.indexWhere((item) => item.id == noteId);
    if (index >= 0) {
      _data.notes[index].deletedAt = deletedAt;
    }
    await recordLocalChange(
      entityType: 'note',
      entityId: noteId,
      operation: 'delete',
      payload: {'deletedAt': deletedAt.toIso8601String()},
    );
  }

  @override
  Future<void> restoreNote(String noteId) async {
    final index = _data.notes.indexWhere((item) => item.id == noteId);
    if (index >= 0) {
      _data.notes[index].deletedAt = null;
    }
    await recordLocalChange(
      entityType: 'note',
      entityId: noteId,
      operation: 'restore',
      payload: {'restoredAt': DateTime.now().toIso8601String()},
    );
  }

  @override
  Future<void> saveActiveTimer(ActiveTimerState? timer) async {
    _activeTimer = timer;
  }

  @override
  Future<ActiveTimerState?> loadActiveTimer() async => _activeTimer;

  @override
  Future<DeviceIdentity> ensureDeviceIdentity() async {
    final existing = _identity;
    if (existing != null) {
      return existing;
    }
    final now = DateTime.now();
    final identity = DeviceIdentity(
      deviceId: _uuid.v4(),
      displayName: defaultDeviceDisplayName(),
      platform: currentPlatformCode(),
      createdAt: now,
      lastSeenAt: now,
    );
    _identity = identity;
    return identity;
  }

  @override
  Future<void> saveDeviceIdentity(DeviceIdentity identity) async {
    identity.lastSeenAt = DateTime.now();
    _identity = identity;
  }

  @override
  Future<DeviceKeyMaterial?> loadDeviceKeyMaterial() async =>
      _deviceKeyMaterial;

  @override
  Future<void> saveDeviceKeyMaterial(DeviceKeyMaterial material) async {
    _deviceKeyMaterial = material;
  }

  @override
  Future<List<TrustedDevice>> loadTrustedDevices({
    bool includeRevoked = false,
  }) async {
    return _trustedDevices
        .where((device) => includeRevoked || device.revokedAt == null)
        .toList(growable: false);
  }

  @override
  Future<void> saveTrustedDevice(TrustedDevice device) async {
    _replaceById<TrustedDevice>(
      _trustedDevices,
      device,
      (item) => item.deviceId,
    );
  }

  @override
  Future<void> revokeTrustedDevice(String deviceId, DateTime revokedAt) async {
    final index = _trustedDevices.indexWhere(
      (device) => device.deviceId == deviceId,
    );
    if (index >= 0) {
      _trustedDevices[index].revokedAt = revokedAt;
    }
  }

  @override
  Future<SyncPreferences> loadSyncPreferences() async => _syncPreferences;

  @override
  Future<void> saveSyncPreferences(SyncPreferences preferences) async {
    _syncPreferences = preferences;
  }

  @override
  Future<List<ChangeRecord>> loadRecentChanges({int limit = 30}) async {
    final sorted = List<ChangeRecord>.from(_changes)
      ..sort((a, b) => b.localSequence.compareTo(a.localSequence));
    return sorted.take(limit).toList(growable: false);
  }

  @override
  Future<int> countJournalEntries() async => _changes.length;

  @override
  Future<bool> isSyncJournalBootstrapped() async => _syncJournalBootstrapped;

  @override
  Future<void> markSyncJournalBootstrapped() async {
    _syncJournalBootstrapped = true;
  }

  @override
  Future<ChangeRecord> recordLocalChange({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final identity = await ensureDeviceIdentity();
    final previousRevision = _changes
        .where(
          (change) =>
              change.entityType == entityType && change.entityId == entityId,
        )
        .fold<int>(
          0,
          (maxRevision, change) =>
              change.revision > maxRevision ? change.revision : maxRevision,
        );
    final change = ChangeRecord(
      localSequence: _changes.length + 1,
      changeId: _uuid.v4(),
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      revision: previousRevision + 1,
      originDeviceId: identity.deviceId,
      changedAt: DateTime.now(),
      payloadJson: jsonEncode(payload),
    );
    _changes.add(change);
    return change;
  }

  @override
  Future<SyncJournalBatch> loadOutgoingChanges({
    required String peerDeviceId,
    required int afterSequence,
    int limit = 200,
  }) async {
    final safeAfter = afterSequence < 0 ? 0 : afterSequence;
    final safeLimit = limit.clamp(1, 1000).toInt();
    final candidates = _changes
      .where((change) => change.localSequence > safeAfter)
      .toList(growable: false)..sort(
      (left, right) => left.localSequence.compareTo(right.localSequence),
    );
    final scanned = candidates.take(safeLimit).toList(growable: false);
    return SyncJournalBatch(
      afterSequence: safeAfter,
      throughSequence: scanned.isEmpty ? safeAfter : scanned.last.localSequence,
      changes: scanned
          .where((change) => change.originDeviceId != peerDeviceId)
          .toList(growable: false),
      hasMore: candidates.length > scanned.length,
    );
  }

  @override
  Future<SyncApplyResult> applyRemoteChanges(List<ChangeRecord> changes) async {
    var insertedCount = 0;
    var appliedCount = 0;
    var duplicateCount = 0;
    var staleCount = 0;
    var unsupportedCount = 0;

    final ordered = List<ChangeRecord>.from(changes)
      ..sort(_compareRemoteApplicationOrder);
    final dataBefore = AppData.decode(_data.encode());
    final changeCountBefore = _changes.length;

    try {
      for (final incoming in ordered) {
        if (_changes.any((change) => change.changeId == incoming.changeId)) {
          duplicateCount++;
          continue;
        }

        ChangeRecord? currentWinner;
        for (final existing in _changes) {
          if (existing.entityType != incoming.entityType ||
              existing.entityId != incoming.entityId) {
            continue;
          }
          if (currentWinner == null ||
              compareChangeFreshness(existing, currentWinner) > 0) {
            currentWinner = existing;
          }
        }

        final stored = ChangeRecord(
          localSequence: _changes.length + 1,
          changeId: incoming.changeId,
          entityType: incoming.entityType,
          entityId: incoming.entityId,
          operation: incoming.operation,
          revision: incoming.revision,
          originDeviceId: incoming.originDeviceId,
          changedAt: incoming.changedAt,
          payloadJson: incoming.payloadJson,
          appliedAt: DateTime.now(),
        );
        _changes.add(stored);
        insertedCount++;

        if (currentWinner != null &&
            compareChangeFreshness(stored, currentWinner) <= 0) {
          staleCount++;
          continue;
        }

        if (_applyRemoteEntity(stored)) {
          appliedCount++;
        } else {
          unsupportedCount++;
        }
      }
    } on Object {
      _data = dataBefore;
      if (_changes.length > changeCountBefore) {
        _changes.removeRange(changeCountBefore, _changes.length);
      }
      rethrow;
    }

    return SyncApplyResult(
      receivedCount: changes.length,
      insertedCount: insertedCount,
      appliedCount: appliedCount,
      duplicateCount: duplicateCount,
      staleCount: staleCount,
      unsupportedCount: unsupportedCount,
    );
  }

  @override
  Future<List<SyncCursor>> loadSyncCursors() async =>
      List<SyncCursor>.from(_syncCursors);

  @override
  Future<void> saveSyncCursor(SyncCursor cursor) async {
    _replaceById<SyncCursor>(_syncCursors, cursor, (item) => item.peerDeviceId);
  }

  @override
  Future<String> exportJson() async => _data.encode();

  @override
  Future<void> importJson(String raw) async {
    await replaceAll(AppData.decode(raw));
    _initialized = true;
  }

  @override
  Future<void> close() async {}

  bool _applyRemoteEntity(ChangeRecord change) {
    final payload = change.payload;
    final upsertOperation =
        change.operation == 'upsert' ||
        change.operation == 'snapshot' ||
        change.operation == 'append';

    switch (change.entityType) {
      case 'project':
        if (!upsertOperation) {
          return false;
        }
        final project = Project.fromJson(payload);
        _verifyEntityId(change, project.id);
        _replaceById<Project>(_data.projects, project, (item) => item.id);
        return true;
      case 'task':
        if (change.operation == 'delete') {
          final deletedAt = DateTime.tryParse('${payload['deletedAt']}');
          final index = _data.tasks.indexWhere(
            (task) => task.id == change.entityId,
          );
          if (index >= 0) {
            _data.tasks[index].deletedAt = deletedAt ?? change.changedAt;
          }
          return true;
        }
        if (change.operation == 'restore') {
          final index = _data.tasks.indexWhere(
            (task) => task.id == change.entityId,
          );
          if (index >= 0) {
            _data.tasks[index].deletedAt = null;
          }
          return true;
        }
        if (!upsertOperation) {
          return false;
        }
        final task = WorkTask.fromJson(payload);
        _verifyEntityId(change, task.id);
        _replaceById<WorkTask>(_data.tasks, task, (item) => item.id);
        return true;
      case 'note':
        if (change.operation == 'delete') {
          final deletedAt = DateTime.tryParse('${payload['deletedAt']}');
          final index = _data.notes.indexWhere(
            (note) => note.id == change.entityId,
          );
          if (index >= 0) {
            _data.notes[index].deletedAt = deletedAt ?? change.changedAt;
          }
          return true;
        }
        if (change.operation == 'restore') {
          final index = _data.notes.indexWhere(
            (note) => note.id == change.entityId,
          );
          if (index >= 0) {
            _data.notes[index].deletedAt = null;
          }
          return true;
        }
        if (!upsertOperation) {
          return false;
        }
        final note = Note.fromJson(payload);
        _verifyEntityId(change, note.id);
        _replaceById<Note>(_data.notes, note, (item) => item.id);
        return true;
      case 'note_version':
        if (!upsertOperation) {
          return false;
        }
        final version = NoteVersion.fromJson(payload);
        _verifyEntityId(change, version.id);
        _replaceById<NoteVersion>(
          _data.noteVersions,
          version,
          (item) => item.id,
        );
        return true;
      case 'time_entry':
        if (!upsertOperation) {
          return false;
        }
        final entry = TimeEntry.fromJson(payload);
        _verifyEntityId(change, entry.id);
        _replaceById<TimeEntry>(_data.entries, entry, (item) => item.id);
        return true;
      default:
        return false;
    }
  }

  void _verifyEntityId(ChangeRecord change, String payloadId) {
    if (payloadId != change.entityId) {
      throw FormatException(
        'Sync change ${change.changeId} has mismatched entity id.',
      );
    }
  }

  void _replaceById<T>(List<T> items, T value, String Function(T item) readId) {
    final index = items.indexWhere((item) => readId(item) == readId(value));
    if (index < 0) {
      items.add(value);
    } else {
      items[index] = value;
    }
  }
}

int _compareRemoteApplicationOrder(ChangeRecord left, ChangeRecord right) {
  final dependency = _syncEntityRank(
    left.entityType,
  ).compareTo(_syncEntityRank(right.entityType));
  if (dependency != 0) {
    return dependency;
  }
  final entityType = left.entityType.compareTo(right.entityType);
  if (entityType != 0) {
    return entityType;
  }
  final entityId = left.entityId.compareTo(right.entityId);
  if (entityId != 0) {
    return entityId;
  }
  return compareChangeFreshness(left, right);
}

int _syncEntityRank(String entityType) {
  return switch (entityType) {
    'project' => 0,
    'note' => 1,
    'task' => 2,
    'note_version' => 3,
    'time_entry' => 4,
    _ => 100,
  };
}
