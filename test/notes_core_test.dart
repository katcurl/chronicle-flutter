import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/services/app_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('note metadata, links and versions survive repository reload', () async {
    final project = Project(id: 'project-1', title: 'Research', emoji: '🧬');
    final target = Note(
      id: 'note-target',
      title: 'TM-score',
      projectId: project.id,
      body: '# TM-score',
    );
    final source = Note(
      id: 'note-source',
      title: 'Journal',
      projectId: project.id,
      body: 'See [[TM-score]].',
      noteType: 'research',
      folderPath: 'Orf9b/Analysis',
      pinned: true,
      properties: const {'method': 'MD'},
    );
    final repository = InMemoryAppRepository(
      initialData: AppData(
        projects: [project],
        tasks: [],
        notes: [target, source],
        entries: [],
      ),
    );
    await repository.markInitialized();
    final store = AppStore(repository: repository);
    await store.load();

    store.updateNote(source);
    await store.rebuildAllNoteLinks();
    store.addNoteVersion(
      NoteVersion(
        id: 'version-1',
        noteId: source.id,
        title: source.title,
        body: source.body,
        folderPath: source.folderPath,
        noteType: source.noteType,
        properties: source.properties,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final restored = await repository.load();
    final restoredSource = restored.notes.singleWhere(
      (note) => note.id == source.id,
    );
    expect(restoredSource.folderPath, 'Orf9b/Analysis');
    expect(restoredSource.pinned, isTrue);
    expect(restored.noteLinks.single.targetNoteId, target.id);
    expect(restored.noteVersions.single.noteId, source.id);

    store.dispose();
  });

  // Duplicate titles must never be resolved to an arbitrary project.
  test('wiki targets prefer the source project and support qualification', () async {
    final projectA = Project(id: 'project-a', title: 'Research A', emoji: '🧪');
    final projectB = Project(id: 'project-b', title: 'Research B', emoji: '🧬');
    final targetA = Note(
      id: 'target-a',
      title: 'RMSD',
      projectId: projectA.id,
      body: '# RMSD A',
    );
    final targetB = Note(
      id: 'target-b',
      title: 'RMSD',
      projectId: projectB.id,
      body: '# RMSD B',
    );
    final source = Note(
      id: 'source',
      title: 'Journal',
      projectId: projectA.id,
      body: 'См. [[RMSD]] и [[Research B :: RMSD]].',
    );
    final repository = InMemoryAppRepository(
      initialData: AppData(
        projects: [projectA, projectB],
        tasks: [],
        notes: [targetA, targetB, source],
        entries: [],
      ),
    );
    await repository.markInitialized();
    final store = AppStore(repository: repository);
    await store.load();
    await store.rebuildAllNoteLinks();

    expect(store.resolveWikiTarget('RMSD', source: source)?.id, targetA.id);
    expect(
      store.resolveWikiTarget('Research B :: RMSD', source: source)?.id,
      targetB.id,
    );
    expect(store.wikiTargetFor(targetB), 'Research B :: RMSD');
    expect(store.backlinksFor(targetA), hasLength(1));
    expect(store.backlinksFor(targetB), hasLength(1));

    store.dispose();
  });
}
