import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/main.dart';
import 'package:chronicle/services/app_store.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_vault_backend.dart';

void main() {
  testWidgets('Chronicle opens the Today screen', (tester) async {
    final store = AppStore(
      repository: InMemoryAppRepository(),
      vaultService: VaultService(backend: TestVaultBackend()),
    );

    await tester.pumpWidget(ChronicleApp(store: store));

    await _pumpUntilReady(tester, store);

    expect(find.text('Готова начать?'), findsOneWidget);
    expect(find.text('Следующие задачи'), findsOneWidget);
  });
}

Future<void> _pumpUntilReady(WidgetTester tester, AppStore store) async {
  for (var attempt = 0; attempt < 100 && !store.ready; attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
  }

  expect(store.ready, isTrue, reason: 'AppStore не завершил загрузку.');

  expect(
    store.loadError,
    isNull,
    reason: 'Ошибка загрузки AppStore: ${store.loadError}',
  );

  await tester.pump();
}
