import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../models/app_models.dart';
import '../../sync/pairing_models.dart';
import '../../sync/sync_models.dart';
import 'app_repository.dart';

class InMemoryAppRepository implements AppRepository {
  InMemoryAppRepository({
    AppData? initialData,
    int automaticJournalMaxEntries = defaultMaxJournalEntries,
    int automaticJournalMaxPayloadBytes = defaultMaxJournalPayloadBytes,
  }) : _data = initialData ?? AppData.empty(),
       _automaticJournalMaxEntries = automaticJournalMaxEntries,
       _automaticJournalMaxPayloadBytes = automaticJournalMaxPayloadBytes {
    if (automaticJournalMaxEntries < 1 || automaticJournalMaxPayloadBytes < 1) {
      throw ArgumentError('Journal budgets must be positive.');
    }
  }

  final Uuid _uuid = const Uuid();
  final int _automaticJournalMaxEntries;
  final int _automaticJournalMaxPayloadBytes;
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
  String? _dataGeneration;
  int _nextLocalSequence = 1;
  int _journalPayloadBytes = 0;
  int _journalCompactionGeneration = 0;
  int _lastCompactedSequence = 0;
  int _nextAutomaticCompactionEntryCount = 0;
  int _nextAutomaticCompactionPayloadBytes = 0;

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
  Future<String> ensureDataGeneration() async {
    return _dataGeneration ??= _uuid.v4();
  }

