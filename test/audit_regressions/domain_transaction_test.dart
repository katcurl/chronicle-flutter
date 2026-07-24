import 'dart:convert';
import 'dart:io';

import 'package:chronicle/data/database/chronicle_database.dart';
import 'package:chronicle/data/repositories/drift_app_repository.dart';
import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/services/app_store.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_vault_backend.dart';

void main() {
  test(
    'failed task graph deletion changes neither store nor repository',
    () async {
      final repository = _FailingGraphRepository(
        initialData: _graphData(),
        failTaskWrite: true,
      );
      await repository.markInitialized();
      final store = _store(repository);
      addTearDown(store.dispose);
      await store.load();
      final before = _stableBackup(await repository.load());

      await expectLater(
        store.deleteTask('parent'),
        throwsA(isA<FileSystemException>()),
      );

      expect(store.data.tasks, hasLength(3));
      expect(
        store.data.tasks.singleWhere((task) => task.id == 'child').parentTaskId,
        'parent',
      );
      expect(_stableBackup(await repository.load()), before);
      expect(store.undoDepth, 0);
    },
  );

  test(
    'failed note graph deletion changes neither store nor repository',
    () async {
      final repository = _FailingGraphRepository(
        initialData: _graphData(),
        failNoteWrite: true,
      );
      await repository.markInitialized();
      final store = _store(repository);
      addTearDown(store.dispose);
      await store.load();
      final before = _stableBackup(await repository.load());

      await expectLater(
        store.deleteNote('note'),
        throwsA(isA<FileSystemException>()),
      );

      expect(store.noteById('note'), isNotNull);
      expect(
        store.data.tasks.singleWhere((task) => task.id == 'linked').noteId,
        'note',
      );
      expect(store.data.noteLinks, hasLength(2));
      expect(_stableBackup(await repository.load()), before);
      expect(store.undoDepth, 0);
    },
  );

  test('successful graph deletions detach dependent entities', () async {
    final repository = InMemoryAppRepository(initialData: _graphData());
    await repository.markInitialized();
    final store = _store(repository);
    addTearDown(store.dispose);
    await store.load();

    await store.deleteTask('parent');
    await store.deleteNote('note');

    expect(store.data.tasks.any((task) => task.id == 'parent'), isFalse);
    expect(
      store.data.tasks.singleWhere((task) => task.id == 'child').parentTaskId,
      isNull,
    );
    expect(
      store.data.tasks.singleWhere((task) => task.id == 'linked').noteId,
      isNull,
    );
    expect(store.noteById('note'), isNull);
    expect(
      store.data.noteLinks.where(
        (link) => link.sourceNoteId == 'note' || link.targetNoteId == 'note',
      ),
      isEmpty,
    );

    final reloaded = await repository.load();
    expect(reloaded.tasks.any((task) => task.id == 'parent'), isFalse);
    expect(
      reloaded.tasks.singleWhere((task) => task.id == 'child').parentTaskId,
      isNull,
    );
    expect(
      reloaded.tasks.singleWhere((task) => task.id == 'linked').noteId,
      isNull,
    );
    expect(reloaded.notes.any((note) => note.id == 'note'), isFalse);
    expect(
      reloaded.noteLinks.where(
        (link) => link.sourceNoteId == 'note' || link.targetNoteId == 'note',
      ),
      isEmpty,
    );
  });

  test('Drift rejects a negative entry and keeps the active timer', () async {
    final database = ChronicleDatabase(NativeDatabase.memory());
    final repository = DriftAppRepository(database: database);
    addTearDown(repository.close);
    final data = _graphData();
    await repository.replaceAll(data);
    final active = ActiveTimerState(
      startedAt: DateTime(2026, 7, 24, 12),
      description: 'Focus',
      projectId: 'p',
    );
    await repository.saveActiveTimer(active);
    final invalid = TimeEntry(
      id: 'negative',
      description: 'Invalid',
      projectId: 'p',
      startedAt: active.startedAt,
      durationSeconds: -1,
    );

    await expectLater(
      repository.appendTimeEntryAndClearTimer(invalid),
      throwsA(anything),
    );

    expect((await repository.load()).entries, isEmpty);
    expect((await repository.loadActiveTimer())?.projectId, 'p');
  });

  test('schema v5 migration normalizes negative timer durations', () async {
    final directory = await Directory.systemTemp.createTemp(
      'chronicle-timer-migration-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final file = File('${directory.path}/chronicle.sqlite');
    final firstDatabase = ChronicleDatabase(NativeDatabase(file));
    final firstRepository = DriftAppRepository(database: firstDatabase);
    await firstRepository.replaceAll(
      AppData(
        projects: [Project(id: 'p', title: 'Project', emoji: '📌')],
        tasks: const [],
        notes: const [],
        entries: const [],
      ),
    );
    await firstDatabase.customStatement('PRAGMA ignore_check_constraints = ON');
    await firstDatabase.customStatement(
      'INSERT INTO time_entries ('
      'id, project_id, task_id, note_id, description, started_at, '
      'duration_seconds, created_at'
      ') VALUES (?, ?, NULL, NULL, ?, ?, ?, ?)',
      [
        'legacy-negative',
        'p',
        'Legacy',
        DateTime(2026, 7, 24, 12).toIso8601String(),
        -10,
        DateTime(2026, 7, 24, 12).toIso8601String(),
      ],
    );
    await firstDatabase.customStatement('PRAGMA user_version = 4');
    await firstRepository.close();

    final migratedDatabase = ChronicleDatabase(NativeDatabase(file));
    final migratedRepository = DriftAppRepository(
      database: migratedDatabase,
    );
    addTearDown(migratedRepository.close);

    final restored = await migratedRepository.load();
    expect(restored.entries.single.durationSeconds, 0);
    final schema = await migratedDatabase.customSelect(
      "SELECT sql FROM sqlite_master WHERE name = 'time_entries'",
    ).getSingle();
    expect(
      schema.read<String>('sql'),
      contains('CHECK (duration_seconds >= 0)'),
    );
  });
}

AppStore _store(InMemoryAppRepository repository) => AppStore(
  repository: repository,
  vaultService: VaultService(backend: TestVaultBackend()),
);

Map<String, dynamic> _stableBackup(AppData data) {
  final decoded = jsonDecode(data.encode()) as Map<String, dynamic>;
  decoded.remove('exportedAt');
  return decoded;
}

AppData _graphData() => AppData(
  projects: [Project(id: 'p', title: 'Project', emoji: '📌')],
  tasks: [
    WorkTask(id: 'parent', title: 'Parent', projectId: 'p'),
    WorkTask(
      id: 'child',
      title: 'Child',
      projectId: 'p',
      parentTaskId: 'parent',
    ),
    WorkTask(id: 'linked', title: 'Linked', projectId: 'p', noteId: 'note'),
  ],
  notes: [
    Note(id: 'note', title: 'Note', projectId: 'p', body: '[[Source]]'),
    Note(id: 'source', title: 'Source', projectId: 'p', body: '[[Note]]'),
  ],
  entries: <TimeEntry>[],
  noteLinks: [
    NoteLink(
      id: 'outgoing',
      sourceNoteId: 'note',
      targetTitle: 'Source',
      targetNoteId: 'source',
    ),
    NoteLink(
      id: 'incoming',
      sourceNoteId: 'source',
      targetTitle: 'Note',
      targetNoteId: 'note',
    ),
  ],
);

final class _FailingGraphRepository extends InMemoryAppRepository {
  _FailingGraphRepository({
    required super.initialData,
    this.failTaskWrite = false,
    this.failNoteWrite = false,
  });

  final bool failTaskWrite;
  final bool failNoteWrite;

  @override
  Future<void> saveTask(WorkTask task) async {
    await super.saveTask(task);
    if (failTaskWrite && task.id == 'child' && task.parentTaskId == null) {
      throw const FileSystemException('task graph write failed');
    }
    if (failNoteWrite && task.id == 'linked' && task.noteId == null) {
      throw const FileSystemException('note graph write failed');
    }
  }
}
