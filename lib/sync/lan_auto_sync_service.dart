import '../data/repositories/app_repository.dart';
import 'lan_auto_sync_models.dart';
import 'lan_auto_sync_transport.dart';
import 'lan_sync_models.dart';
import 'lan_sync_service.dart';
import 'sync_models.dart';

class IncomingAutoSyncPolicy {
  const IncomingAutoSyncPolicy({
    required Future<bool> Function() globallyEnabled,
    required Future<bool> Function(String peerDeviceId) peerEnabled,
  }) : _globallyEnabled = globallyEnabled,
       _peerEnabled = peerEnabled;

  final Future<bool> Function() _globallyEnabled;
  final Future<bool> Function(String peerDeviceId) _peerEnabled;

  Future<bool> allows(String peerDeviceId) async {
    if (!await _globallyEnabled()) {
      return false;
    }
    return _peerEnabled(peerDeviceId);
  }
}

class LanAutoSyncService {
  LanAutoSyncService({
    required AppRepository repository,
    required LanSyncService lanSyncService,
  }) : _repository = repository,
       _lanSyncService = lanSyncService;

  final AppRepository _repository;
  final LanSyncService _lanSyncService;

  Future<LanAutoSyncNode> start({
    required Future<bool> Function() incomingAutoSyncEnabled,
    required bool localNetworkOnly,
    Future<void> Function(SyncApplyResult result)? onRemoteApplied,
  }) async {
    final local = await _lanSyncService.ensureLocalIdentity();
    final policy = IncomingAutoSyncPolicy(
      globallyEnabled: incomingAutoSyncEnabled,
      peerEnabled: deviceAllowsAutoSync,
    );
    return LanAutoSyncNode.start(
      local: local,
      crypto: _lanSyncService.crypto,
      lookupTrustedPeer: _lanSyncService.trustedPeerOrNull,
      allowIncomingSync: policy.allows,
      localNetworkOnly: localNetworkOnly,
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
