import 'dart:typed_data';

import '../data/repositories/app_repository.dart';
import 'attachment_sync_models.dart';
import 'lan_sync_models.dart';
import 'lan_sync_transport.dart';
import 'pairing_crypto.dart';
import 'pairing_models.dart';
import 'sync_models.dart';

class LanSyncService {
  LanSyncService({
    required AppRepository repository,
    PairingCrypto? crypto,
    BuildAttachmentSyncManifest? buildAttachmentManifest,
    ReadAttachmentForSync? readAttachment,
    StoreAttachmentFromSync? storeAttachment,
    ApplyAttachmentRecordFromSync? applyAttachmentRecord,
    ApplyAttachmentTombstoneFromSync? applyAttachmentTombstone,
  }) : _repository = repository,
       crypto = crypto ?? PairingCrypto(),
       _buildAttachmentManifest =
           buildAttachmentManifest ?? _emptyAttachmentManifest,
       _readAttachment = readAttachment ?? _missingAttachment,
       _storeAttachment = storeAttachment ?? _unsupportedStoreAttachment,
       _applyAttachmentRecord =
           applyAttachmentRecord ?? _unsupportedAttachmentRecord,
       _applyAttachmentTombstone =
           applyAttachmentTombstone ?? _unsupportedAttachmentTombstone;

  final AppRepository _repository;
  final PairingCrypto crypto;
  final BuildAttachmentSyncManifest _buildAttachmentManifest;
  final ReadAttachmentForSync _readAttachment;
  final StoreAttachmentFromSync _storeAttachment;
  final ApplyAttachmentRecordFromSync _applyAttachmentRecord;
  final ApplyAttachmentTombstoneFromSync _applyAttachmentTombstone;

  Future<LocalPairingIdentity> ensureLocalIdentity() => _ensureLocalIdentity();

  Future<PairingPeer?> trustedPeerOrNull(String deviceId) async {
    final devices = await _repository.loadTrustedDevices(includeRevoked: true);
    for (final device in devices) {
      if (device.deviceId == deviceId &&
          device.isActive &&
          device.publicKey.isNotEmpty) {
        return _peerFromTrusted(device);
      }
    }
    return null;
  }

  Future<LanSyncHostSession> startHost({
    required String peerDeviceId,
    Future<void> Function(SyncApplyResult result)? onRemoteApplied,
  }) async {
    final local = await _ensureLocalIdentity();
    final trusted = await _trustedDevice(peerDeviceId);
    final targetPeer = _peerFromTrusted(trusted);
    return LanSyncHostSession.start(
      local: local,
      targetPeer: targetPeer,
      crypto: crypto,
      buildOutgoing: _buildOutgoing,
      applyIncoming: _repository.applyRemoteChanges,
      loadCursor: _loadCursor,
      saveCursor: _repository.saveSyncCursor,
      markSuccess: _markSuccess,
      buildAttachmentManifest: _buildAttachmentManifest,
      readAttachment: _readAttachment,
      storeAttachment: _storeAttachment,
      applyAttachmentRecord: _applyAttachmentRecord,
      applyAttachmentTombstone: _applyAttachmentTombstone,
      onRemoteApplied: onRemoteApplied,
    );
  }

  Future<LanSyncReport> syncFromOffer(
    String rawOffer, {
    required String expectedPeerDeviceId,
    Future<void> Function(SyncApplyResult result)? onRemoteApplied,
  }) async {
    final offer = LanSyncOffer.decode(rawOffer);
    if (offer.hostPeer.deviceId != expectedPeerDeviceId) {
      throw StateError('Код относится к другому связанному устройству.');
    }
    final local = await _ensureLocalIdentity();
    final trusted = await _trustedDevice(expectedPeerDeviceId);
    return LanSyncClient.sync(
      offer: offer,
      local: local,
      trustedHost: _peerFromTrusted(trusted),
      crypto: crypto,
      buildOutgoing: _buildOutgoing,
      applyIncoming: _repository.applyRemoteChanges,
      loadCursor: _loadCursor,
      saveCursor: _repository.saveSyncCursor,
      markSuccess: _markSuccess,
      buildAttachmentManifest: _buildAttachmentManifest,
      readAttachment: _readAttachment,
      storeAttachment: _storeAttachment,
      applyAttachmentRecord: _applyAttachmentRecord,
      applyAttachmentTombstone: _applyAttachmentTombstone,
      onRemoteApplied: onRemoteApplied,
    );
  }

  Future<LocalPairingIdentity> _ensureLocalIdentity() async {
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

  Future<TrustedDevice> _trustedDevice(String deviceId) async {
    final devices = await _repository.loadTrustedDevices(includeRevoked: true);
    for (final device in devices) {
      if (device.deviceId == deviceId && device.isActive) {
        if (device.publicKey.isEmpty) {
          throw StateError(
            'У доверенного устройства отсутствует открытый ключ.',
          );
        }
        return device;
      }
    }
    throw StateError('Устройство больше не входит в список доверенных.');
  }

  PairingPeer _peerFromTrusted(TrustedDevice device) => PairingPeer(
    deviceId: device.deviceId,
    displayName: device.displayName,
    platform: device.platform,
    publicKey: device.publicKey,
  );

  Future<SyncJournalBatch> _buildOutgoing(
    String peerDeviceId,
    int afterSequence,
    int limit,
  ) {
    return _repository.loadOutgoingChanges(
      peerDeviceId: peerDeviceId,
      afterSequence: afterSequence,
      limit: limit,
    );
  }

  Future<SyncCursor> _loadCursor(String peerDeviceId) async {
    final cursors = await _repository.loadSyncCursors();
    for (final cursor in cursors) {
      if (cursor.peerDeviceId == peerDeviceId) {
        return cursor;
      }
    }
    return SyncCursor(peerDeviceId: peerDeviceId);
  }

  Future<void> _markSuccess(PairingPeer peer, DateTime completedAt) async {
    final trusted = await _trustedDevice(peer.deviceId);
    trusted.displayName = peer.displayName;
    trusted.lastSeenAt = completedAt;
    trusted.lastSyncAt = completedAt;
    await _repository.saveTrustedDevice(trusted);
  }
}

Future<AttachmentSyncManifest> _emptyAttachmentManifest() async {
  return AttachmentSyncManifest(generatedAt: DateTime.now().toUtc());
}


Future<Uint8List?> _missingAttachment(AttachmentSyncEntry entry) async => null;

Future<AttachmentSyncApplyResult> _unsupportedStoreAttachment(
  AttachmentSyncEntry entry,
  Uint8List bytes,
) {
  throw UnsupportedError('Хранилище вложений не подключено.');
}

Future<AttachmentSyncApplyResult> _unsupportedAttachmentRecord(
  AttachmentSyncEntry entry,
) {
  throw UnsupportedError('Хранилище вложений не подключено.');
}

Future<AttachmentSyncApplyResult> _unsupportedAttachmentTombstone(
  AttachmentSyncEntry entry,
) {
  throw UnsupportedError('Хранилище вложений не подключено.');
}