  @override
  Future<void> replaceAllForRestore(
    AppData data, {
    required String generation,
  }) async {
    final previousData = _data;
    final previousChanges = List<ChangeRecord>.from(_changes);
    final previousCursors = List<SyncCursor>.from(_syncCursors);
    final previousGeneration = _dataGeneration;
    final previousTimer = _activeTimer;
    final previousInitialized = _initialized;
    final previousBootstrapped = _syncJournalBootstrapped;
    final previousPayloadBytes = _journalPayloadBytes;
    final previousCompactionGeneration = _journalCompactionGeneration;
    final previousLastCompactedSequence = _lastCompactedSequence;
    final previousNextLocalSequence = _nextLocalSequence;
    try {
      _data = AppData.decode(data.encode());
      _changes.clear();
      _journalPayloadBytes = 0;
      _syncCursors.clear();
      _activeTimer = null;
      _dataGeneration = generation;
      _initialized = true;
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
      _syncJournalBootstrapped = true;
    } on Object {
      _data = previousData;
      _changes
        ..clear()
        ..addAll(previousChanges);
      _dataGeneration = previousGeneration;
      _activeTimer = previousTimer;
      _syncCursors
        ..clear()
        ..addAll(previousCursors);
      _initialized = previousInitialized;
      _syncJournalBootstrapped = previousBootstrapped;
      _journalPayloadBytes = previousPayloadBytes;
      _journalCompactionGeneration = previousCompactionGeneration;
      _lastCompactedSequence = previousLastCompactedSequence;
      _nextLocalSequence = previousNextLocalSequence;
      rethrow;
    }
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
  Future<void> restoreTask(String taskId) async {
    final index = _data.tasks.indexWhere((item) => item.id == taskId);
    if (index >= 0) {
      _data.tasks[index].deletedAt = null;
    }
    await recordLocalChange(
      entityType: 'task',
      entityId: taskId,
      operation: 'restore',
      payload: {'restoredAt': DateTime.now().toIso8601String()},
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
  Future<void> appendTimeEntryAndClearTimer(TimeEntry entry) async {
    await saveTimeEntry(entry);
    _activeTimer = null;
  }

  @override
  Future<void> deleteTaskGraph(String taskId, DateTime deletedAt) async {
    final snapshot = AppData.decode(_data.encode());
    final changesSnapshot = List<ChangeRecord>.from(_changes);
    final payloadBytesSnapshot = _journalPayloadBytes;
    final nextLocalSequenceSnapshot = _nextLocalSequence;
    final compactionGenerationSnapshot = _journalCompactionGeneration;
    final lastCompactedSequenceSnapshot = _lastCompactedSequence;
    try {
      for (final child in _data.tasks.where(
        (task) => task.parentTaskId == taskId,
      )) {
        child.parentTaskId = null;
        child.updatedAt = deletedAt;
        await saveTask(child);
      }
      await softDeleteTask(taskId, deletedAt);
    } on Object {
      _data = snapshot;
      _changes
        ..clear()
        ..addAll(changesSnapshot);
      _journalPayloadBytes = payloadBytesSnapshot;
      _nextLocalSequence = nextLocalSequenceSnapshot;
      _journalCompactionGeneration = compactionGenerationSnapshot;
      _lastCompactedSequence = lastCompactedSequenceSnapshot;
      rethrow;
    }
  }

  @override
  Future<void> deleteNoteGraph(String noteId, DateTime deletedAt) async {
    final snapshot = AppData.decode(_data.encode());
    final changesSnapshot = List<ChangeRecord>.from(_changes);
    final payloadBytesSnapshot = _journalPayloadBytes;
    final nextLocalSequenceSnapshot = _nextLocalSequence;
    final compactionGenerationSnapshot = _journalCompactionGeneration;
    final lastCompactedSequenceSnapshot = _lastCompactedSequence;
    try {
      for (final task in _data.tasks.where((task) => task.noteId == noteId)) {
        task.noteId = null;
        task.updatedAt = deletedAt;
        await saveTask(task);
      }
      _data.noteLinks.removeWhere(
        (link) => link.sourceNoteId == noteId || link.targetNoteId == noteId,
      );
      await softDeleteNote(noteId, deletedAt);
    } on Object {
      _data = snapshot;
      _changes
        ..clear()
        ..addAll(changesSnapshot);
      _journalPayloadBytes = payloadBytesSnapshot;
      _nextLocalSequence = nextLocalSequenceSnapshot;
      _journalCompactionGeneration = compactionGenerationSnapshot;
      _lastCompactedSequence = lastCompactedSequenceSnapshot;
      rethrow;
    }
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
  Future<void> deleteDeviceKeyMaterial() async {
    _deviceKeyMaterial = null;
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
  Future<JournalCompactionResult> compactJournal({
    int maxEntries = defaultMaxJournalEntries,
    int maxPayloadBytes = defaultMaxJournalPayloadBytes,
  }) async {
    _validateJournalBudgets(maxEntries, maxPayloadBytes);
    return _compactJournalNow(
      maxEntries: maxEntries,
      maxPayloadBytes: maxPayloadBytes,
    );
  }

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
      localSequence: _nextLocalSequence++,
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
    _journalPayloadBytes += utf8.encode(change.payloadJson).length;
    _compactJournalIfNeeded();
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
    final changesBefore = List<ChangeRecord>.from(_changes);
    final payloadBytesBefore = _journalPayloadBytes;
    final nextLocalSequenceBefore = _nextLocalSequence;
    final compactionGenerationBefore = _journalCompactionGeneration;
    final lastCompactedSequenceBefore = _lastCompactedSequence;

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
          localSequence: _nextLocalSequence++,
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
        _journalPayloadBytes += utf8.encode(stored.payloadJson).length;
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
      _compactJournalIfNeeded();
    } on Object {
      _data = dataBefore;
      _changes
        ..clear()
        ..addAll(changesBefore);
      _journalPayloadBytes = payloadBytesBefore;
      _nextLocalSequence = nextLocalSequenceBefore;
      _journalCompactionGeneration = compactionGenerationBefore;
      _lastCompactedSequence = lastCompactedSequenceBefore;
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
  Future<void> close() async {}

  void _compactJournalIfNeeded() {
    if (_changes.length <= _automaticJournalMaxEntries &&
        _journalPayloadBytes <= _automaticJournalMaxPayloadBytes) {
      return;
    }
    if (_changes.length < _nextAutomaticCompactionEntryCount &&
        _journalPayloadBytes < _nextAutomaticCompactionPayloadBytes) {
      return;
    }
    final result = _compactJournalNow(
      maxEntries: _automaticJournalMaxEntries,
      maxPayloadBytes: _automaticJournalMaxPayloadBytes,
    );
    if (result.withinBudget) {
      _nextAutomaticCompactionEntryCount = 0;
      _nextAutomaticCompactionPayloadBytes = 0;
    } else {
      _nextAutomaticCompactionEntryCount = result.entryCountAfter + 1000;
      _nextAutomaticCompactionPayloadBytes =
          result.payloadBytesAfter + 10 * 1024 * 1024;
    }
  }

  JournalCompactionResult _compactJournalNow({
    required int maxEntries,
    required int maxPayloadBytes,
  }) {
    final entryCountBefore = _changes.length;
    final payloadBytesBefore = _journalPayloadBytes;
    final minimumPeerCursor = _minimumPeerCursor();
    final lastSequenceBefore = _changes.fold<int>(
      _lastCompactedSequence,
      (value, change) =>
          change.localSequence > value ? change.localSequence : value,
    );
    if (entryCountBefore <= maxEntries &&
        payloadBytesBefore <= maxPayloadBytes) {
      return _journalCompactionResult(
        didCompact: false,
        entryCountBefore: entryCountBefore,
        payloadBytesBefore: payloadBytesBefore,
        minimumPeerCursor: minimumPeerCursor,
        maxEntries: maxEntries,
        maxPayloadBytes: maxPayloadBytes,
      );
    }

    final winners = <String, ChangeRecord>{};
    for (final change in _changes) {
      final key = '${change.entityType}\u0000${change.entityId}';
      final current = winners[key];
      if (current == null || compareChangeFreshness(change, current) > 0) {
        winners[key] = change;
      }
    }
    var canonicalized = false;
    final compacted = winners.values
      .map((winner) {
        final replacement = _canonicalizeRestoreWinner(winner);
        canonicalized = canonicalized || !identical(replacement, winner);
        return replacement;
      })
      .toList(growable: false)..sort(
      (left, right) => left.localSequence.compareTo(right.localSequence),
    );
    if (compacted.length == _changes.length && !canonicalized) {
      return _journalCompactionResult(
        didCompact: false,
        entryCountBefore: entryCountBefore,
        payloadBytesBefore: payloadBytesBefore,
        minimumPeerCursor: minimumPeerCursor,
        maxEntries: maxEntries,
        maxPayloadBytes: maxPayloadBytes,
      );
    }

    _changes
      ..clear()
      ..addAll(compacted);
    _journalPayloadBytes = compacted.fold<int>(
      0,
      (total, change) => total + utf8.encode(change.payloadJson).length,
    );
    _journalCompactionGeneration += 1;
    _lastCompactedSequence = lastSequenceBefore;
    return _journalCompactionResult(
      didCompact: true,
      entryCountBefore: entryCountBefore,
      payloadBytesBefore: payloadBytesBefore,
      minimumPeerCursor: minimumPeerCursor,
      maxEntries: maxEntries,
      maxPayloadBytes: maxPayloadBytes,
    );
  }

  ChangeRecord _canonicalizeRestoreWinner(ChangeRecord winner) {
    if (winner.operation != 'restore') {
      return winner;
    }
    Map<String, dynamic>? payload;
    if (winner.entityType == 'note') {
      final index = _data.notes.indexWhere(
        (note) => note.id == winner.entityId,
      );
      if (index >= 0 && _data.notes[index].deletedAt == null) {
        payload = _data.notes[index].toJson();
      }
    } else if (winner.entityType == 'task') {
      final index = _data.tasks.indexWhere(
        (task) => task.id == winner.entityId,
      );
      if (index >= 0 && _data.tasks[index].deletedAt == null) {
        payload = _data.tasks[index].toJson();
      }
    } else {
      return winner;
    }
    return ChangeRecord(
      localSequence: winner.localSequence,
      changeId: winner.changeId,
      entityType: winner.entityType,
      entityId: winner.entityId,
      operation: payload == null ? 'delete' : 'snapshot',
      revision: winner.revision,
      originDeviceId: winner.originDeviceId,
      changedAt: winner.changedAt,
      payloadJson: jsonEncode(
        payload ??
            <String, dynamic>{
              'deletedAt': winner.changedAt.toUtc().toIso8601String(),
            },
      ),
      appliedAt: winner.appliedAt,
    );
  }

  JournalCompactionResult _journalCompactionResult({
    required bool didCompact,
    required int entryCountBefore,
    required int payloadBytesBefore,
    required int? minimumPeerCursor,
    required int maxEntries,
    required int maxPayloadBytes,
  }) {
    return JournalCompactionResult(
      didCompact: didCompact,
      entryCountBefore: entryCountBefore,
      entryCountAfter: _changes.length,
      payloadBytesBefore: payloadBytesBefore,
      payloadBytesAfter: _journalPayloadBytes,
      generation: _journalCompactionGeneration,
      lastCompactedSequence: _lastCompactedSequence,
      minimumPeerCursor: minimumPeerCursor,
      maxEntries: maxEntries,
      maxPayloadBytes: maxPayloadBytes,
    );
  }

  int? _minimumPeerCursor() {
    int? minimum;
    for (final cursor in _syncCursors) {
      if (minimum == null || cursor.lastSentSequence < minimum) {
        minimum = cursor.lastSentSequence;
      }
    }
    return minimum;
  }

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

void _validateJournalBudgets(int maxEntries, int maxPayloadBytes) {
  if (maxEntries < 1 || maxPayloadBytes < 1) {
    throw ArgumentError('Journal budgets must be positive.');
  }
}
