import 'lan_auto_sync_models.dart';
import 'lan_sync_models.dart';
import 'lan_sync_transport.dart';
import 'pairing_crypto.dart';
import 'pairing_models.dart';

typedef TrustedPeerLookup = Future<PairingPeer?> Function(String deviceId);
typedef StartLanSyncHost =
    Future<LanSyncHostSession> Function(String peerDeviceId);

class LanAutoSyncNode {
  LanAutoSyncNode._();

  static Future<LanAutoSyncNode> start({
    required LocalPairingIdentity local,
    required PairingCrypto crypto,
    required TrustedPeerLookup lookupTrustedPeer,
    required StartLanSyncHost startHost,
  }) {
    throw UnsupportedError(
      'Автоматическая LAN-синхронизация доступна в нативных сборках.',
    );
  }

  Stream<LanDiscoveredPeer> get peers => const Stream.empty();
  Stream<LanSyncReport> get reports => const Stream.empty();
  int get port => 0;
  Future<void> announceNow() async {}
  Future<String> requestOffer(LanDiscoveredPeer peer) =>
      throw UnsupportedError('Автоматическая LAN-синхронизация недоступна.');
  Future<void> close() async {}
}
