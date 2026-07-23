import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/services/app_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deleting and undoing a note restores task and wiki relationships', () async {
    final project = Project(id: 'project-1', title: 'Research', emoji: '🧬');
    final note = Note(
      id: 'note-1',
      title: 'Result',
      projectId: project.id,
      body: '# Result',
    );
    final other = Note(
      id: 'note-2',
      title: 'Discussion',
      projectId: project.id,
      body: 'See [[id:note-1|Result]].',
    );
    final task = WorkTask(
      id: 'task-1',
      title: 'Check result',
      projectId: project.id,
      noteId: note.id,
    );
    final repository = InMemoryAppRepository();
    await repository.replaceAll(
      AppData(
        projects: <Project>[project],
        tasks: <WorkTask>[task],
        notes: <Note>[note, other],
        entries: <TimeEntry>[],
      ),
    );
    await repository.markInitialized();
    final store = AppStore(repository: repository);
    await store.load();

    await store.deleteNote(note.id);

    expect(store.noteById(note.id), isNull);
    expect(store.data.tasks.single.noteId, isNull);
    expect(store.canUndo, isTrue);

    final label = await store.undoLastAction();

    expect(label, contains('Result'));
    expect(store.noteById(note.id), isNotNull);
    expect(store.data.tasks.single.noteId, note.id);
    expect(
      store.data.noteLinks.any(
        (link) =>
            link.sourceNoteId == other.id && link.targetNoteId == note.id,
      ),
      isTrue,
    );
    expect((await repository.load()).notes.map((item) => item.id), contains(note.id));
    store.dispose();
  });

  test('task deletion undo restores child hierarchy', () async {
    final project = Project(id: 'project-1', title: 'Research', emoji: '🧬');
    final parent = WorkTask(
      id: 'task-parent',
      title: 'Parent',
      projectId: project.id,
    );
    final child = WorkTask(
      id: 'task-child',
      title: 'Child',
      projectId: project.id,
      parentTaskId: parent.id,
    );
    final repository = InMemoryAppRepository();
    await repository.replaceAll(
      AppData(
        projects: <Project>[project],
        tasks: <WorkTask>[parent, child],
        notes: <Note>[],
        entries: <TimeEntry>[],
      ),
    );
    await repository.markInitialized();
    final store = AppStore(repository: repository);
    await store.load();

    await store.deleteTask(parent.id);
    expect(store.data.tasks.single.parentTaskId, isNull);

    await store.undoLastAction();

    expect(store.data.tasks.map((item) => item.id), contains(parent.id));
    expect(
      store.data.tasks.singleWhere((item) => item.id == child.id).parentTaskId,
      parent.id,
    );
    store.dispose();
  });

  test('project archive and source deletion are undoable', () async {
    final project = Project(id: 'project-1', title: 'Research', emoji: '🧬');
    final source = CitationSource(
      id: 'source-1',
      citationKey: 'Smith2026',
      title: 'Stable systems',
    );
    final repository = InMemoryAppRepository();
    await repository.replaceAll(
      AppData(
        projects: <Project>[project],
        tasks: <WorkTask>[],
        notes: <Note>[],
        entries: <TimeEntry>[],
        citationSources: <CitationSource>[source],
      ),
    );
    await repository.markInitialized();
    final store = AppStore(repository: repository);
    await store.load();

    await store.setProjectArchived(store.projectById(project.id)!, true);
    expect(store.projectById(project.id)!.archived, isTrue);
    await store.undoLastAction();
    expect(store.projectById(project.id)!.archived, isFalse);

    await store.deleteCitationSource(source.id);
    expect(store.data.citationSources, isEmpty);
    await store.undoLastAction();
    expect(store.data.citationSources.single.id, source.id);
    store.dispose();
  });
}
