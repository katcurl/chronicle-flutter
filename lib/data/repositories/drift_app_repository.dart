import 'dart:convert';

import 'package:drift/drift.dart';

import '../../models/app_models.dart';
import '../database/chronicle_database.dart';
import 'app_repository.dart';

class DriftAppRepository implements AppRepository {
  DriftAppRepository({ChronicleDatabase? database})
    : _database = database ?? ChronicleDatabase.defaults();

  static const _initializedKey = 'initialized';
  static const _activeTimerKey = 'active_timer';

  final ChronicleDatabase _database;

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
  }

  @override
  Future<void> saveProject(Project project) =>
      _upsert('projects', project.toDb());

  @override
  Future<void> saveTask(WorkTask task) => _upsert('tasks', task.toDb());

  @override
  Future<void> softDeleteTask(String taskId, DateTime deletedAt) async {
    final encoded = deletedAt.toIso8601String();
    await _database.customStatement(
      'UPDATE tasks SET deleted_at = ?, updated_at = ? WHERE id = ?',
      [encoded, encoded, taskId],
    );
  }

  @override
  Future<void> saveNote(Note note) => _upsert('notes', note.toDb());

  @override
  Future<void> saveNoteVersion(NoteVersion version) =>
      _upsert('note_versions', version.toDb());

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
  Future<void> saveTimeEntry(TimeEntry entry) =>
      _upsert('time_entries', entry.toDb());

  @override
  Future<void> softDeleteNote(String noteId, DateTime deletedAt) async {
    final encoded = deletedAt.toIso8601String();
    await _database.customStatement(
      'UPDATE notes SET deleted_at = ?, updated_at = ? WHERE id = ?',
      [encoded, encoded, noteId],
    );
  }

  @override
  Future<void> restoreNote(String noteId) async {
    await _database.customStatement(
      'UPDATE notes SET deleted_at = NULL, updated_at = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), noteId],
    );
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
    if (value == null) return null;

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
  Future<String> exportJson() async => (await load()).encode();

  @override
  Future<void> importJson(String raw) async {
    await replaceAll(AppData.decode(raw));
    await markInitialized();
  }

  @override
  Future<void> close() => _database.close();

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
    if (rows.isEmpty) return null;
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
    final updates = columns
        .where((column) => column != 'id')
        .map((column) => '$column = excluded.$column')
        .join(', ');

    await _database.customStatement(
      'INSERT INTO $table (${columns.join(', ')}) '
      'VALUES ($placeholders) '
      'ON CONFLICT(id) DO UPDATE SET $updates',
      columns.map((column) => values[column]).toList(growable: false),
    );
  }
}
