import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class ChronicleDatabase {
  ChronicleDatabase._();

  static final ChronicleDatabase instance = ChronicleDatabase._();
  static const databaseName = 'chronicle.db';
  static const databaseVersion = 1;

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;

    final databasesPath = await getDatabasesPath();
    final databasePath = path.join(databasesPath, databaseName);
    final opened = await openDatabase(
      databasePath,
      version: databaseVersion,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createVersion1,
      onUpgrade: _upgrade,
    );
    _database = opened;
    return opened;
  }

  Future<void> close() async {
    final database = _database;
    _database = null;
    if (database != null) {
      await database.close();
    }
  }

  Future<void> _upgrade(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 1) {
      await _createVersion1(database, newVersion);
    }
  }

  Future<void> _createVersion1(Database database, int version) async {
    final batch = database.batch();

    batch.execute('''
      CREATE TABLE app_state (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE projects (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        emoji TEXT NOT NULL DEFAULT '📁',
        description TEXT NOT NULL DEFAULT '',
        archived INTEGER NOT NULL DEFAULT 0 CHECK (archived IN (0, 1)),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE RESTRICT,
        title TEXT NOT NULL,
        body TEXT NOT NULL DEFAULT '',
        tags_json TEXT NOT NULL DEFAULT '[]',
        status TEXT NOT NULL DEFAULT 'draft',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE RESTRICT,
        note_id TEXT REFERENCES notes(id) ON DELETE SET NULL,
        title TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'next',
        estimate_minutes INTEGER NOT NULL DEFAULT 30,
        due_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        completed_at TEXT,
        deleted_at TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE time_entries (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE RESTRICT,
        task_id TEXT REFERENCES tasks(id) ON DELETE SET NULL,
        note_id TEXT REFERENCES notes(id) ON DELETE SET NULL,
        description TEXT NOT NULL DEFAULT '',
        started_at TEXT NOT NULL,
        duration_seconds INTEGER NOT NULL CHECK (duration_seconds >= 0),
        created_at TEXT NOT NULL
      )
    ''');

    batch.execute(
      'CREATE INDEX idx_projects_archived ON projects(archived, updated_at)',
    );
    batch.execute(
      'CREATE INDEX idx_tasks_status_due ON tasks(status, due_at)',
    );
    batch.execute(
      'CREATE INDEX idx_tasks_project ON tasks(project_id, status)',
    );
    batch.execute(
      'CREATE INDEX idx_notes_project ON notes(project_id, updated_at)',
    );
    batch.execute(
      'CREATE INDEX idx_time_entries_started ON time_entries(started_at)',
    );
    batch.execute(
      'CREATE INDEX idx_time_entries_project ON time_entries(project_id, started_at)',
    );

    await batch.commit(noResult: true);
  }
}
