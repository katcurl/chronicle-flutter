import 'dart:typed_data';

import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/screens/devices_screen.dart';
import 'package:chronicle/services/app_store.dart';
import 'package:chronicle/vault/vault_backend.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('devices screen shows local sync, Vault and backup foundation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = AppStore(
      repository: InMemoryAppRepository(),
      vaultService: VaultService(backend: _MemoryVaultBackend()),
    );
    await store.load();
    addTearDown(store.dispose);

    await tester.pumpWidget(MaterialApp(home: DevicesScreen(store: store)));
    await tester.pumpAndSettle();

    expect(find.text('Устройства и синхронизация'), findsOneWidget);
    expect(find.text('Автосинхронизация'), findsOneWidget);
    expect(find.text('Подключить устройство'), findsOneWidget);
    expect(find.text('Журнал изменений'), findsOneWidget);
    expect(find.text('Markdown Vault'), findsOneWidget);
    expect(find.text('Экспортировать Chronicle'), findsOneWidget);
    expect(find.text('Восстановить из файла'), findsOneWidget);
  });
}

class _MemoryVaultBackend extends VaultBackend {
  final Map<String, String> files = {};

  @override
  Future<String?> resolveRootPath() async => '/memory/Chronicle Vault';

  @override
  Future<String?> chooseRootPath() async => '/memory/Chronicle Vault';

  @override
  Future<void> writeFiles({
    required String rootPath,
    required Map<String, String> files,
    required Set<String> staleManagedPaths,
  }) async {
    for (final path in staleManagedPaths) {
      this.files.remove(path);
    }
    this.files.addAll(files);
  }

  @override
  Future<String?> readTextFile(String rootPath, String relativePath) async {
    return files[relativePath];
  }

  @override
  Future<bool> fileExists(String rootPath, String relativePath) async {
    return files.containsKey(relativePath);
  }

  @override
  Future<String?> saveBackup({
    required String fileName,
    required Uint8List bytes,
  }) async => '/memory/$fileName';

  @override
  Future<PickedVaultFile?> pickBackup() async => null;

  @override
  Future<String> writeEmergencyBackup({
    required String rootPath,
    required String fileName,
    required Uint8List bytes,
  }) async => '/memory/$fileName';
}
