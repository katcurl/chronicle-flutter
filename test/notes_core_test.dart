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
}
