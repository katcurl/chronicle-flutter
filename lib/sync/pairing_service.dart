import '../data/repositories/app_repository.dart';
import '../security/device_key_store.dart';
import 'pairing_crypto.dart';
import 'pairing_models.dart';
import 'pairing_transport.dart';
import 'sync_models.dart';

class PairingService {
  PairingService({
    required AppRepository repository,
    required DeviceKeyStore deviceKeyStore,
    PairingCrypto? crypto,
  }) : _repository = repository,
       _deviceKeyStore = deviceKeyStore,
       crypto = crypto ?? PairingCrypto();

  final AppRepository _repository;
  final DeviceKeyStore _deviceKeyStore;
  final PairingCrypto crypto;

  Future<LocalPairingIdentity> ensureLocalIdentity() async {
    final identity = await _repository.ensureDeviceIdentity();
    final keyMaterial =
        await DeviceKeyManager(
          repository: _repository,
          secureStore: _deviceKeyStore,
          crypto: crypto,
        ).ensure();
    return LocalPairingIdentity(
      peer: PairingPeer.local(identity, keyMaterial),
      keyMaterial: keyMaterial,
    );
  }

  Future<PairingHostSession> startHost() async {
    final local = await ensureLocalIdentity();
    final preferences = await _repository.loadSyncPreferences();
    return PairingHostSession.start(
      local: local,
      crypto: crypto,
      onTrust: trustPeer,
      localNetworkOnly: preferences.localNetworkOnly,
    );
  }

  Future<PairingClientSession> startClient(String rawOffer) async {
    final offer = PairingOffer.decode(rawOffer);
    final local = await ensureLocalIdentity();
    final preferences = await _repository.loadSyncPreferences();
    return PairingClientSession.start(
      offer: offer,
      local: local,
      crypto: crypto,
      localNetworkOnly: preferences.localNetworkOnly,
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
