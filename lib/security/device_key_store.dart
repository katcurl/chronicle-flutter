import '../data/repositories/app_repository.dart';
import '../sync/pairing_crypto.dart';
import '../sync/pairing_models.dart';
import 'package:synchronized/synchronized.dart';

abstract interface class DeviceKeyStore {
  Future<DeviceKeyMaterial?> read();

  Future<void> write(DeviceKeyMaterial material);

  Future<void> delete();
}

class DeviceKeyManager {
  const DeviceKeyManager({
    required AppRepository repository,
    required DeviceKeyStore secureStore,
    required PairingCrypto crypto,
  }) : _repository = repository,
       _secureStore = secureStore,
       _crypto = crypto;

  final AppRepository _repository;
  final DeviceKeyStore _secureStore;
  final PairingCrypto _crypto;
  static final Lock _migrationLock = Lock();

  Future<DeviceKeyMaterial> ensure() {
    return _migrationLock.synchronized(_ensureUnlocked);
  }

  Future<DeviceKeyMaterial> _ensureUnlocked() async {
    final secure = await _secureStore.read();
    final legacy = await _repository.loadDeviceKeyMaterial();
    if (secure != null) {
      await _verify(secure);
      if (legacy != null) {
        if (!_sameMaterial(secure, legacy)) {
          throw StateError(
            'Secure device key differs from the recoverable database key.',
          );
        }
        await _repository.deleteDeviceKeyMaterial();
      }
      return secure;
    }

    final candidate = legacy ?? await _crypto.generateKeyMaterial();
    await _verify(candidate);
    try {
      await _secureStore.write(candidate);
      final readBack = await _secureStore.read();
      if (readBack == null || !_sameMaterial(readBack, candidate)) {
        throw StateError('Secure device key verification failed.');
      }
      await _verify(readBack);
    } on Object catch (error) {
      Object? cleanupError;
      try {
        await _secureStore.delete();
      } on Object catch (caught) {
        cleanupError = caught;
      }
      final cleanupSuffix =
          cleanupError == null
              ? ''
              : ' Secure-store rollback also failed: $cleanupError';
      throw StateError(
        'Could not persist the device key securely: $error.$cleanupSuffix',
      );
    }
    if (legacy != null) {
      await _repository.deleteDeviceKeyMaterial();
    }
    return candidate;
  }

  Future<void> _verify(DeviceKeyMaterial material) async {
    final challenge = 'chronicle-device-key-check:${_crypto.randomToken()}';
    final signature = await _crypto.sign(challenge, material);
    final valid = await _crypto.verify(
      message: challenge,
      signatureBase64: signature,
      publicKeyBase64: material.publicKeyBase64,
    );
    if (!valid) {
      throw StateError('Stored device key failed cryptographic verification.');
    }
  }
}

bool _sameMaterial(DeviceKeyMaterial left, DeviceKeyMaterial right) {
  return left.privateKeyBase64 == right.privateKeyBase64 &&
      left.publicKeyBase64 == right.publicKeyBase64 &&
      left.createdAt.toUtc() == right.createdAt.toUtc();
}
