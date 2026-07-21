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
}
