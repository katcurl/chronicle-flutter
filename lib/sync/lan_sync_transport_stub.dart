import 'attachment_sync_models.dart';
import 'lan_sync_models.dart';
import 'lan_sync_resilience.dart';
import 'pairing_crypto.dart';
import 'pairing_models.dart';
import 'sync_models.dart';

typedef BuildOutgoingBatch =
    Future<SyncJournalBatch> Function(
      String peerDeviceId,
      int afterSequence,
      int limit,
    );
typedef ApplyIncomingChanges =
    Future<SyncApplyResult> Function(List<ChangeRecord> changes);
typedef LoadPeerCursor = Future<SyncCursor> Function(String peerDeviceId);
typedef SavePeerCursor = Future<void> Function(SyncCursor cursor);
typedef MarkPeerSyncSuccess =
    Future<void> Function(PairingPeer peer, DateTime completedAt);
typedef RemoteAppliedCallback = Future<void> Function(SyncApplyResult result);

class LanSyncHostSession {
  LanSyncHostSession._();

  static Future<LanSyncHostSession> start({
    required LocalPairingIdentity local,
    required PairingPeer targetPeer,
    required PairingCrypto crypto,
    required BuildOutgoingBatch buildOutgoing,
    required ApplyIncomingChanges applyIncoming,
    required LoadPeerCursor loadCursor,
    required SavePeerCursor saveCursor,
    required MarkPeerSyncSuccess markSuccess,
    required BuildAttachmentSyncManifest buildAttachmentManifest,
    required ReadAttachmentForSync readAttachment,
    required StoreAttachmentFromSync storeAttachment,
    required ApplyAttachmentRecordFromSync applyAttachmentRecord,
    required ApplyAttachmentTombstoneFromSync applyAttachmentTombstone,
    bool localNetworkOnly = true,
    RemoteAppliedCallback? onRemoteApplied,
  }) {
    throw UnsupportedError(
      'LAN-синхронизация доступна в нативных Android и desktop-сборках.',
    );
  }

  List<String> get addresses => const [];
  Stream<LanSyncReport> get reports => const Stream.empty();
  Stream<LanSyncProgress> get progress => const Stream.empty();
  Future<LanSyncOffer> offerFor(String address) async {
    throw UnsupportedError('');
  }

  Future<void> close() async {}
}

class LanSyncClient {
  const LanSyncClient._();

  static Future<LanSyncReport> sync({
    required LanSyncOffer offer,
    required LocalPairingIdentity local,
    required PairingPeer trustedHost,
    required PairingCrypto crypto,
    required BuildOutgoingBatch buildOutgoing,
    required ApplyIncomingChanges applyIncoming,
    required LoadPeerCursor loadCursor,
    required SavePeerCursor saveCursor,
    required MarkPeerSyncSuccess markSuccess,
    required BuildAttachmentSyncManifest buildAttachmentManifest,
    required ReadAttachmentForSync readAttachment,
    required StoreAttachmentFromSync storeAttachment,
    required ApplyAttachmentRecordFromSync applyAttachmentRecord,
    required ApplyAttachmentTombstoneFromSync applyAttachmentTombstone,
    bool localNetworkOnly = true,
    RemoteAppliedCallback? onRemoteApplied,
    LanSyncProgressCallback? onProgress,
    LanSyncCancellationToken? cancellationToken,
  }) {
    throw UnsupportedError(
      'LAN-синхронизация доступна в нативных Android и desktop-сборках.',
    );
  }
}
