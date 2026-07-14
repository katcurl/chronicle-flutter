import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/screens/devices_screen.dart';
import 'package:chronicle/services/app_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('devices screen shows local-only sync foundation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1800));

    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final store = AppStore(repository: InMemoryAppRepository());
    await store.load();

    addTearDown(store.dispose);

    await tester.pumpWidget(MaterialApp(home: DevicesScreen(store: store)));

    await tester.pumpAndSettle();

    expect(find.text('Устройства и синхронизация'), findsOneWidget);

    expect(find.text('Автосинхронизация'), findsOneWidget);

    expect(find.text('Подключить устройство'), findsOneWidget);

    expect(find.text('Журнал изменений'), findsOneWidget);
  });
}
