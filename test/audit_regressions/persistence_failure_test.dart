import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/features/appearance/app_appearance.dart';
import 'package:chronicle/features/projects/project_appearance_store.dart';
import 'package:chronicle/main.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/screens/notes_screen.dart';
import 'package:chronicle/services/app_store.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_vault_backend.dart';

void main() {
  test(
    'updateNote returns a Future that completes after persistence',
    () async {
      final repository = InMemoryAppRepository(initialData: _initialData());
      await repository.markInitialized();
      final store = _store(repository);
      addTearDown(store.dispose);
      await store.load();

      final updated = Note.fromJson({
        ...store.data.notes.single.toJson(),
        'body': 'after',
      });
      final result = Function.apply(store.updateNote, [updated]);

      expect(result, isA<Future<void>>());
      await (result as Future<void>);
      expect(store.data.notes.single.body, 'after');
    },
  );

  test('failed note save leaves committed in-memory data unchanged', () async {
    final repository = _FailingNoteRepository(initialData: _initialData());
    await repository.markInitialized();
    final store = _store(repository);
    addTearDown(store.dispose);
    await store.load();
    final errors = <Object>[];

    await runZonedGuarded(() async {
      final updated = Note.fromJson({
        ...store.data.notes.single.toJson(),
        'body': 'after',
      });
      store.updateNote(updated);
      await Future<void>.delayed(Duration.zero);
    }, (error, _) => errors.add(error));

    expect(errors, hasLength(1));
    expect(errors.single, isA<FileSystemException>());
    expect(store.data.notes.single.body, 'before');
  });

  test('addNote becomes visible only after persistence completes', () async {
    final repository = _BlockingNoteRepository(initialData: _initialData());
    await repository.markInitialized();
    final store = _store(repository);
    addTearDown(() {
      if (!repository.saveCompleter.isCompleted) {
        repository.saveCompleter.complete();
      }
      store.dispose();
    });
    await store.load();
    final added = Note(
      id: 'new-note',
      title: 'New',
      projectId: 'p',
      body: 'pending',
    );

    final result = Function.apply(store.addNote, [added]);

    expect(result, isA<Future<void>>());
    expect(store.noteById(added.id), isNull);
    repository.saveCompleter.complete();
    await (result as Future<void>);
    expect(store.noteById(added.id)?.body, 'pending');
  });

  test(
    'note version becomes visible only after persistence completes',
    () async {
      final repository = _BlockingVersionRepository(
        initialData: _initialData(),
      );
      await repository.markInitialized();
      final store = _store(repository);
      addTearDown(() {
        if (!repository.saveCompleter.isCompleted) {
          repository.saveCompleter.complete();
        }
        store.dispose();
      });
      await store.load();
      final version = NoteVersion(
        id: 'version',
        noteId: 'n',
        title: 'Note',
        body: 'before',
      );

      final result = Function.apply(store.addNoteVersion, [version]);

      expect(result, isA<Future<void>>());
      expect(store.data.noteVersions, isEmpty);
      repository.saveCompleter.complete();
      await (result as Future<void>);
      expect(store.data.noteVersions.single.id, version.id);
    },
  );

  test('addTask becomes visible only after persistence completes', () async {
    final repository = _BlockingTaskRepository(initialData: _initialData());
    await repository.markInitialized();
    final store = _store(repository);
    addTearDown(() {
      if (!repository.saveCompleter.isCompleted) {
        repository.saveCompleter.complete();
      }
      store.dispose();
    });
    await store.load();
    final task = WorkTask(id: 'task', title: 'Persist me', projectId: 'p');

    final result = Function.apply(store.addTask, [task]);

    expect(result, isA<Future<void>>());
    expect(store.data.tasks, isEmpty);
    repository.saveCompleter.complete();
    await (result as Future<void>);
    expect(store.data.tasks.single.id, task.id);
  });

  test('updateTask commits in-memory state only after persistence', () async {
    final initialData = _initialData();
    initialData.tasks.add(
      WorkTask(id: 'task', title: 'before', projectId: 'p'),
    );
    final repository = _BlockingTaskRepository(initialData: initialData);
    await repository.markInitialized();
    final store = _store(repository);
    addTearDown(() {
      if (!repository.saveCompleter.isCompleted) {
        repository.saveCompleter.complete();
      }
      store.dispose();
    });
    await store.load();
    final updated = WorkTask.fromJson({
      ...store.data.tasks.single.toJson(),
      'title': 'after',
    });

    final result = Function.apply(store.updateTask, [updated]);

    expect(result, isA<Future<void>>());
    expect(store.data.tasks.single.title, 'before');
    repository.saveCompleter.complete();
    await (result as Future<void>);
    expect(store.data.tasks.single.title, 'after');
  });

  test('task status changes only after persistence completes', () async {
    final initialData = _initialData();
    initialData.tasks.add(
      WorkTask(id: 'task', title: 'before', projectId: 'p', status: 'next'),
    );
    final repository = _BlockingTaskRepository(initialData: initialData);
    await repository.markInitialized();
    final store = _store(repository);
    addTearDown(() {
      if (!repository.saveCompleter.isCompleted) {
        repository.saveCompleter.complete();
      }
      store.dispose();
    });
    await store.load();

    final result = Function.apply(store.updateTaskStatus, [
      store.data.tasks.single,
      'done',
    ]);

    expect(result, isA<Future<void>>());
    expect(store.data.tasks.single.status, 'next');
    repository.saveCompleter.complete();
    await (result as Future<void>);
    expect(store.data.tasks.single.status, 'done');
    expect(store.data.tasks.single.completedAt, isNotNull);
  });

  test('addProject becomes visible only after persistence completes', () async {
    final initialData = _initialData()..projects.clear();
    final repository = _BlockingProjectRepository(initialData: initialData);
    await repository.markInitialized();
    final store = _store(repository);
    addTearDown(() {
      if (!repository.saveCompleter.isCompleted) {
        repository.saveCompleter.complete();
      }
      store.dispose();
    });
    await store.load();
    final project = Project(id: 'p', title: 'Persist me', emoji: '📌');

    final result = Function.apply(store.addProject, [project]);

    expect(result, isA<Future<void>>());
    expect(store.data.projects, isEmpty);
    repository.saveCompleter.complete();
    await (result as Future<void>);
    expect(store.data.projects.single.title, 'Persist me');
  });

  test(
    'updateProject commits in-memory state only after persistence',
    () async {
      final repository = _BlockingProjectRepository(
        initialData: _initialData(),
      );
      await repository.markInitialized();
      final store = _store(repository);
      addTearDown(() {
        if (!repository.saveCompleter.isCompleted) {
          repository.saveCompleter.complete();
        }
        store.dispose();
      });
      await store.load();
      final updated = Project.fromJson({
        ...store.data.projects.single.toJson(),
        'title': 'after',
      });

      final result = Function.apply(store.updateProject, [updated]);

      expect(result, isA<Future<void>>());
      expect(store.data.projects.single.title, 'Project');
      repository.saveCompleter.complete();
      await (result as Future<void>);
      expect(store.data.projects.single.title, 'after');
    },
  );

  testWidgets('editor stays dirty until note persistence completes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = _BlockingNoteRepository(initialData: _initialData());
    await repository.markInitialized();
    final store = _store(repository);
    final appearanceController = ProjectAppearanceController();
    addTearDown(() {
      if (!repository.saveCompleter.isCompleted) {
        repository.saveCompleter.complete();
      }
    });
    await store.load();

    await tester.pumpWidget(
      MaterialApp(
        home: NoteWorkspaceScreen(
          store: store,
          note: store.data.notes.single,
          appearanceController: appearanceController,
          globalAppearance: AppAppearancePreferences.defaults(),
        ),
      ),
    );
    await tester.pump();

    final bodyField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller?.text == 'before',
    );
    expect(bodyField, findsOneWidget);
    await tester.enterText(bodyField, 'after');
    await tester.pump();
    await tester.tap(find.byTooltip('Сохранить версию'));
    await tester.pump();

    expect(find.text('Note •'), findsOneWidget);

    repository.saveCompleter.complete();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Note •'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    appearanceController.dispose();
    store.dispose();
  });

  testWidgets('app exit waits for queued persistence', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final initialData = _initialData()..projects.clear();
    final repository = _BlockingProjectRepository(initialData: initialData);
    await repository.markInitialized();
    final store = _store(repository);
    addTearDown(() {
      if (!repository.saveCompleter.isCompleted) {
        repository.saveCompleter.complete();
      }
    });

    await tester.pumpWidget(ChronicleApp(store: store));
    for (var attempt = 0; attempt < 100 && !store.ready; attempt++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(store.ready, isTrue);

    final write = store.addProject(
      Project(id: 'exit-project', title: 'Exit', emoji: '📌'),
    );
    var exitCompleted = false;
    final exit = tester.binding.handleRequestAppExit().then((response) {
      exitCompleted = true;
      return response;
    });
    await tester.pump();

    expect(exitCompleted, isFalse);
    repository.saveCompleter.complete();
    await write;
    expect(await exit, AppExitResponse.exit);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

AppStore _store(InMemoryAppRepository repository) => AppStore(
  repository: repository,
  vaultService: VaultService(backend: TestVaultBackend()),
);

AppData _initialData() => AppData(
  projects: [Project(id: 'p', title: 'Project', emoji: '📌')],
  tasks: <WorkTask>[],
  notes: [Note(id: 'n', title: 'Note', projectId: 'p', body: 'before')],
  entries: <TimeEntry>[],
);

final class _FailingNoteRepository extends InMemoryAppRepository {
  _FailingNoteRepository({required super.initialData});

  @override
  Future<void> saveNote(Note note) {
    return Future<void>.error(const FileSystemException('disk full'));
  }
}

final class _BlockingNoteRepository extends InMemoryAppRepository {
  _BlockingNoteRepository({required super.initialData});

  final Completer<void> saveCompleter = Completer<void>();

  @override
  Future<void> saveNote(Note note) async {
    await saveCompleter.future;
    await super.saveNote(note);
  }
}

final class _BlockingVersionRepository extends InMemoryAppRepository {
  _BlockingVersionRepository({required super.initialData});

  final Completer<void> saveCompleter = Completer<void>();

  @override
  Future<void> saveNoteVersion(NoteVersion version) async {
    await saveCompleter.future;
    await super.saveNoteVersion(version);
  }
}

final class _BlockingTaskRepository extends InMemoryAppRepository {
  _BlockingTaskRepository({required super.initialData});

  final Completer<void> saveCompleter = Completer<void>();

  @override
  Future<void> saveTask(WorkTask task) async {
    await saveCompleter.future;
    await super.saveTask(task);
  }
}

final class _BlockingProjectRepository extends InMemoryAppRepository {
  _BlockingProjectRepository({required super.initialData});

  final Completer<void> saveCompleter = Completer<void>();

  @override
  Future<void> saveProject(Project project) async {
    await saveCompleter.future;
    await super.saveProject(project);
  }
}
