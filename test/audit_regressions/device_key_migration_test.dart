import 'package:chronicle/data/database/chronicle_database.dart';
import 'package:chronicle/data/repositories/drift_app_repository.dart';
import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/security/device_key_store.dart';
import 'package:chronicle/services/app_store.dart';
import 'package:chronicle/sync/pairing_crypto.dart';
import 'package:chronicle/sync/pairing_models.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_vault_backend.dart';

void main() {
  test('plaintext DB key migrates once into secure storage', () async {
    final database = ChronicleDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftAppRepository(database: database);
    final crypto = PairingCrypto();
    final legacy = await crypto.generateKeyMaterial();
    final secureStore = _MemoryDeviceKeyStore();
    await repository.saveDeviceKeyMaterial(legacy);
    expect(await _legacyKeyRows(database), hasLength(1));
    final manager = DeviceKeyManager(
      repository: repository,
      secureStore: secureStore,
      crypto: crypto,
    );

    final migrated = await manager.ensure();

    expect(_sameKey(migrated, legacy), isTrue);
    expect(_sameKey(secureStore.value!, legacy), isTrue);
    expect(await repository.loadDeviceKeyMaterial(), isNull);
    expect(await _legacyKeyRows(database), isEmpty);
    expect(secureStore.writeCount, 1);

    final second = await manager.ensure();
    expect(_sameKey(second, legacy), isTrue);
    expect(secureStore.writeCount, 1);
  });

  test('secure-store failure never deletes the recoverable DB key', () async {
    final repository = InMemoryAppRepository();
    final crypto = PairingCrypto();
    final legacy = await crypto.generateKeyMaterial();
    await repository.saveDeviceKeyMaterial(legacy);
    final manager = DeviceKeyManager(
      repository: repository,
      secureStore: _MemoryDeviceKeyStore(failWrites: true),
      crypto: crypto,
    );

    await expectLater(manager.ensure(), throwsA(isA<StateError>()));

    final preserved = await repository.loadDeviceKeyMaterial();
    expect(preserved, isNotNull);
    expect(_sameKey(preserved!, legacy), isTrue);
  });

  test('failed secure readback is rolled back and keeps the DB key', () async {
    final repository = InMemoryAppRepository();
    final crypto = PairingCrypto();
    final legacy = await crypto.generateKeyMaterial();
    await repository.saveDeviceKeyMaterial(legacy);
    final secureStore = _MemoryDeviceKeyStore(corruptReadBack: true);
    final manager = DeviceKeyManager(
      repository: repository,
      secureStore: secureStore,
      crypto: crypto,
    );

    await expectLater(manager.ensure(), throwsA(isA<StateError>()));

    expect(secureStore.value, isNull);
    expect(secureStore.deleteCount, 1);
    expect(await repository.loadDeviceKeyMaterial(), isNotNull);
  });

  test(
    'production startup migrates a legacy key without user action',
    () async {
      final repository = InMemoryAppRepository();
      final legacy = await PairingCrypto().generateKeyMaterial();
      final secureStore = _MemoryDeviceKeyStore();
      await repository.saveDeviceKeyMaterial(legacy);
      final store = AppStore(
        repository: repository,
        vaultService: VaultService(backend: TestVaultBackend()),
        deviceKeyStore: secureStore,
        migrateDeviceKeyOnStartup: true,
      );
      addTearDown(store.dispose);

      await store.load();

      expect(store.loadError, isNull);
      expect(_sameKey(secureStore.value!, legacy), isTrue);
      expect(await repository.loadDeviceKeyMaterial(), isNull);
    },
  );

  test('secure-store outage does not block access to local notes', () async {
    final repository = InMemoryAppRepository();
    final legacy = await PairingCrypto().generateKeyMaterial();
    await repository.saveDeviceKeyMaterial(legacy);
    final store = AppStore(
      repository: repository,
      vaultService: VaultService(backend: TestVaultBackend()),
      deviceKeyStore: _MemoryDeviceKeyStore(failWrites: true),
      migrateDeviceKeyOnStartup: true,
    );
    addTearDown(store.dispose);

    await store.load();

    expect(store.loadError, isNull);
    expect(store.lanAutoSyncError, isNotNull);
    expect(await repository.loadDeviceKeyMaterial(), isNotNull);
  });
}

Future<List<Map<String, Object?>>> _legacyKeyRows(
  ChronicleDatabase database,
) async {
  final rows =
      await database
          .customSelect(
            'SELECT key, value FROM app_state '
            "WHERE key = 'device_key_material_v1'",
          )
          .get();
  return rows
      .where((row) => row.read<String>('key') == 'device_key_material_v1')
      .map((row) => row.data)
      .toList(growable: false);
}

class _MemoryDeviceKeyStore implements DeviceKeyStore {
  _MemoryDeviceKeyStore({
    this.failWrites = false,
    this.corruptReadBack = false,
  });

  final bool failWrites;
  final bool corruptReadBack;
  DeviceKeyMaterial? value;
  int writeCount = 0;
  int deleteCount = 0;
  bool _hasWritten = false;

  @override
  Future<void> delete() async {
    deleteCount += 1;
    value = null;
  }

  @override
  Future<DeviceKeyMaterial?> read() async {
    final current = value;
    if (!corruptReadBack || !_hasWritten || current == null) {
      return current;
    }
    return DeviceKeyMaterial(
      privateKeyBase64: '${current.privateKeyBase64}corrupted',
      publicKeyBase64: current.publicKeyBase64,
      createdAt: current.createdAt,
    );
  }

  @override
  Future<void> write(DeviceKeyMaterial material) async {
    if (failWrites) {
      throw StateError('secure write failed');
    }
    writeCount += 1;
    value = material;
    _hasWritten = true;
  }
}

bool _sameKey(DeviceKeyMaterial left, DeviceKeyMaterial right) {
  return left.privateKeyBase64 == right.privateKeyBase64 &&
      left.publicKeyBase64 == right.publicKeyBase64 &&
      left.createdAt.toUtc() == right.createdAt.toUtc();
}
