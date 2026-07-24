import 'dart:io';

import 'package:chronicle/data/database/chronicle_database.dart';
import 'package:chronicle/data/repositories/drift_app_repository.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'chronicle-migration-test-',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('migrates the checked-in v1 schema to the current schema', () async {
    final databaseFile = File('${temporaryDirectory.path}/chronicle.sqlite');
    final legacy = sqlite.sqlite3.open(databaseFile.path);
    try {
      legacy.execute(File('sql/schema_v1.sql').readAsStringSync());
      legacy.execute('PRAGMA user_version = 1');
      _insertV1Project(legacy, id: 'active', title: 'Active', emoji: 'A');
      _insertV1Project(
        legacy,
        id: 'archived',
        title: 'Archived',
        emoji: 'R',
        archived: true,
      );
      legacy.execute(
        'INSERT INTO notes '
        '(id, project_id, title, body, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>[
          'note',
          'active',
          'Legacy note',
          'Preserved',
          _v1Timestamp,
          _v1Timestamp,
        ],
      );
      legacy.execute(
        'INSERT INTO tasks '
        '(id, project_id, note_id, title, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>[
          'task',
          'active',
          'note',
          'Legacy task',
          _v1Timestamp,
          _v1Timestamp,
        ],
      );
      legacy.execute('PRAGMA ignore_check_constraints = ON');
      legacy.execute(
        'INSERT INTO time_entries '
        '(id, project_id, task_id, note_id, description, started_at, '
        'duration_seconds, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          'entry',
          'active',
          'task',
          'note',
          'Legacy timer',
          _v1Timestamp,
          -7,
          _v1Timestamp,
        ],
      );
      legacy.execute('PRAGMA ignore_check_constraints = OFF');
    } finally {
      legacy.close();
    }

    final database = ChronicleDatabase(NativeDatabase(databaseFile));
    final repository = DriftAppRepository(database: database);
    final migrated = await repository.load();

    expect(migrated.projects, hasLength(2));
    expect(
      migrated.projects
          .singleWhere((project) => project.id == 'archived')
          .archived,
      isTrue,
    );
    expect(migrated.notes.single.body, 'Preserved');
    expect(migrated.notes.single.revision, 1);
    expect(migrated.tasks.single.description, isEmpty);
    expect(migrated.tasks.single.parentTaskId, isNull);
    expect(migrated.entries.single.durationSeconds, 0);

    migrated.tasks.add(
      WorkTask(
        id: 'child',
        title: 'Current hierarchy',
        projectId: 'active',
        parentTaskId: 'task',
      ),
    );
    await repository.replaceAll(migrated);
    final current = await repository.load();
    expect(
      current.tasks.singleWhere((task) => task.id == 'child').parentTaskId,
      'task',
    );
    await repository.close();

    final inspected = sqlite.sqlite3.open(
      databaseFile.path,
      mode: sqlite.OpenMode.readOnly,
    );
    try {
      expect(
        inspected.select('PRAGMA user_version').first.columnAt(0),
        chronicleDatabaseSchemaVersion,
      );
      expect(
        inspected.select('PRAGMA integrity_check').single.columnAt(0),
        'ok',
      );
    } finally {
      inspected.close();
    }
  });

  test('rejects a newer database without modifying it', () async {
    final databaseFile = File('${temporaryDirectory.path}/future.sqlite');
    final future = sqlite.sqlite3.open(databaseFile.path);
    try {
      future.execute(File('sql/schema_v1.sql').readAsStringSync());
      future.execute('PRAGMA user_version = 6');
      _insertV1Project(
        future,
        id: 'sentinel',
        title: 'Do not mutate',
        emoji: 'S',
      );
    } finally {
      future.close();
    }

    final database = ChronicleDatabase(NativeDatabase(databaseFile));
    final repository = DriftAppRepository(database: database);
    await expectLater(repository.load(), throwsStateError);
    await repository.close();

    final inspected = sqlite.sqlite3.open(
      databaseFile.path,
      mode: sqlite.OpenMode.readOnly,
    );
    try {
      expect(inspected.select('PRAGMA user_version').first.columnAt(0), 6);
      expect(
        inspected
            .select("SELECT title FROM projects WHERE id = 'sentinel'")
            .single
            .columnAt(0),
        'Do not mutate',
      );
    } finally {
      inspected.close();
    }
  });

  test('legacy snapshot includes committed WAL content', () async {
    final source = File('${temporaryDirectory.path}/legacy.sqlite');
    final target = File('${temporaryDirectory.path}/published.sqlite');
    final writer = sqlite.sqlite3.open(source.path);
    try {
      writer.execute('PRAGMA journal_mode = WAL');
      writer.execute('PRAGMA wal_autocheckpoint = 0');
      writer.execute(File('sql/schema_v1.sql').readAsStringSync());
      writer.execute('PRAGMA user_version = 1');
      _insertV1Project(
        writer,
        id: 'wal-row',
        title: 'Committed in WAL',
        emoji: 'W',
      );
      expect(File('${source.path}-wal').existsSync(), isTrue);

      await copyValidatedSqliteSnapshot(source: source, target: target);
    } finally {
      writer.close();
    }

    final copied = sqlite.sqlite3.open(
      target.path,
      mode: sqlite.OpenMode.readOnly,
    );
    try {
      expect(
        copied
            .select("SELECT title FROM projects WHERE id = 'wal-row'")
            .single
            .columnAt(0),
        'Committed in WAL',
      );
      expect(copied.select('PRAGMA quick_check').single.columnAt(0), 'ok');
    } finally {
      copied.close();
    }
  });

  test('corrupt legacy database is never published', () async {
    final source = File('${temporaryDirectory.path}/corrupt.sqlite');
    final target = File('${temporaryDirectory.path}/published.sqlite');
    await source.writeAsBytes(<int>[1, 2, 3, 4, 5], flush: true);

    await expectLater(
      copyValidatedSqliteSnapshot(source: source, target: target),
      throwsA(anything),
    );

    expect(await target.exists(), isFalse);
    expect(await File('${target.path}.migrating').exists(), isFalse);
  });

  test('interruption before publish leaves no partial target', () async {
    final source = File('${temporaryDirectory.path}/legacy.sqlite');
    final target = File('${temporaryDirectory.path}/published.sqlite');
    final legacy = sqlite.sqlite3.open(source.path);
    try {
      legacy.execute(File('sql/schema_v1.sql').readAsStringSync());
      legacy.execute('PRAGMA user_version = 1');
    } finally {
      legacy.close();
    }

    await expectLater(
      copyValidatedSqliteSnapshot(
        source: source,
        target: target,
        beforePublish: () async => throw StateError('simulated interruption'),
      ),
      throwsStateError,
    );

    expect(await target.exists(), isFalse);
    expect(await File('${target.path}.migrating').exists(), isFalse);
  });
}

const String _v1Timestamp = '2026-01-01T00:00:00.000Z';

void _insertV1Project(
  sqlite.Database database, {
  required String id,
  required String title,
  required String emoji,
  bool archived = false,
}) {
  database.execute(
    'INSERT INTO projects '
    '(id, title, emoji, description, archived, created_at, updated_at) '
    'VALUES (?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      id,
      title,
      emoji,
      '',
      archived ? 1 : 0,
      _v1Timestamp,
      _v1Timestamp,
    ],
  );
}
