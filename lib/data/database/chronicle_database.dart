import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' show getDatabasesPath;

part 'chronicle_database.g.dart';

class AppStateRecords extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  String get tableName => 'app_state';

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@TableIndex(name: 'idx_projects_archived', columns: {#archived, #updatedAt})
class ProjectRecords extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get emoji => text().withDefault(const Constant('📁'))();
  TextColumn get description => text().withDefault(const Constant(''))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  TextColumn get createdAt => text().named('created_at')();
  TextColumn get updatedAt => text().named('updated_at')();

  @override
  String get tableName => 'projects';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'idx_notes_project', columns: {#projectId, #updatedAt})
class NoteRecords extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text()
          .named('project_id')
          .references(ProjectRecords, #id, onDelete: KeyAction.restrict)();
  TextColumn get title => text()();
  TextColumn get body => text().withDefault(const Constant(''))();
  TextColumn get tagsJson =>
      text().named('tags_json').withDefault(const Constant('[]'))();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  TextColumn get createdAt => text().named('created_at')();
  TextColumn get updatedAt => text().named('updated_at')();
  TextColumn get deletedAt => text().named('deleted_at').nullable()();

  @override
  String get tableName => 'notes';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'idx_tasks_status_due', columns: {#status, #dueAt})
@TableIndex(name: 'idx_tasks_project', columns: {#projectId, #status})
class TaskRecords extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text()
          .named('project_id')
          .references(ProjectRecords, #id, onDelete: KeyAction.restrict)();
  TextColumn get noteId =>
      text()
          .named('note_id')
          .nullable()
          .references(NoteRecords, #id, onDelete: KeyAction.setNull)();
  TextColumn get title => text()();
  TextColumn get status => text().withDefault(const Constant('next'))();
  IntColumn get estimateMinutes =>
      integer().named('estimate_minutes').withDefault(const Constant(30))();
  TextColumn get dueAt => text().named('due_at').nullable()();
  TextColumn get createdAt => text().named('created_at')();
  TextColumn get updatedAt => text().named('updated_at')();
  TextColumn get completedAt => text().named('completed_at').nullable()();
  TextColumn get deletedAt => text().named('deleted_at').nullable()();

  @override
  String get tableName => 'tasks';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'idx_time_entries_started', columns: {#startedAt})
@TableIndex(name: 'idx_time_entries_project', columns: {#projectId, #startedAt})
class TimeEntryRecords extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text()
          .named('project_id')
          .references(ProjectRecords, #id, onDelete: KeyAction.restrict)();
  TextColumn get taskId =>
      text()
          .named('task_id')
          .nullable()
          .references(TaskRecords, #id, onDelete: KeyAction.setNull)();
  TextColumn get noteId =>
      text()
          .named('note_id')
          .nullable()
          .references(NoteRecords, #id, onDelete: KeyAction.setNull)();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get startedAt => text().named('started_at')();
  IntColumn get durationSeconds => integer().named('duration_seconds')();
  TextColumn get createdAt => text().named('created_at')();

  @override
  String get tableName => 'time_entries';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    AppStateRecords,
    ProjectRecords,
    NoteRecords,
    TaskRecords,
    TimeEntryRecords,
  ],
)
final class ChronicleDatabase extends _$ChronicleDatabase {
  ChronicleDatabase(super.executor);

  factory ChronicleDatabase.defaults() => ChronicleDatabase(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from > to) {
        throw StateError('Downgrading Chronicle databases is unsupported.');
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'chronicle',
    native: DriftNativeOptions(databasePath: _resolveDatabasePath),
  );
}

Future<String> _resolveDatabasePath() async {
  final supportDirectory = await getApplicationSupportDirectory();
  final databaseDirectory = Directory(
    path.join(supportDirectory.path, 'Chronicle'),
  );
  await databaseDirectory.create(recursive: true);

  final target = File(path.join(databaseDirectory.path, 'chronicle.sqlite'));
  if (!await target.exists() && (Platform.isAndroid || Platform.isIOS)) {
    await _copyLegacyMobileDatabase(target);
  }

  return target.path;
}

Future<void> _copyLegacyMobileDatabase(File target) async {
  final legacyDirectory = await getDatabasesPath();
  final legacy = File(path.join(legacyDirectory, 'chronicle.db'));
  if (!await legacy.exists()) return;

  final temporary = File('${target.path}.migrating');
  if (await temporary.exists()) {
    await temporary.delete();
  }

  await legacy.copy(temporary.path);
  await temporary.rename(target.path);

  for (final suffix in const ['-wal', '-shm', '-journal']) {
    final legacySidecar = File('${legacy.path}$suffix');
    if (await legacySidecar.exists()) {
      await legacySidecar.copy('${target.path}$suffix');
    }
  }
}
