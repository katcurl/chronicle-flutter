import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../models/app_models.dart';
import '../../sync/pairing_models.dart';
import '../../sync/sync_models.dart';
import '../database/chronicle_database.dart';
import 'app_repository.dart';

class DriftAppRepository implements AppRepository {
  DriftAppRepository({
    ChronicleDatabase? database,
    int automaticJournalMaxEntries = defaultMaxJournalEntries,
    int automaticJournalMaxPayloadBytes = defaultMaxJournalPayloadBytes,
  }) : _database = database ?? ChronicleDatabase.defaults(),
       _automaticJournalMaxEntries = automaticJournalMaxEntries,
       _automaticJournalMaxPayloadBytes = automaticJournalMaxPayloadBytes {
    _validateJournalBudgets(
      automaticJournalMaxEntries,
      automaticJournalMaxPayloadBytes,
    );
  }

  static const _initializedKey = 'initialized';
  static const _activeTimerKey = 'active_timer';
  static const _syncPreferencesKey = 'sync_preferences';
  static const _syncJournalBootstrappedKey = 'sync_journal_bootstrapped';
  static const _journalEntryCountKey = 'sync_journal_entry_count_v1';
  static const _journalPayloadBytesKey = 'sync_journal_payload_bytes_v1';
  static const _journalCompactionMetadataKey =
      'sync_journal_compaction_metadata_v1';
  static const _deviceKeyMaterialKey = 'device_key_material_v1';
  static const _citationSourcesKey = 'citation_sources_v1';
  static const _dataGenerationKey = 'data_generation_v1';

  final ChronicleDatabase _database;
  final int _automaticJournalMaxEntries;
  final int _automaticJournalMaxPayloadBytes;
  final Uuid _uuid = const Uuid();
  DeviceIdentity? _identityCache;
  bool _journalMetricsValidated = false;
  int _nextAutomaticCompactionEntryCount = 0;
  int _nextAutomaticCompactionPayloadBytes = 0;

  @override
  Future<bool> isInitialized() async {
    final value = await _readState(_initializedKey);
    return value == '1';
  }

  @override
  Future<void> markInitialized() => _putState(_initializedKey, '1');

  @override
  Future<AppData> load() async {
    return _database.transaction(() async {
      final projects = await _readRows(
        'SELECT * FROM projects ORDER BY updated_at DESC',
      );
      final tasks = await _readRows(
        'SELECT * FROM tasks '
        'WHERE deleted_at IS NULL ORDER BY updated_at DESC',
      );
      final notes = await _readRows(
        'SELECT * FROM notes '
        'WHERE deleted_at IS NULL ORDER BY updated_at DESC',
      );
      final entries = await _readRows(
        'SELECT * FROM time_entries ORDER BY started_at DESC',
      );
      final links = await _readRows(
        'SELECT * FROM note_links ORDER BY created_at DESC',
      );
      final versions = await _readRows(
        'SELECT * FROM note_versions ORDER BY created_at DESC',
      );
      final citationSources = await _loadCitationSources();

      return AppData(
        projects: projects.map(Project.fromDb).toList(),
        tasks: tasks.map(WorkTask.fromDb).toList(),
        notes: notes.map(Note.fromDb).toList(),
        entries: entries.map(TimeEntry.fromDb).toList(),
        noteLinks: links.map(NoteLink.fromDb).toList(),
        noteVersions: versions.map(NoteVersion.fromDb).toList(),
        citationSources: citationSources,
      );
    });
  }

