import '../data/repositories/app_repository.dart';
import 'lan_auto_sync_models.dart';
import 'lan_auto_sync_transport.dart';
import 'lan_sync_models.dart';
import 'lan_sync_service.dart';
import 'sync_models.dart';

class LanAutoSyncService {
  LanAutoSyncService({
    required AppRepository repository,
    required LanSyncService lanSyncService,
  }) : _repository = repository,
       _lanSyncService = lanSyncService;

  final AppRepository _repository;
  final LanSyncService _lanSyncService;

  Future<LanAutoSyncNode> start({
    Future<void> Function(SyncApplyResult result)? onRemoteApplied,
  }) async {
    final local = await _lanSyncService.ensureLocalIdentity();
    return LanAutoSyncNode.start(
      local: local,
      crypto: _lanSyncService.crypto,
      lookupTrustedPeer: _lanSyncService.trustedPeerOrNull,
      startHost:
          (peerDeviceId) => _lanSyncService.startHost(
            peerDeviceId: peerDeviceId,
            onRemoteApplied: onRemoteApplied,
          ),
    );
  }

  Future<LanSyncReport> syncWithDiscoveredPeer({
    required LanAutoSyncNode node,
    required LanDiscoveredPeer discoveredPeer,
    Future<void> Function(SyncApplyResult result)? onRemoteApplied,
  }) async {
    final trusted = await _lanSyncService.trustedPeerOrNull(
      discoveredPeer.peer.deviceId,
    );
    if (trusted == null || trusted.publicKey != discoveredPeer.peer.publicKey) {
      throw StateError('Устройство больше не входит в список доверенных.');
    }
    final offer = await node.requestOffer(discoveredPeer);
    return _lanSyncService.syncFromOffer(
      offer,
      expectedPeerDeviceId: discoveredPeer.peer.deviceId,
      onRemoteApplied: onRemoteApplied,
    );
  }

  Future<bool> deviceAllowsAutoSync(String deviceId) async {
    final devices = await _repository.loadTrustedDevices(includeRevoked: true);
    for (final device in devices) {
      if (device.deviceId == deviceId && device.isActive) {
        return device.autoSyncEnabled;
      }
    }
    return false;
  }
}
