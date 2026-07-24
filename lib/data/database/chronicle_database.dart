import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' show getDatabasesPath;
import 'package:sqlite3/sqlite3.dart' as sqlite;

part 'chronicle_database.g.dart';

const int chronicleDatabaseSchemaVersion = 5;

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
  IntColumn get colorValue =>
      integer().named('color_value').withDefault(const Constant(0xFF6750A4))();
  TextColumn get dueAt => text().named('due_at').nullable()();
  IntColumn get budgetMinutes => integer().named('budget_minutes').nullable()();
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
  TextColumn get folderPath =>
      text().named('folder_path').withDefault(const Constant(''))();
  TextColumn get noteType =>
      text().named('note_type').withDefault(const Constant('note'))();
  TextColumn get propertiesJson =>
      text().named('properties_json').withDefault(const Constant('{}'))();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  TextColumn get createdAt => text().named('created_at')();
  TextColumn get updatedAt => text().named('updated_at')();
  TextColumn get deletedAt => text().named('deleted_at').nullable()();

  @override
  String get tableName => 'notes';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(
  name: 'idx_note_links_target',
  columns: {#targetNoteId, #targetTitle},
)
@TableIndex(name: 'idx_note_links_source', columns: {#sourceNoteId})
class NoteLinkRecords extends Table {
  TextColumn get id => text()();
  @ReferenceName('sourceNoteLinks')
  TextColumn get sourceNoteId =>
      text()
          .named('source_note_id')
          .references(NoteRecords, #id, onDelete: KeyAction.cascade)();
  TextColumn get targetTitle => text().named('target_title')();
  @ReferenceName('targetNoteLinks')
  TextColumn get targetNoteId =>
      text()
          .named('target_note_id')
          .nullable()
          .references(NoteRecords, #id, onDelete: KeyAction.setNull)();
  TextColumn get createdAt => text().named('created_at')();

  @override
  String get tableName => 'note_links';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'idx_note_versions_note', columns: {#noteId, #createdAt})
class NoteVersionRecords extends Table {
  TextColumn get id => text()();
  TextColumn get noteId =>
      text()
          .named('note_id')
          .references(NoteRecords, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  TextColumn get body => text().withDefault(const Constant(''))();
  TextColumn get tagsJson =>
      text().named('tags_json').withDefault(const Constant('[]'))();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  TextColumn get folderPath =>
      text().named('folder_path').withDefault(const Constant(''))();
  TextColumn get noteType =>
      text().named('note_type').withDefault(const Constant('note'))();
  TextColumn get propertiesJson =>
      text().named('properties_json').withDefault(const Constant('{}'))();
  TextColumn get reason => text().withDefault(const Constant('manual'))();
  TextColumn get createdAt => text().named('created_at')();

  @override
  String get tableName => 'note_versions';

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
  TextColumn get parentTaskId => text().named('parent_task_id').nullable()();
  TextColumn get noteId =>
      text()
          .named('note_id')
          .nullable()
          .references(NoteRecords, #id, onDelete: KeyAction.setNull)();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get status => text().withDefault(const Constant('next'))();
  IntColumn get priority => integer().withDefault(const Constant(1))();
  IntColumn get estimateMinutes =>
      integer().named('estimate_minutes').withDefault(const Constant(30))();
  IntColumn get sortOrder =>
      integer().named('sort_order').withDefault(const Constant(0))();
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
  IntColumn get durationSeconds =>
      integer()
          .named('duration_seconds')
          .customConstraint('NOT NULL CHECK (duration_seconds >= 0)')();
  TextColumn get createdAt => text().named('created_at')();

  @override
  String get tableName => 'time_entries';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class DeviceIdentityRecords extends Table {
  TextColumn get deviceId => text().named('device_id')();
  TextColumn get displayName => text().named('display_name')();
  TextColumn get platform => text()();
  TextColumn get createdAt => text().named('created_at')();
  TextColumn get lastSeenAt => text().named('last_seen_at')();

  @override
  String get tableName => 'device_identity';

  @override
  Set<Column<Object>> get primaryKey => {deviceId};
}

@TableIndex(
  name: 'idx_trusted_devices_active',
  columns: {#revokedAt, #lastSyncAt},
)
class TrustedDeviceRecords extends Table {
  TextColumn get deviceId => text().named('device_id')();
  TextColumn get displayName => text().named('display_name')();
  TextColumn get platform => text()();
  TextColumn get publicKey => text().named('public_key')();
  TextColumn get pairedAt => text().named('paired_at')();
  TextColumn get lastSeenAt => text().named('last_seen_at').nullable()();
  TextColumn get lastSyncAt => text().named('last_sync_at').nullable()();
  TextColumn get revokedAt => text().named('revoked_at').nullable()();
  BoolColumn get autoSyncEnabled =>
      boolean().named('auto_sync_enabled').withDefault(const Constant(true))();

  @override
  String get tableName => 'trusted_devices';

  @override
  Set<Column<Object>> get primaryKey => {deviceId};
}

@TableIndex(
  name: 'idx_change_records_entity',
  columns: {#entityType, #entityId, #revision},
)
@TableIndex(
  name: 'idx_change_records_origin',
  columns: {#originDeviceId, #localSequence},
)
class ChangeRecordRecords extends Table {
  IntColumn get localSequence =>
      integer().named('local_sequence').autoIncrement()();
  TextColumn get changeId => text().named('change_id').unique()();
  TextColumn get entityType => text().named('entity_type')();
  TextColumn get entityId => text().named('entity_id')();
  TextColumn get operation => text()();
  IntColumn get revision => integer()();
  TextColumn get originDeviceId => text().named('origin_device_id')();
  TextColumn get changedAt => text().named('changed_at')();
  TextColumn get payloadJson => text().named('payload_json')();
  TextColumn get appliedAt => text().named('applied_at').nullable()();

  @override
  String get tableName => 'change_records';
}

class SyncCursorRecords extends Table {
  TextColumn get peerDeviceId => text().named('peer_device_id')();
  IntColumn get lastSentSequence =>
      integer().named('last_sent_sequence').withDefault(const Constant(0))();
  TextColumn get lastReceivedChangeId =>
      text().named('last_received_change_id').nullable()();
  TextColumn get lastSuccessAt => text().named('last_success_at').nullable()();

  @override
  String get tableName => 'sync_cursors';

  @override
  Set<Column<Object>> get primaryKey => {peerDeviceId};
}

@DriftDatabase(
  tables: [
    AppStateRecords,
    ProjectRecords,
    NoteRecords,
    NoteLinkRecords,
    NoteVersionRecords,
    TaskRecords,
    TimeEntryRecords,
    DeviceIdentityRecords,
    TrustedDeviceRecords,
    ChangeRecordRecords,
    SyncCursorRecords,
  ],
)
final class ChronicleDatabase extends _$ChronicleDatabase {
  ChronicleDatabase(super.executor);

  factory ChronicleDatabase.defaults() => ChronicleDatabase(_openConnection());

  @override
  int get schemaVersion => chronicleDatabaseSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from > to) {
        throw StateError('Downgrading Chronicle databases is unsupported.');
      }
      if (from < 2) {
        await migrator.addColumn(projectRecords, projectRecords.colorValue);
        await migrator.addColumn(projectRecords, projectRecords.dueAt);
        await migrator.addColumn(projectRecords, projectRecords.budgetMinutes);
        await migrator.addColumn(taskRecords, taskRecords.parentTaskId);
        await migrator.addColumn(taskRecords, taskRecords.description);
        await migrator.addColumn(taskRecords, taskRecords.priority);
        await migrator.addColumn(taskRecords, taskRecords.sortOrder);
      }
      if (from < 3) {
        await migrator.addColumn(noteRecords, noteRecords.folderPath);
        await migrator.addColumn(noteRecords, noteRecords.noteType);
        await migrator.addColumn(noteRecords, noteRecords.propertiesJson);
        await migrator.addColumn(noteRecords, noteRecords.pinned);
        await migrator.addColumn(noteRecords, noteRecords.revision);
        await migrator.createTable(noteLinkRecords);
        await migrator.createTable(noteVersionRecords);
      }
      if (from < 4) {
        await migrator.createTable(deviceIdentityRecords);
        await migrator.createTable(trustedDeviceRecords);
        await migrator.createTable(changeRecordRecords);
        await migrator.createTable(syncCursorRecords);
      }
      if (from < 5) {
        await customStatement(
          'UPDATE time_entries SET duration_seconds = 0 '
          'WHERE duration_seconds < 0',
        );
        await migrator.alterTable(TableMigration(timeEntryRecords));
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
  final target = File(await locateChronicleDatabasePath());
  final databaseDirectory = target.parent;
  await databaseDirectory.create(recursive: true);

  if (!await target.exists() && (Platform.isAndroid || Platform.isIOS)) {
    await _copyLegacyMobileDatabase(target);
  }

  return target.path;
}

/// Resolves the production database location without creating, migrating, or
/// opening any file. Recovery preflight uses this to remain strictly read-only.
Future<String> locateChronicleDatabasePath() async {
  final supportDirectory = await getApplicationSupportDirectory();
  return path.join(supportDirectory.path, 'Chronicle', 'chronicle.sqlite');
}

Future<void> _copyLegacyMobileDatabase(File target) async {
  final legacyDirectory = await getDatabasesPath();
  final legacy = File(path.join(legacyDirectory, 'chronicle.db'));
  if (!await legacy.exists()) return;

  await copyValidatedSqliteSnapshot(source: legacy, target: target);
}

/// Copies one consistent, committed SQLite snapshot and publishes it only
/// after validation. SQLite's backup API includes committed WAL pages, so the
/// published database never depends on source sidecar files.
Future<void> copyValidatedSqliteSnapshot({
  required File source,
  required File target,
  Future<void> Function()? beforePublish,
}) async {
  if (!await source.exists()) {
    throw StateError('The legacy Chronicle database does not exist.');
  }
  if (await target.exists()) {
    throw StateError('Refusing to overwrite an existing Chronicle database.');
  }

  await target.parent.create(recursive: true);
  final temporary = File('${target.path}.migrating');
  await _deleteSqliteFiles(temporary);

  sqlite.Database? sourceDatabase;
  sqlite.Database? temporaryDatabase;
  var published = false;
  try {
    sourceDatabase = sqlite.sqlite3.open(
      source.path,
      mode: sqlite.OpenMode.readOnly,
    );
    temporaryDatabase = sqlite.sqlite3.open(temporary.path);
    await sourceDatabase.backup(temporaryDatabase, nPage: 256).drain<void>();
    _validateSqliteSnapshot(temporaryDatabase);

    temporaryDatabase.close();
    temporaryDatabase = null;
    sourceDatabase.close();
    sourceDatabase = null;

    await beforePublish?.call();

    final finalValidation = sqlite.sqlite3.open(
      temporary.path,
      mode: sqlite.OpenMode.readOnly,
    );
    try {
      _validateSqliteSnapshot(finalValidation);
    } finally {
      finalValidation.close();
    }

    await temporary.rename(target.path);
    published = true;
  } finally {
    temporaryDatabase?.close();
    sourceDatabase?.close();
    if (!published) {
      await _deleteSqliteFiles(temporary);
    }
  }
}

void _validateSqliteSnapshot(sqlite.Database database) {
  final quickCheck = database.select('PRAGMA quick_check');
  final quickCheckResult =
      quickCheck.isEmpty ? null : quickCheck.first.columnAt(0)?.toString();
  if (quickCheck.length != 1 || quickCheckResult != 'ok') {
    throw StateError(
      'The legacy Chronicle database failed SQLite quick_check: '
      '${quickCheck.map((row) => row.columnAt(0)).join(', ')}',
    );
  }

  final versionRows = database.select('PRAGMA user_version');
  final version =
      versionRows.isEmpty ? null : versionRows.first.columnAt(0) as int?;
  if (version == null ||
      version < 1 ||
      version > chronicleDatabaseSchemaVersion) {
    throw StateError(
      'Unsupported legacy Chronicle database version: $version.',
    );
  }
}

Future<void> _deleteSqliteFiles(File database) async {
  for (final suffix in const ['', '-wal', '-shm', '-journal']) {
    final candidate = File('${database.path}$suffix');
    if (await candidate.exists()) {
      await candidate.delete();
    }
  }
}