  @override
  Future<void> replaceAll(AppData data) async {
    await _database.transaction(() async {
      await _database.customStatement('DELETE FROM time_entries');
      await _database.customStatement('DELETE FROM tasks');
      await _database.customStatement('DELETE FROM note_links');
      await _database.customStatement('DELETE FROM note_versions');
      await _database.customStatement('DELETE FROM notes');
      await _database.customStatement('DELETE FROM projects');

      for (final project in data.projects) {
        await _upsert('projects', project.toDb());
      }
      for (final note in data.notes) {
        await _upsert('notes', note.toDb());
      }
      for (final task in data.tasks) {
        await _upsert('tasks', task.toDb());
      }
      for (final link in data.noteLinks) {
        await _upsert('note_links', link.toDb());
      }
      for (final version in data.noteVersions) {
        await _upsert('note_versions', version.toDb());
      }
      for (final entry in data.entries) {
        await _upsert('time_entries', entry.toDb());
      }
    });
    await saveCitationSources(data.citationSources);

    for (final project in data.projects) {
      await recordLocalChange(
        entityType: 'project',
        entityId: project.id,
        operation: 'snapshot',
        payload: project.toJson(),
      );
    }
    for (final task in data.tasks) {
      await recordLocalChange(
        entityType: 'task',
        entityId: task.id,
        operation: 'snapshot',
        payload: task.toJson(),
      );
    }
    for (final note in data.notes) {
      await recordLocalChange(
        entityType: 'note',
        entityId: note.id,
        operation: 'snapshot',
        payload: note.toJson(),
      );
    }
    for (final entry in data.entries) {
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
    final current = await _readState(_dataGenerationKey);
    if (current != null && current.isNotEmpty) {
      return current;
    }
    final generation = _uuid.v4();
    await _putState(_dataGenerationKey, generation);
    return generation;
  }

  @override
  Future<void> replaceAllForRestore(
    AppData data, {
    required String generation,
  }) async {
    await ensureDeviceIdentity();
    await _database.transaction(() async {
      await _database.customStatement('DELETE FROM time_entries');
      await _database.customStatement('DELETE FROM tasks');
      await _database.customStatement('DELETE FROM note_links');
      await _database.customStatement('DELETE FROM note_versions');
      await _database.customStatement('DELETE FROM notes');
      await _database.customStatement('DELETE FROM projects');
      await _database.customStatement('DELETE FROM change_records');
      await _database.customStatement('DELETE FROM sync_cursors');
      await _writeJournalMetricsInTransaction(
        const _JournalMetrics(entryCount: 0, payloadBytes: 0),
      );

      for (final project in data.projects) {
        await _upsert('projects', project.toDb());
      }
      for (final note in data.notes) {
        await _upsert('notes', note.toDb());
      }
      for (final task in data.tasks) {
        await _upsert('tasks', task.toDb());
      }
      for (final link in data.noteLinks) {
        await _upsert('note_links', link.toDb());
      }
      for (final version in data.noteVersions) {
        await _upsert('note_versions', version.toDb());
      }
      for (final entry in data.entries) {
        await _upsert('time_entries', entry.toDb());
      }
      await _putState(
        _citationSourcesKey,
        jsonEncode([
          for (final source in data.citationSources) source.toJson(),
        ]),
      );
      await _database.customStatement('DELETE FROM app_state WHERE key = ?', [
        _activeTimerKey,
      ]);
      await _putState(_initializedKey, '1');
      await _putState(_dataGenerationKey, generation);
      await _putState(_syncJournalBootstrappedKey, '1');

      for (final project in data.projects) {
        await _recordLocalChangeInTransaction(
          entityType: 'project',
          entityId: project.id,
          operation: 'snapshot',
          payload: project.toJson(),
        );
      }
      for (final task in data.tasks) {
        await _recordLocalChangeInTransaction(
          entityType: 'task',
          entityId: task.id,
          operation: 'snapshot',
          payload: task.toJson(),
        );
      }
      for (final note in data.notes) {
        await _recordLocalChangeInTransaction(
          entityType: 'note',
          entityId: note.id,
          operation: 'snapshot',
          payload: note.toJson(),
        );
      }
      for (final entry in data.entries) {
        await _recordLocalChangeInTransaction(
          entityType: 'time_entry',
          entityId: entry.id,
          operation: 'snapshot',
          payload: entry.toJson(),
        );
      }
    });
  }

  @override
  Future<void> saveProject(Project project) => _saveEntity(
    table: 'projects',
    values: project.toDb(),
    entityType: 'project',
    entityId: project.id,
    operation: 'upsert',
    payload: project.toJson(),
  );

  @override
  Future<void> saveTask(WorkTask task) => _saveEntity(
    table: 'tasks',
    values: task.toDb(),
    entityType: 'task',
    entityId: task.id,
    operation: 'upsert',
    payload: task.toJson(),
  );

  @override
  Future<void> softDeleteTask(String taskId, DateTime deletedAt) async {
    final encoded = deletedAt.toIso8601String();
    await _database.transaction(() async {
      await _database.customStatement(
        'UPDATE tasks SET deleted_at = ?, updated_at = ? WHERE id = ?',
        [encoded, encoded, taskId],
      );
      await _recordLocalChangeInTransaction(
        entityType: 'task',
        entityId: taskId,
        operation: 'delete',
        payload: {'deletedAt': encoded},
      );
    });
  }

  @override
  Future<void> restoreTask(String taskId) async {
    final restoredAt = DateTime.now().toIso8601String();
    await _database.transaction(() async {
      await _database.customStatement(
        'UPDATE tasks SET deleted_at = NULL, updated_at = ? WHERE id = ?',
        [restoredAt, taskId],
      );
      await _recordLocalChangeInTransaction(
        entityType: 'task',
        entityId: taskId,
        operation: 'restore',
        payload: {'restoredAt': restoredAt},
      );
    });
  }

  @override
  Future<void> saveNote(Note note) => _saveEntity(
    table: 'notes',
    values: note.toDb(),
    entityType: 'note',
    entityId: note.id,
    operation: 'upsert',
    payload: note.toJson(),
  );

  @override
  Future<void> saveNoteVersion(NoteVersion version) => _saveEntity(
    table: 'note_versions',
    values: version.toDb(),
    entityType: 'note_version',
    entityId: version.id,
    operation: 'append',
    payload: version.toJson(),
  );

  @override
  Future<void> saveCitationSources(List<CitationSource> sources) {
    return _putState(
      _citationSourcesKey,
      jsonEncode([for (final source in sources) source.toJson()]),
    );
  }

  Future<List<CitationSource>> _loadCitationSources() async {
    final raw = await _readState(_citationSourcesKey);
    if (raw == null || raw.trim().isEmpty) return <CitationSource>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <CitationSource>[];
      return decoded
          .whereType<Map>()
          .map(
            (item) => CitationSource.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } on Object {
      return <CitationSource>[];
    }
  }

  @override
  Future<void> replaceNoteLinks(String noteId, List<NoteLink> links) async {
    await _database.transaction(() async {
      await _database.customStatement(
        'DELETE FROM note_links WHERE source_note_id = ?',
        [noteId],
      );
      for (final link in links) {
        await _upsert('note_links', link.toDb());
      }
    });
  }

  @override
  Future<void> saveTimeEntry(TimeEntry entry) => _saveEntity(
    table: 'time_entries',
    values: entry.toDb(),
    entityType: 'time_entry',
    entityId: entry.id,
    operation: 'append',
    payload: entry.toJson(),
  );

  @override
  Future<void> appendTimeEntryAndClearTimer(TimeEntry entry) async {
    await _database.transaction(() async {
      await _upsert('time_entries', entry.toDb());
      await _recordLocalChangeInTransaction(
        entityType: 'time_entry',
        entityId: entry.id,
        operation: 'append',
        payload: entry.toJson(),
      );
      await _database.customStatement('DELETE FROM app_state WHERE key = ?', [
        _activeTimerKey,
      ]);
    });
  }

  @override
  Future<void> deleteTaskGraph(String taskId, DateTime deletedAt) async {
    final encoded = deletedAt.toIso8601String();
    await _database.transaction(() async {
      final childRows =
          await _database
              .customSelect(
                'SELECT * FROM tasks WHERE parent_task_id = ?',
                variables: [Variable<String>(taskId)],
              )
              .get();
      for (final row in childRows) {
        final child =
            WorkTask.fromDb(row.data)
              ..parentTaskId = null
              ..updatedAt = deletedAt;
        await _upsert('tasks', child.toDb());
        await _recordLocalChangeInTransaction(
          entityType: 'task',
          entityId: child.id,
          operation: 'upsert',
          payload: child.toJson(),
        );
      }
      await _database.customStatement(
        'UPDATE tasks SET deleted_at = ?, updated_at = ? WHERE id = ?',
        [encoded, encoded, taskId],
      );
      await _recordLocalChangeInTransaction(
        entityType: 'task',
        entityId: taskId,
        operation: 'delete',
        payload: {'deletedAt': encoded},
      );
    });
  }

  @override
  Future<void> deleteNoteGraph(String noteId, DateTime deletedAt) async {
    final encoded = deletedAt.toIso8601String();
    await _database.transaction(() async {
      final taskRows =
          await _database
              .customSelect(
                'SELECT * FROM tasks WHERE note_id = ?',
                variables: [Variable<String>(noteId)],
              )
              .get();
      for (final row in taskRows) {
        final task =
            WorkTask.fromDb(row.data)
              ..noteId = null
              ..updatedAt = deletedAt;
        await _upsert('tasks', task.toDb());
        await _recordLocalChangeInTransaction(
          entityType: 'task',
          entityId: task.id,
          operation: 'upsert',
          payload: task.toJson(),
        );
      }
      await _database.customStatement(
        'DELETE FROM note_links '
        'WHERE source_note_id = ? OR target_note_id = ?',
        [noteId, noteId],
      );
      await _database.customStatement(
        'UPDATE notes SET deleted_at = ?, updated_at = ? WHERE id = ?',
        [encoded, encoded, noteId],
      );
      await _recordLocalChangeInTransaction(
        entityType: 'note',
        entityId: noteId,
        operation: 'delete',
        payload: {'deletedAt': encoded},
      );
    });
  }

  @override
  Future<void> softDeleteNote(String noteId, DateTime deletedAt) async {
    final encoded = deletedAt.toIso8601String();
    await _database.transaction(() async {
      await _database.customStatement(
        'UPDATE notes SET deleted_at = ?, updated_at = ? WHERE id = ?',
        [encoded, encoded, noteId],
      );
      await _recordLocalChangeInTransaction(
        entityType: 'note',
        entityId: noteId,
        operation: 'delete',
        payload: {'deletedAt': encoded},
      );
    });
  }

  @override
  Future<void> restoreNote(String noteId) async {
    final restoredAt = DateTime.now().toIso8601String();
    await _database.transaction(() async {
      await _database.customStatement(
        'UPDATE notes SET deleted_at = NULL, updated_at = ? WHERE id = ?',
        [restoredAt, noteId],
      );
      await _recordLocalChangeInTransaction(
        entityType: 'note',
        entityId: noteId,
        operation: 'restore',
        payload: {'restoredAt': restoredAt},
      );
    });
  }

  @override
  Future<void> saveActiveTimer(ActiveTimerState? timer) async {
    if (timer == null) {
      await _database.customStatement('DELETE FROM app_state WHERE key = ?', [
        _activeTimerKey,
      ]);
      return;
    }

    await _putState(_activeTimerKey, jsonEncode(timer.toJson()));
  }

  @override
  Future<ActiveTimerState?> loadActiveTimer() async {
    final value = await _readState(_activeTimerKey);
    if (value == null) {
      return null;
    }

    try {
      final decoded = jsonDecode(value) as Map<String, dynamic>;
      return ActiveTimerState.fromJson(decoded);
    } on Object {
      await _database.customStatement('DELETE FROM app_state WHERE key = ?', [
        _activeTimerKey,
      ]);
      return null;
    }
  }

  @override
  Future<DeviceIdentity> ensureDeviceIdentity() async {
    final cached = _identityCache;
    if (cached != null) {
      return cached;
    }

    final rows = await _readRows(
      'SELECT * FROM device_identity ORDER BY created_at LIMIT 1',
    );
    if (rows.isNotEmpty) {
      final identity = DeviceIdentity.fromDb(rows.single);
      identity.lastSeenAt = DateTime.now();
      await _upsert('device_identity', identity.toDb());
      _identityCache = identity;
      return identity;
    }

    final now = DateTime.now();
    final identity = DeviceIdentity(
      deviceId: _uuid.v4(),
      displayName: defaultDeviceDisplayName(),
      platform: currentPlatformCode(),
      createdAt: now,
      lastSeenAt: now,
    );
    await _upsert('device_identity', identity.toDb());
    _identityCache = identity;
    return identity;
  }

  @override
  Future<void> saveDeviceIdentity(DeviceIdentity identity) async {
    identity.lastSeenAt = DateTime.now();
    await _upsert('device_identity', identity.toDb());
    _identityCache = identity;
  }

  @override
  Future<DeviceKeyMaterial?> loadDeviceKeyMaterial() async {
    final raw = await _readState(_deviceKeyMaterialKey);
    if (raw == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return DeviceKeyMaterial.fromJson(decoded);
      }
      if (decoded is Map) {
        return DeviceKeyMaterial.fromJson(Map<String, dynamic>.from(decoded));
      }
    } on Object {
      return null;
    }
    return null;
  }

