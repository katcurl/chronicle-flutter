import 'dart:io';

import 'package:chronicle/application/notes/note_commands.dart';
import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/data/repositories/mutation_queue.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('note commands publish an added note only after persistence', () async {
    final data = AppData.empty();
    final repository = _FailingNoteRepository();
    final commands = NoteCommands(
      repository: repository,
      mutationQueue: MutationQueue(),
      currentData: () => data,
      resolveWikiTarget: (_, {source}) => null,
      registerUndo: ({required label, required restore}) {},
      recordLinkIndexWarning: (_) async {},
      scheduleSync: () {},
      scheduleVaultMirror: () {},
      notifyListeners: () {},
    );
    final note = Note(
      id: 'note',
      projectId: 'project',
      title: 'Note',
      body: 'body',
    );

    await expectLater(commands.add(note), throwsA(isA<FileSystemException>()));

    expect(data.notes, isEmpty);
  });

  test('note commands persist a deterministic wiki-link index', () async {
    final target = Note(
      id: 'target',
      projectId: 'project',
      title: 'Target',
      body: '',
    );
    final source = Note(
      id: 'source',
      projectId: 'project',
      title: 'Source',
      body: '[[Target]]',
    );
    final data = AppData(
      projects: <Project>[],
      tasks: <WorkTask>[],
      notes: <Note>[target],
      entries: <TimeEntry>[],
    );
    final repository = InMemoryAppRepository(initialData: data);
    final commands = NoteCommands(
      repository: repository,
      mutationQueue: MutationQueue(),
      currentData: () => data,
      resolveWikiTarget:
          (rawTarget, {source}) => rawTarget == 'Target' ? target : null,
      registerUndo: ({required label, required restore}) {},
      recordLinkIndexWarning: (_) async {},
      scheduleSync: () {},
      scheduleVaultMirror: () {},
      notifyListeners: () {},
    );

    await commands.add(source);

    expect(data.noteLinks, hasLength(1));
    expect(data.noteLinks.single.sourceNoteId, source.id);
    expect(data.noteLinks.single.targetNoteId, target.id);
    expect((await repository.load()).noteLinks, hasLength(1));
  });
}

final class _FailingNoteRepository extends InMemoryAppRepository {
  @override
  Future<void> saveNote(Note note) {
    throw const FileSystemException('simulated persistence failure');
  }
}
