import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/main.dart';
import 'package:chronicle/services/app_store.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_vault_backend.dart';

void main() {
  testWidgets('compact layout uses bottom navigation', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = _createStore();

    await tester.pumpWidget(ChronicleApp(store: store));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('wide layout uses navigation rail', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = _createStore();

    await tester.pumpWidget(ChronicleApp(store: store));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('very wide layout shows context panel', (tester) async {
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = _createStore();

    await tester.pumpWidget(ChronicleApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Контекст'), findsOneWidget);
    expect(find.text('Быстрые клавиши'), findsOneWidget);
  });
}

AppStore _createStore() {
  return AppStore(
    repository: InMemoryAppRepository(),
    vaultService: VaultService(backend: TestVaultBackend()),
  );
}