  @override
  Future<void> saveDeviceKeyMaterial(DeviceKeyMaterial material) {
    return _putState(_deviceKeyMaterialKey, jsonEncode(material.toJson()));
  }

  @override
  Future<void> deleteDeviceKeyMaterial() {
    return _deleteState(_deviceKeyMaterialKey);
  }

  @override
  Future<List<TrustedDevice>> loadTrustedDevices({
    bool includeRevoked = false,
  }) async {
    final where = includeRevoked ? '' : 'WHERE revoked_at IS NULL ';
    final rows = await _readRows(
      'SELECT * FROM trusted_devices '
      '${where}ORDER BY COALESCE(last_sync_at, paired_at) DESC',
    );
    return rows.map(TrustedDevice.fromDb).toList(growable: false);
  }

  @override
  Future<void> saveTrustedDevice(TrustedDevice device) async {
    await _upsert('trusted_devices', device.toDb());
  }

  @override
  Future<void> revokeTrustedDevice(String deviceId, DateTime revokedAt) async {
    await _database.customStatement(
      'UPDATE trusted_devices SET revoked_at = ? WHERE device_id = ?',
      [revokedAt.toIso8601String(), deviceId],
    );
  }

  @override
  Future<SyncPreferences> loadSyncPreferences() async {
    final raw = await _readState(_syncPreferencesKey);
    if (raw == null) {
      return const SyncPreferences();
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return SyncPreferences.fromJson(decoded);
    } on Object {
      return const SyncPreferences();
    }
  }

