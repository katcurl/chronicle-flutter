import '../data/repositories/app_repository.dart';
import 'pairing_crypto.dart';
import 'pairing_models.dart';
import 'pairing_transport.dart';
import 'sync_models.dart';

class PairingService {
  PairingService({required AppRepository repository, PairingCrypto? crypto})
    : _repository = repository,
      crypto = crypto ?? PairingCrypto();

  final AppRepository _repository;
  final PairingCrypto crypto;

  Future<LocalPairingIdentity> ensureLocalIdentity() async {
    final identity = await _repository.ensureDeviceIdentity();
    var keyMaterial = await _repository.loadDeviceKeyMaterial();
    if (keyMaterial == null) {
      keyMaterial = await crypto.generateKeyMaterial();
      await _repository.saveDeviceKeyMaterial(keyMaterial);
    }
    return LocalPairingIdentity(
      peer: PairingPeer.local(identity, keyMaterial),
      keyMaterial: keyMaterial,
    );
  }

  Future<PairingHostSession> startHost() async {
    final local = await ensureLocalIdentity();
    return PairingHostSession.start(
      local: local,
      crypto: crypto,
      onTrust: trustPeer,
    );
  }

  Future<PairingClientSession> startClient(String rawOffer) async {
    final offer = PairingOffer.decode(rawOffer);
    final local = await ensureLocalIdentity();
    return PairingClientSession.start(
      offer: offer,
      local: local,
      crypto: crypto,
    );
  }

  Future<PairingClientResult> finishClient(PairingClientSession session) async {
    final result = await session.waitForApproval();
    await session.complete();
    await trustPeer(result.hostPeer);
    return result;
  }

  Future<void> trustPeer(PairingPeer peer) async {
    final now = DateTime.now();
    await _repository.saveTrustedDevice(
      TrustedDevice(
        deviceId: peer.deviceId,
        displayName: peer.displayName,
        platform: peer.platform,
        publicKey: peer.publicKey,
        pairedAt: now,
        lastSeenAt: now,
      ),
    );
  }
}
