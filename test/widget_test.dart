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
    await tester.pumpAndSettle();

    expect(find.text('Готова начать?'), findsOneWidget);
    expect(find.text('Следующие задачи'), findsOneWidget);
  });
}