  @override
  Future<void> saveSyncPreferences(SyncPreferences preferences) {
    return _putState(_syncPreferencesKey, jsonEncode(preferences.toJson()));
  }

  @override
  Future<List<ChangeRecord>> loadRecentChanges({int limit = 30}) async {
    final safeLimit = limit.clamp(1, 500);
    final rows = await _readRows(
      'SELECT * FROM change_records '
      'ORDER BY local_sequence DESC LIMIT $safeLimit',
    );
    return rows.map(ChangeRecord.fromDb).toList(growable: false);
  }

  @override
  Future<int> countJournalEntries() async {
    final rows =
        await _database
            .customSelect('SELECT COUNT(*) AS total FROM change_records')
            .get();
    return rows.single.read<int>('total');
  }

  @override
  Future<JournalCompactionResult> compactJournal({
    int maxEntries = defaultMaxJournalEntries,
    int maxPayloadBytes = defaultMaxJournalPayloadBytes,
  }) {
    _validateJournalBudgets(maxEntries, maxPayloadBytes);
    return _database.transaction(
      () => _compactJournalInTransaction(
        maxEntries: maxEntries,
        maxPayloadBytes: maxPayloadBytes,
      ),
    );
  }

  @override
  Future<bool> isSyncJournalBootstrapped() async {
    return await _readState(_syncJournalBootstrappedKey) == '1';
  }

  @override
  Future<void> markSyncJournalBootstrapped() {
    return _putState(_syncJournalBootstrappedKey, '1');
  }

