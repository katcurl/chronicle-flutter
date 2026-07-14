import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../models/app_models.dart';
import '../../sync/sync_models.dart';
import '../database/chronicle_database.dart';
import 'app_repository.dart';

class DriftAppRepository implements AppRepository {
  DriftAppRepository({ChronicleDatabase? database})
    : _database = database ?? ChronicleDatabase.defaults();

  static const _initializedKey = 'initialized';
  static const _activeTimerKey = 'active_timer';
  static const _syncPreferencesKey = 'sync_preferences';
  static const _syncJournalBootstrappedKey = 'sync_journal_bootstrapped';

  final ChronicleDatabase _database;
  final Uuid _uuid = const Uuid();
  DeviceIdentity? _identityCache;

  @override
  Future<bool> isInitialized() async {
    final value = await _readState(_initializedKey);
    return value == '1';
  }

  @override
  Future<void> markInitialized() => _putState(_initializedKey, '1');

  @override
  Future<AppData> load() async {
    final results = await Future.wait([
      _readRows('SELECT * FROM projects ORDER BY updated_at DESC'),
      _readRows(
        'SELECT * FROM tasks '
        'WHERE deleted_at IS NULL ORDER BY updated_at DESC',
      ),
      _readRows(
        'SELECT * FROM notes '
        'WHERE deleted_at IS NULL ORDER BY updated_at DESC',
      ),
      _readRows('SELECT * FROM time_entries ORDER BY started_at DESC'),
      _readRows('SELECT * FROM note_links ORDER BY created_at DESC'),
      _readRows('SELECT * FROM note_versions ORDER BY created_at DESC'),
    ]);

    return AppData(
      projects: results[0].map(Project.fromDb).toList(),
      tasks: results[1].map(WorkTask.fromDb).toList(),
      notes: results[2].map(Note.fromDb).toList(),
      entries: results[3].map(TimeEntry.fromDb).toList(),
      noteLinks: results[4].map(NoteLink.fromDb).toList(),
      noteVersions: results[5].map(NoteVersion.fromDb).toList(),
    );
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
  Future<void> importJson(String raw) async {
    await replaceAll(AppData.decode(raw));
    await markInitialized();
  }

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
