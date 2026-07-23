import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/screens/devices_screen.dart';
import 'package:chronicle/screens/insights_screen.dart';
import 'package:chronicle/services/app_store.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_vault_backend.dart';

void main() {
  testWidgets('Insights exposes only the validated file restore flow', (
    tester,
  ) async {
    final store = AppStore(
      repository: InMemoryAppRepository(),
      vaultService: VaultService(backend: TestVaultBackend()),
    );
    addTearDown(store.dispose);

    await tester.pumpWidget(MaterialApp(home: InsightsScreen(store: store)));

    await tester.tap(find.byTooltip('Резервная копия'));
    await tester.pumpAndSettle();

    expect(find.text('Восстановить из JSON'), findsNothing);
    expect(find.text('Восстановить из файла'), findsOneWidget);

    await tester.tap(find.text('Восстановить из файла'));
    await tester.pumpAndSettle();

    expect(find.byType(DevicesScreen), findsOneWidget);
    expect(find.text('Вставь JSON резервной копии'), findsNothing);
  });
}