  @override
  Future<ChangeRecord> recordLocalChange({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) {
    return _database.transaction(
      () => _recordLocalChangeInTransaction(
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        payload: payload,
      ),
    );
  }

  @override
  Future<SyncJournalBatch> loadOutgoingChanges({
    required String peerDeviceId,
    required int afterSequence,
    int limit = 200,
  }) async {
    final safeAfter = afterSequence < 0 ? 0 : afterSequence;
    final safeLimit = limit.clamp(1, 1000).toInt();
    final rows =
        await _database
            .customSelect(
              'SELECT * FROM change_records '
              'WHERE local_sequence > ? '
              'ORDER BY local_sequence ASC LIMIT ?',
              variables: [
                Variable<int>(safeAfter),
                Variable<int>(safeLimit + 1),
              ],
            )
            .get();
    final hasMore = rows.length > safeLimit;
    final scannedRows = rows.take(safeLimit).toList(growable: false);
    final scanned = scannedRows
        .map((row) => ChangeRecord.fromDb(row.data))
        .toList(growable: false);
    return SyncJournalBatch(
      afterSequence: safeAfter,
      throughSequence: scanned.isEmpty ? safeAfter : scanned.last.localSequence,
      changes: scanned
          .where((change) => change.originDeviceId != peerDeviceId)
          .toList(growable: false),
      hasMore: hasMore,
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

    await _database.transaction(() async {
      for (final incoming in ordered) {
        if (await _containsChangeInTransaction(incoming.changeId)) {
          duplicateCount++;
          continue;
        }

        final currentWinner = await _freshestChangeInTransaction(
          entityType: incoming.entityType,
          entityId: incoming.entityId,
        );
        final stored = ChangeRecord(
          localSequence: 0,
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
        await _insertRemoteChangeInTransaction(stored);
        insertedCount++;

        if (currentWinner != null &&
            compareChangeFreshness(stored, currentWinner) <= 0) {
          staleCount++;
          continue;
        }

        if (await _applyRemoteEntityInTransaction(stored)) {
          appliedCount++;
        } else {
          unsupportedCount++;
        }
      }
      await _compactJournalIfNeededInTransaction();
    });

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
  Future<List<SyncCursor>> loadSyncCursors() async {
    final rows = await _readRows(
      'SELECT * FROM sync_cursors ORDER BY last_success_at DESC',
    );
    return rows.map(SyncCursor.fromDb).toList(growable: false);
  }

  @override
  Future<void> saveSyncCursor(SyncCursor cursor) async {
    await _upsert('sync_cursors', cursor.toDb());
  }

  @override
  Future<String> exportJson() async => (await load()).encode();

  @override
  Future<void> close() => _database.close();

  Future<void> _saveEntity({
    required String table,
    required Map<String, Object?> values,
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    await _database.transaction(() async {
      await _upsert(table, values);
      await _recordLocalChangeInTransaction(
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        payload: payload,
      );
    });
  }

  Future<bool> _containsChangeInTransaction(String changeId) async {
    final rows =
        await _database
            .customSelect(
              'SELECT 1 AS present FROM change_records '
              'WHERE change_id = ? LIMIT 1',
              variables: [Variable<String>(changeId)],
            )
            .get();
    return rows.isNotEmpty;
  }

  Future<ChangeRecord?> _freshestChangeInTransaction({
    required String entityType,
    required String entityId,
  }) async {
    final rows =
        await _database
            .customSelect(
              'SELECT * FROM change_records '
              'WHERE entity_type = ? AND entity_id = ?',
              variables: [
                Variable<String>(entityType),
                Variable<String>(entityId),
              ],
            )
            .get();
    ChangeRecord? winner;
    for (final row in rows) {
      final candidate = ChangeRecord.fromDb(row.data);
      if (winner == null || compareChangeFreshness(candidate, winner) > 0) {
        winner = candidate;
      }
    }
    return winner;
  }

  Future<void> _insertRemoteChangeInTransaction(ChangeRecord change) async {
    await _ensureJournalMetricsInTransaction();
    await _database.customStatement(
      'INSERT INTO change_records ('
      'change_id, entity_type, entity_id, operation, revision, '
      'origin_device_id, changed_at, payload_json, applied_at'
      ') VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        change.changeId,
        change.entityType,
        change.entityId,
        change.operation,
        change.revision,
        change.originDeviceId,
        change.changedAt.toUtc().toIso8601String(),
        change.payloadJson,
        change.appliedAt?.toUtc().toIso8601String(),
      ],
    );
    await _incrementJournalMetricsInTransaction(change.payloadJson);
  }

  Future<bool> _applyRemoteEntityInTransaction(ChangeRecord change) async {
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
        _verifyRemoteEntityId(change, project.id);
        await _upsert('projects', project.toDb());
        return true;
      case 'task':
        if (change.operation == 'delete') {
          final deletedAt =
              DateTime.tryParse('${payload['deletedAt']}') ?? change.changedAt;
          await _database.customStatement(
            'UPDATE tasks SET deleted_at = ?, updated_at = ? WHERE id = ?',
            [
              deletedAt.toUtc().toIso8601String(),
              deletedAt.toUtc().toIso8601String(),
              change.entityId,
            ],
          );
          return true;
        }
        if (change.operation == 'restore') {
          await _database.customStatement(
            'UPDATE tasks SET deleted_at = NULL, updated_at = ? WHERE id = ?',
            [change.changedAt.toUtc().toIso8601String(), change.entityId],
          );
          return true;
        }
        if (!upsertOperation) {
          return false;
        }
        final task = WorkTask.fromJson(payload);
        _verifyRemoteEntityId(change, task.id);
        await _upsert('tasks', task.toDb());
        return true;
      case 'note':
        if (change.operation == 'delete') {
          final deletedAt =
              DateTime.tryParse('${payload['deletedAt']}') ?? change.changedAt;
          await _database.customStatement(
            'UPDATE notes SET deleted_at = ?, updated_at = ? WHERE id = ?',
            [
              deletedAt.toUtc().toIso8601String(),
              deletedAt.toUtc().toIso8601String(),
              change.entityId,
            ],
          );
          return true;
        }
        if (change.operation == 'restore') {
          await _database.customStatement(
            'UPDATE notes SET deleted_at = NULL, updated_at = ? WHERE id = ?',
            [change.changedAt.toUtc().toIso8601String(), change.entityId],
          );
          return true;
        }
        if (!upsertOperation) {
          return false;
        }
        final note = Note.fromJson(payload);
        _verifyRemoteEntityId(change, note.id);
        await _upsert('notes', note.toDb());
        return true;
      case 'note_version':
        if (!upsertOperation) {
          return false;
        }
        final version = NoteVersion.fromJson(payload);
        _verifyRemoteEntityId(change, version.id);
        await _upsert('note_versions', version.toDb());
        return true;
      case 'time_entry':
        if (!upsertOperation) {
          return false;
        }
        final entry = TimeEntry.fromJson(payload);
        _verifyRemoteEntityId(change, entry.id);
        await _upsert('time_entries', entry.toDb());
        return true;
      default:
        return false;
    }
  }

  void _verifyRemoteEntityId(ChangeRecord change, String payloadId) {
    if (payloadId != change.entityId) {
      throw FormatException(
        'Sync change ${change.changeId} has mismatched entity id.',
      );
    }
  }

  Future<ChangeRecord> _recordLocalChangeInTransaction({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final identity = await ensureDeviceIdentity();
    final revisionRows =
        await _database
            .customSelect(
              'SELECT COALESCE(MAX(revision), 0) + 1 AS next_revision '
              'FROM change_records WHERE entity_type = ? AND entity_id = ?',
              variables: [
                Variable<String>(entityType),
                Variable<String>(entityId),
              ],
            )
            .get();
    final revision = revisionRows.single.read<int>('next_revision');
    final changedAt = DateTime.now();
    final changeId = _uuid.v4();
    final payloadJson = jsonEncode(payload);

    await _ensureJournalMetricsInTransaction();
    await _database.customStatement(
      'INSERT INTO change_records ('
      'change_id, entity_type, entity_id, operation, revision, '
      'origin_device_id, changed_at, payload_json, applied_at'
      ') VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL)',
      [
        changeId,
        entityType,
        entityId,
        operation,
        revision,
        identity.deviceId,
        changedAt.toIso8601String(),
        payloadJson,
      ],
    );
    await _incrementJournalMetricsInTransaction(payloadJson);
    await _compactJournalIfNeededInTransaction();

    final sequenceRows =
        await _database
            .customSelect(
              'SELECT local_sequence FROM change_records WHERE change_id = ? LIMIT 1',
              variables: [Variable<String>(changeId)],
            )
            .get();

    return ChangeRecord(
      localSequence: sequenceRows.single.read<int>('local_sequence'),
      changeId: changeId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      revision: revision,
      originDeviceId: identity.deviceId,
      changedAt: changedAt,
      payloadJson: payloadJson,
    );
  }

  Future<void> _compactJournalIfNeededInTransaction() async {
    final metrics = await _ensureJournalMetricsInTransaction();
    if (metrics.entryCount <= _automaticJournalMaxEntries &&
        metrics.payloadBytes <= _automaticJournalMaxPayloadBytes) {
      return;
    }
    if (metrics.entryCount < _nextAutomaticCompactionEntryCount &&
        metrics.payloadBytes < _nextAutomaticCompactionPayloadBytes) {
      return;
    }
    final result = await _compactJournalInTransaction(
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

  Future<JournalCompactionResult> _compactJournalInTransaction({
    required int maxEntries,
    required int maxPayloadBytes,
  }) async {
    final before = await _ensureJournalMetricsInTransaction();
    final metadata = await _readJournalCompactionMetadataInTransaction();
    final minimumPeerCursor = await _minimumPeerCursorInTransaction();
    if (before.entryCount <= maxEntries &&
        before.payloadBytes <= maxPayloadBytes) {
      return JournalCompactionResult(
        didCompact: false,
        entryCountBefore: before.entryCount,
        entryCountAfter: before.entryCount,
        payloadBytesBefore: before.payloadBytes,
        payloadBytesAfter: before.payloadBytes,
        generation: metadata.generation,
        lastCompactedSequence: metadata.lastCompactedSequence,
        minimumPeerCursor: minimumPeerCursor,
        maxEntries: maxEntries,
        maxPayloadBytes: maxPayloadBytes,
      );
    }
    final candidateRows =
        await _database
            .customSelect(
              'SELECT local_sequence, change_id, entity_type, entity_id, '
              'operation, revision, changed_at FROM change_records',
            )
            .get();
    final winners = <String, _JournalCandidate>{};
    var maxSequenceBefore = 0;
    for (final row in candidateRows) {
      final candidate = _JournalCandidate(
        localSequence: row.read<int>('local_sequence'),
        changeId: row.read<String>('change_id'),
        entityType: row.read<String>('entity_type'),
        entityId: row.read<String>('entity_id'),
        operation: row.read<String>('operation'),
        revision: row.read<int>('revision'),
        changedAt: DateTime.parse(row.read<String>('changed_at')).toUtc(),
      );
      if (candidate.localSequence > maxSequenceBefore) {
        maxSequenceBefore = candidate.localSequence;
      }
      final current = winners[candidate.entityKey];
      if (current == null || candidate.isFresherThan(current)) {
        winners[candidate.entityKey] = candidate;
      }
    }
    final restoreWinners = winners.values
        .where((candidate) => candidate.operation == 'restore')
        .toList(growable: false);
    final removableCount = before.entryCount - winners.length;
    if (removableCount == 0 && restoreWinners.isEmpty) {
      return JournalCompactionResult(
        didCompact: false,
        entryCountBefore: before.entryCount,
        entryCountAfter: before.entryCount,
        payloadBytesBefore: before.payloadBytes,
        payloadBytesAfter: before.payloadBytes,
        generation: metadata.generation,
        lastCompactedSequence: metadata.lastCompactedSequence,
        minimumPeerCursor: minimumPeerCursor,
        maxEntries: maxEntries,
        maxPayloadBytes: maxPayloadBytes,
      );
    }

    for (final winner in restoreWinners) {
      await _canonicalizeRestoreWinnerInTransaction(
        localSequence: winner.localSequence,
        entityType: winner.entityType,
        entityId: winner.entityId,
        changedAt: winner.changedAt.toIso8601String(),
      );
    }
    if (removableCount > 0) {
      await _deleteSupersededJournalRowsInTransaction(
        winners.values
            .map((candidate) => candidate.localSequence)
            .toList(growable: false),
      );
    }

    final after = await _readActualJournalMetricsInTransaction();
    await _writeJournalMetricsInTransaction(after);
    final nextMetadata = _JournalCompactionMetadata(
      generation: metadata.generation + 1,
      lastCompactedSequence: maxSequenceBefore,
    );
    await _putState(
      _journalCompactionMetadataKey,
      jsonEncode(nextMetadata.toJson(minimumPeerCursor: minimumPeerCursor)),
    );
    return JournalCompactionResult(
      didCompact: true,
      entryCountBefore: before.entryCount,
      entryCountAfter: after.entryCount,
      payloadBytesBefore: before.payloadBytes,
      payloadBytesAfter: after.payloadBytes,
      generation: nextMetadata.generation,
      lastCompactedSequence: nextMetadata.lastCompactedSequence,
      minimumPeerCursor: minimumPeerCursor,
      maxEntries: maxEntries,
      maxPayloadBytes: maxPayloadBytes,
    );
  }

  Future<void> _deleteSupersededJournalRowsInTransaction(
    List<int> winnerSequences,
  ) async {
    const table = 'chronicle_journal_compaction_winners';
    await _database.customStatement('DROP TABLE IF EXISTS temp.$table');
    try {
      await _database.customStatement(
        'CREATE TEMP TABLE $table (local_sequence INTEGER PRIMARY KEY)',
      );
      const chunkSize = 400;
      for (var start = 0; start < winnerSequences.length; start += chunkSize) {
        final end = (start + chunkSize).clamp(0, winnerSequences.length);
        final chunk = winnerSequences.sublist(start, end);
        final placeholders = List<String>.filled(
          chunk.length,
          '(?)',
        ).join(', ');
        await _database.customStatement(
          'INSERT INTO $table (local_sequence) VALUES $placeholders',
          chunk,
        );
      }
      await _database.customStatement(
        'DELETE FROM change_records WHERE local_sequence NOT IN '
        '(SELECT local_sequence FROM $table)',
      );
    } finally {
      await _database.customStatement('DROP TABLE IF EXISTS temp.$table');
    }
  }

  Future<void> _canonicalizeRestoreWinnerInTransaction({
    required int localSequence,
    required String entityType,
    required String entityId,
    required String changedAt,
  }) async {
    Map<String, dynamic>? payload;
    String? deletedAt;
    if (entityType == 'note') {
      final rows =
          await _database
              .customSelect(
                'SELECT * FROM notes WHERE id = ? LIMIT 1',
                variables: [Variable<String>(entityId)],
              )
              .get();
      if (rows.isNotEmpty) {
        final note = Note.fromDb(rows.single.data);
        deletedAt = note.deletedAt?.toUtc().toIso8601String();
        if (deletedAt == null) {
          payload = note.toJson();
        }
      }
    } else if (entityType == 'task') {
      final rows =
          await _database
              .customSelect(
                'SELECT * FROM tasks WHERE id = ? LIMIT 1',
                variables: [Variable<String>(entityId)],
              )
              .get();
      if (rows.isNotEmpty) {
        final task = WorkTask.fromDb(rows.single.data);
        deletedAt = task.deletedAt?.toUtc().toIso8601String();
        if (deletedAt == null) {
          payload = task.toJson();
        }
      }
    } else {
      return;
    }
    final operation = payload == null ? 'delete' : 'snapshot';
    final payloadJson = jsonEncode(
      payload ?? <String, dynamic>{'deletedAt': deletedAt ?? changedAt},
    );
    await _database.customStatement(
      'UPDATE change_records SET operation = ?, payload_json = ? '
      'WHERE local_sequence = ?',
      [operation, payloadJson, localSequence],
    );
  }

  Future<_JournalMetrics> _ensureJournalMetricsInTransaction() async {
    if (!_journalMetricsValidated) {
      final actual = await _readActualJournalMetricsInTransaction();
      await _writeJournalMetricsInTransaction(actual);
      _journalMetricsValidated = true;
      return actual;
    }
    final rows =
        await _database
            .customSelect(
              'SELECT key, value FROM app_state WHERE key IN (?, ?)',
              variables: [
                Variable<String>(_journalEntryCountKey),
                Variable<String>(_journalPayloadBytesKey),
              ],
            )
            .get();
    int? entryCount;
    int? payloadBytes;
    for (final row in rows) {
      final key = row.read<String>('key');
      final value = int.tryParse(row.read<String>('value'));
      if (key == _journalEntryCountKey) {
        entryCount = value;
      } else if (key == _journalPayloadBytesKey) {
        payloadBytes = value;
      }
    }
    if (entryCount != null &&
        entryCount >= 0 &&
        payloadBytes != null &&
        payloadBytes >= 0) {
      return _JournalMetrics(
        entryCount: entryCount,
        payloadBytes: payloadBytes,
      );
    }
    final actual = await _readActualJournalMetricsInTransaction();
    await _writeJournalMetricsInTransaction(actual);
    return actual;
  }

  Future<_JournalMetrics> _readActualJournalMetricsInTransaction() async {
    final rows =
        await _database
            .customSelect(
              'SELECT COUNT(*) AS entry_count, '
              'COALESCE(SUM(LENGTH(CAST(payload_json AS BLOB))), 0) '
              'AS payload_bytes FROM change_records',
            )
            .get();
    return _JournalMetrics(
      entryCount: rows.single.read<int>('entry_count'),
      payloadBytes: rows.single.read<int>('payload_bytes'),
    );
  }

  Future<void> _writeJournalMetricsInTransaction(
    _JournalMetrics metrics,
  ) async {
    await _putState(_journalEntryCountKey, '${metrics.entryCount}');
    await _putState(_journalPayloadBytesKey, '${metrics.payloadBytes}');
  }

  Future<void> _incrementJournalMetricsInTransaction(String payloadJson) async {
    final payloadBytes = utf8.encode(payloadJson).length;
    await _database.customStatement(
      'UPDATE app_state SET value = '
      'CAST(CAST(value AS INTEGER) + 1 AS TEXT) WHERE key = ?',
      [_journalEntryCountKey],
    );
    await _database.customStatement(
      'UPDATE app_state SET value = '
      'CAST(CAST(value AS INTEGER) + ? AS TEXT) WHERE key = ?',
      [payloadBytes, _journalPayloadBytesKey],
    );
  }

  Future<int?> _minimumPeerCursorInTransaction() async {
    final rows =
        await _database
            .customSelect(
              'SELECT MIN(last_sent_sequence) AS minimum_cursor '
              'FROM sync_cursors',
            )
            .get();
    return rows.single.readNullable<int>('minimum_cursor');
  }

  Future<_JournalCompactionMetadata>
  _readJournalCompactionMetadataInTransaction() async {
    final raw = await _readState(_journalCompactionMetadataKey);
    if (raw == null) {
      return const _JournalCompactionMetadata();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return _JournalCompactionMetadata.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    } on Object {
      // Invalid diagnostics metadata is safely rebuilt after compaction.
    }
    return const _JournalCompactionMetadata();
  }

  Future<List<Map<String, Object?>>> _readRows(String sql) async {
    final rows = await _database.customSelect(sql).get();
    return rows.map((row) => row.data).toList(growable: false);
  }

  Future<String?> _readState(String key) async {
    final rows =
        await _database
            .customSelect(
              'SELECT value FROM app_state WHERE key = ? LIMIT 1',
              variables: [Variable<String>(key)],
            )
            .get();
    if (rows.isEmpty) {
      return null;
    }
    return rows.single.read<String>('value');
  }

  Future<void> _putState(String key, String value) async {
    await _database.customStatement(
      'INSERT INTO app_state (key, value) VALUES (?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      [key, value],
    );
  }

  Future<void> _deleteState(String key) async {
    await _database.customStatement('DELETE FROM app_state WHERE key = ?', [
      key,
    ]);
  }

  Future<void> _upsert(String table, Map<String, Object?> values) async {
    final columns = values.keys.toList(growable: false);
    final placeholders = List.filled(columns.length, '?').join(', ');
    final conflictColumn = switch (table) {
      'device_identity' || 'trusted_devices' => 'device_id',
      'sync_cursors' => 'peer_device_id',
      _ => 'id',
    };
    final updates = columns
        .where((column) => column != conflictColumn)
        .map((column) => '$column = excluded.$column')
        .join(', ');

    final conflictAction =
        updates.isEmpty ? 'DO NOTHING' : 'DO UPDATE SET $updates';

    await _database.customStatement(
      'INSERT INTO $table (${columns.join(', ')}) '
      'VALUES ($placeholders) '
      'ON CONFLICT($conflictColumn) $conflictAction',
      columns.map((column) => values[column]).toList(growable: false),
    );
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

class _JournalMetrics {
  const _JournalMetrics({required this.entryCount, required this.payloadBytes});

  final int entryCount;
  final int payloadBytes;
}

class _JournalCandidate {
  const _JournalCandidate({
    required this.localSequence,
    required this.changeId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.revision,
    required this.changedAt,
  });

  final int localSequence;
  final String changeId;
  final String entityType;
  final String entityId;
  final String operation;
  final int revision;
  final DateTime changedAt;

  String get entityKey => '$entityType\u0000$entityId';

  bool isFresherThan(_JournalCandidate other) {
    final revisionOrder = revision.compareTo(other.revision);
    if (revisionOrder != 0) {
      return revisionOrder > 0;
    }
    final timeOrder = changedAt.compareTo(other.changedAt);
    if (timeOrder != 0) {
      return timeOrder > 0;
    }
    return changeId.compareTo(other.changeId) > 0;
  }
}

class _JournalCompactionMetadata {
  const _JournalCompactionMetadata({
    this.generation = 0,
    this.lastCompactedSequence = 0,
  });

  final int generation;
  final int lastCompactedSequence;

  Map<String, dynamic> toJson({required int? minimumPeerCursor}) => {
    'generation': generation,
    'lastCompactedSequence': lastCompactedSequence,
    'minimumPeerCursor': minimumPeerCursor,
  };

  factory _JournalCompactionMetadata.fromJson(Map<String, dynamic> json) {
    return _JournalCompactionMetadata(
      generation: _nonNegativeInt(json['generation']),
      lastCompactedSequence: _nonNegativeInt(json['lastCompactedSequence']),
    );
  }
}

int _nonNegativeInt(Object? value) {
  final parsed = switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text) ?? 0,
    _ => 0,
  };
  return parsed < 0 ? 0 : parsed;
}
