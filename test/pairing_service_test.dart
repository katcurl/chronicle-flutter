import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/sync/pairing_models.dart';
import 'package:chronicle/sync/pairing_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local pairing identity remains stable', () async {
    final repository = InMemoryAppRepository();
    final service = PairingService(repository: repository);

    final first = await service.ensureLocalIdentity();
    final second = await service.ensureLocalIdentity();

    expect(second.peer.deviceId, first.peer.deviceId);
    expect(second.peer.publicKey, first.peer.publicKey);
    expect(
      second.keyMaterial.privateKeyBase64,
      first.keyMaterial.privateKeyBase64,
    );
  });

  test('trusted peer is persisted without a cloud account', () async {
    final repository = InMemoryAppRepository();
    final service = PairingService(repository: repository);
    const peer = PairingPeer(
      deviceId: 'phone-1',
      displayName: 'Телефон',
      platform: 'android',
      publicKey: 'phone-public-key',
    );

    await service.trustPeer(peer);
    final devices = await repository.loadTrustedDevices();

    expect(devices, hasLength(1));
    expect(devices.single.deviceId, peer.deviceId);
    expect(devices.single.publicKey, peer.publicKey);
    expect(devices.single.revokedAt, isNull);
  });
}
