import 'package:chronicle/security/device_key_store.dart';
import 'package:chronicle/sync/pairing_models.dart';

class MemoryDeviceKeyStore implements DeviceKeyStore {
  DeviceKeyMaterial? value;

  @override
  Future<void> delete() async {
    value = null;
  }

  @override
  Future<DeviceKeyMaterial?> read() async => value;

  @override
  Future<void> write(DeviceKeyMaterial material) async {
    value = material;
  }
}
