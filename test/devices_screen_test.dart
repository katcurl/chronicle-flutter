import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/screens/devices_screen.dart';
import 'package:chronicle/services/app_store.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_vault_backend.dart';

void main() {
  testWidgets('devices screen shows local sync, Vault and backup foundation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2200));

    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final store = AppStore(
      repository: InMemoryAppRepository(),
      vaultService: VaultService(backend: TestVaultBackend()),
    );

    addTearDown(store.dispose);

    await store.load();

    expect(
      store.loadError,
      isNull,
      reason: 'Ошибка загрузки AppStore: ${store.loadError}',
    );

    await tester.pumpWidget(MaterialApp(home: DevicesScreen(store: store)));

    await tester.pump();

    expect(find.text('Устройства и синхронизация'), findsOneWidget);
    expect(find.text('Автосинхронизация'), findsOneWidget);
    expect(find.text('Подключить устройство'), findsOneWidget);
    expect(find.text('Журнал изменений'), findsOneWidget);
    expect(find.text('Markdown Vault'), findsOneWidget);
    expect(find.text('Экспортировать Chronicle'), findsOneWidget);
    expect(find.text('Восстановить из файла'), findsOneWidget);
  });
}
