import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../sync/pairing_models.dart';
import 'device_key_store.dart';

class SecureDeviceKeyStore implements DeviceKeyStore {
  SecureDeviceKeyStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              resetOnError: false,
              migrateWithBackup: false,
              storageNamespace: 'chronicle_device_keys',
            ),
            wOptions: WindowsOptions(useBackwardCompatibility: false),
          );

  static const storageKey = 'chronicle.device.ed25519.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<DeviceKeyMaterial?> read() async {
    final raw = await _storage.read(key: storageKey);
    if (raw == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('Secure device key is not an object.');
      }
      return DeviceKeyMaterial.fromJson(Map<String, dynamic>.from(decoded));
    } on Object catch (error) {
      throw StateError('Secure device key is corrupted: $error');
    }
  }

  @override
  Future<void> write(DeviceKeyMaterial material) {
    return _storage.write(
      key: storageKey,
      value: jsonEncode(material.toJson()),
    );
  }

  @override
  Future<void> delete() => _storage.delete(key: storageKey);
}
