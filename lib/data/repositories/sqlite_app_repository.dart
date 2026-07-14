import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../models/app_models.dart';
import '../database/chronicle_database.dart';
import 'app_repository.dart';

class SqliteAppRepository implements AppRepository {
  SqliteAppRepository({ChronicleDatabase? database})
      : _database = database ?? ChronicleDatabase.instance;

  static const _initializedKey = 'initialized';
  static const _activeTimerKey = 'active_timer';

  final ChronicleDatabase _database;

  @override
  Future<bool> isInitialized() async {
    final database = await _database.database;
    final rows = await database.query(
      'app_state',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_initializedKey],
      limit: 1,
    );
    return rows.isNotEmpty && rows.first['value'] == '1';
  }

  @override
  Future<void> markInitialized() async {
    final database = await _database.database;
    await _putState(database, _initializedKey, '1');
  }

  @override
  Future<AppData> load() async {
    final database = await _database.database;
    final results = await Future.wait([
      database.query(
        'projects',
        where: 'archived = 0',
        orderBy: 'updated_at DESC',
      ),
      database.query(
        'tasks',
        where: 'deleted_at IS NULL',
        orderBy: 'updated_at DESC',
      ),
      database.query(
        'notes',
        where: 'deleted_at IS NULL',
        orderBy: 'updated_at DESC',
      ),
      database.query(
        'time_entries',
        orderBy: 'started_at DESC',
      ),
    ]);

    return AppData(
      projects: results[0].map(Project.fromDb).toList(),
      tasks: results[1].map(WorkTask.fromDb).toList(),
      notes: results[2].map(Note.fromDb).toList(),
      entries: results[3].map(TimeEntry.fromDb).toList(),
    );
  }

  @override
  Future<void> replaceAll(AppData data) async {
    final database = await _database.database;
    await database.transaction((transaction) async {
      await transaction.delete('time_entries');
      await transaction.delete('tasks');
      await transaction.delete('notes');
      await transaction.delete('projects');

      final batch = transaction.batch();
      for (final project in data.projects) {
        batch.insert('projects', project.toDb());
      }
      for (final note in data.notes) {
        batch.insert('notes', note.toDb());
      }
      for (final task in data.tasks) {
        batch.insert('tasks', task.toDb());
      }
      for (final entry in data.entries) {
        batch.insert('time_entries', entry.toDb());
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> saveProject(Project project) async {
    final database = await _database.database;
    await _upsert(database, 'projects', project.toDb());
  }

  @override
  Future<void> saveTask(WorkTask task) async {
    final database = await _database.database;
    await _upsert(database, 'tasks', task.toDb());
  }

  @override
  Future<void> saveNote(Note note) async {
    final database = await _database.database;
    await _upsert(database, 'notes', note.toDb());
  }

  @override
  Future<void> saveTimeEntry(TimeEntry entry) async {
    final database = await _database.database;
    await _upsert(database, 'time_entries', entry.toDb());
  }

  @override
  Future<void> softDeleteNote(String noteId, DateTime deletedAt) async {
    final database = await _database.database;
    await database.update(
      'notes',
      {
        'deleted_at': deletedAt.toIso8601String(),
        'updated_at': deletedAt.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [noteId],
    );
  }

  @override
  Future<void> restoreNote(String noteId) async {
    final database = await _database.database;
    await database.update(
      'notes',
      {
        'deleted_at': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [noteId],
    );
  }

  @override
  Future<void> saveActiveTimer(ActiveTimerState? timer) async {
    final database = await _database.database;
    if (timer == null) {
      await database.delete(
        'app_state',
        where: 'key = ?',
        whereArgs: [_activeTimerKey],
      );
      return;
    }
    await _putState(database, _activeTimerKey, jsonEncode(timer.toJson()));
  }

  @override
  Future<ActiveTimerState?> loadActiveTimer() async {
    final database = await _database.database;
    final rows = await database.query(
      'app_state',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_activeTimerKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final value = rows.first['value'] as String;
    try {
      final decoded = jsonDecode(value) as Map<String, dynamic>;
      return ActiveTimerState.fromJson(decoded);
    } on Object {
      await database.delete(
        'app_state',
        where: 'key = ?',
        whereArgs: [_activeTimerKey],
      );
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

  Future<void> _upsert(
    DatabaseExecutor executor,
    String table,
    Map<String, Object?> values,
  ) async {
    final id = values['id'];
    final updated = await executor.update(
      table,
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated == 0) {
      await executor.insert(table, values);
    }
  }

  Future<void> _putState(
    DatabaseExecutor executor,
    String key,
    String value,
  ) async {
    final updated = await executor.update(
      'app_state',
      {'value': value},
      where: 'key = ?',
      whereArgs: [key],
    );
    if (updated == 0) {
      await executor.insert('app_state', {'key': key, 'value': value});
    }
  }
}
