import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/services/app_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('data saved by one store is loaded by the next store', () async {
    final repository = InMemoryAppRepository();
    final firstStore = AppStore(repository: repository);
    await firstStore.load();

    firstStore.addProject(
      Project(id: 'persistent-project', title: 'Постоянный', emoji: '📁'),
    );
    await Future<void>.delayed(Duration.zero);

    final secondStore = AppStore(repository: repository);
    await secondStore.load();

    expect(
      secondStore.data.projects.any(
        (project) => project.id == 'persistent-project',
      ),
      isTrue,
    );
  });

  test('citation library is persisted by the repository', () async {
    final repository = InMemoryAppRepository();
    final firstStore = AppStore(repository: repository);
    await firstStore.load();

    firstStore.addCitationSource(
      CitationSource(
        id: 'source-1',
        citationKey: 'Jaffe2005',
        title: 'Multistate proteins',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final secondStore = AppStore(repository: repository);
    await secondStore.load();

    expect(secondStore.data.citationSources.single.citationKey, 'Jaffe2005');
  });

  test('custom note templates can be created, updated and deleted in memory', () async {
    final repository = InMemoryAppRepository();
    final store = AppStore(repository: repository);
    await store.load();

    final created = await store.createCustomNoteTemplate(
      title: 'Мой протокол',
      icon: '🧪',
      noteType: 'experiment',
      content: '# Мой протокол\n\n## Ход работы',
      defaultTags: const <String>['лаборатория', 'лаборатория'],
    );

    expect(created.isCustom, isTrue);
    expect(store.customNoteTemplates, hasLength(1));
    expect(created.defaultTags, <String>['лаборатория']);
    expect(store.availableNoteTemplates, contains(created));

    final updated = await store.updateCustomNoteTemplate(
      id: created.id,
      title: 'Обновлённый протокол',
      icon: '⚗️',
      noteType: 'experiment',
      content: '# Обновлённый протокол',
    );

    expect(store.customNoteTemplates.single.title, updated.title);
    await store.deleteCustomNoteTemplate(created.id);
    expect(store.customNoteTemplates, isEmpty);
  });


  test('ordinary note updates do not refresh Vault attachment images', () async {
    final repository = InMemoryAppRepository();
    final store = AppStore(repository: repository);
    addTearDown(store.dispose);
    await store.load();

    var attachmentRefreshCount = 0;
    store.attachmentRefreshListenable.addListener(() {
      attachmentRefreshCount += 1;
    });

    if (store.data.projects.isEmpty) {
      store.addProject(
        Project(id: 'project-1', title: 'Project', emoji: '📁'),
      );
    }
    final note = Note(
      id: 'resize-note',
      title: 'Image resize',
      projectId: store.data.projects.first.id,
      body: '![image](../Attachments/image.png)',
    );
    store.addNote(note);
    note.body =
        '![image](../Attachments/image.png "chronicle-image width=50 align=center")';
    store.updateNote(note);

    expect(attachmentRefreshCount, 0);
  });
}
