import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/services/app_store.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_vault_backend.dart';

void main() {
  test('a new Chronicle installation starts completely empty', () async {
    final store = AppStore(
      repository: InMemoryAppRepository(),
      vaultService: VaultService(backend: TestVaultBackend()),
    );

    await store.load();

    expect(store.loadError, isNull);
    expect(store.data.projects, isEmpty);
    expect(store.data.notes, isEmpty);
    expect(store.data.tasks, isEmpty);
    expect(store.data.entries, isEmpty);
    expect(store.customNoteTemplates, isEmpty);
    expect(store.availableNoteTemplates.map((item) => item.id), <String>[
      'blank',
    ]);
    expect(store.applicableNoteTemplates, isEmpty);
  });
}
