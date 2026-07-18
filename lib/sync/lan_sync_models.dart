import 'dart:convert';

import 'attachment_sync_models.dart';
import 'pairing_models.dart';
import 'sync_models.dart';

const lanSyncProtocol = 'chronicle-sync-v3';

class LanSyncOffer {
  const LanSyncOffer({
    required this.host,
    required this.port,
    required this.sessionId,
    required this.token,
    required this.expiresAt,
    required this.hostPeer,
    required this.targetDeviceId,
  });

  final String host;
  final int port;
  final String sessionId;
  final String token;
  final DateTime expiresAt;
  final PairingPeer hostPeer;
  final String targetDeviceId;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  LanSyncOffer copyWithHost(String value) => LanSyncOffer(
    host: value,
    port: port,
    sessionId: sessionId,
    token: token,
    expiresAt: expiresAt,
    hostPeer: hostPeer,
    targetDeviceId: targetDeviceId,
  );

  Map<String, dynamic> toJson() => {
    'protocol': lanSyncProtocol,
    'host': host,
    'port': port,
    'sessionId': sessionId,
    'token': token,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'hostPeer': hostPeer.toJson(),
    'targetDeviceId': targetDeviceId,
  };

  String encode() {
    final bytes = utf8.encode(jsonEncode(toJson()));
    final payload = base64Url.encode(bytes).replaceAll('=', '');
    return 'chronicle://sync/$payload';
  }

  factory LanSyncOffer.decode(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != 'chronicle' || uri.host != 'sync') {
      throw const FormatException('Это не код синхронизации Chronicle.');
    }
    final payload = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
    if (payload.isEmpty) {
      throw const FormatException('Код не содержит данных синхронизации.');
    }
    final decoded = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(payload))),
    );
    if (decoded is! Map) {
      throw const FormatException('Неверный формат кода Chronicle.');
    }
    final json = Map<String, dynamic>.from(decoded);
    if (json['protocol'] != lanSyncProtocol) {
      throw const FormatException('Эта версия протокола не поддерживается.');
    }
    final offer = LanSyncOffer(
      host: json['host']! as String,
      port: (json['port']! as num).toInt(),
      sessionId: json['sessionId']! as String,
      token: json['token']! as String,
      expiresAt: DateTime.parse(json['expiresAt']! as String).toLocal(),
      hostPeer: PairingPeer.fromJson(
        Map<String, dynamic>.from(json['hostPeer']! as Map),
      ),
      targetDeviceId: json['targetDeviceId']! as String,
    );
    if (offer.isExpired) {
      throw const FormatException('Срок действия кода синхронизации истёк.');
    }
    return offer;
  }
}

class LanSyncExchangeRequest {
  const LanSyncExchangeRequest({
    required this.sessionId,
    required this.token,
    required this.roundId,
    required this.peer,
    required this.batch,
    required this.signature,
    this.attachmentManifest = const AttachmentSyncManifest.empty(),
  });

  final String sessionId;
  final String token;
  final String roundId;
  final PairingPeer peer;
  final SyncJournalBatch batch;
  final AttachmentSyncManifest attachmentManifest;
  final String signature;

  String get signingPayload => jsonEncode({
    'protocol': lanSyncProtocol,
    'kind': 'exchange-request',
    'sessionId': sessionId,
    'token': token,
    'roundId': roundId,
    'peer': peer.toJson(),
    'batch': batch.toJson(),
    'attachmentManifest': attachmentManifest.toJson(),
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'token': token,
    'roundId': roundId,
    'peer': peer.toJson(),
    'batch': batch.toJson(),
    'attachmentManifest': attachmentManifest.toJson(),
    'signature': signature,
  };

  factory LanSyncExchangeRequest.fromJson(Map<String, dynamic> json) {
    return LanSyncExchangeRequest(
      sessionId: json['sessionId']! as String,
      token: json['token']! as String,
      roundId: json['roundId']! as String,
      peer: PairingPeer.fromJson(
        Map<String, dynamic>.from(json['peer']! as Map),
      ),
      batch: SyncJournalBatch.fromJson(
        Map<String, dynamic>.from(json['batch']! as Map),
      ),
      attachmentManifest: _readAttachmentManifest(json['attachmentManifest']),
      signature: json['signature']! as String,
    );
  }
}

class LanSyncExchangeResponse {
  const LanSyncExchangeResponse({
    required this.sessionId,
    required this.roundId,
    required this.hostPeer,
    required this.batch,
    required this.remoteApplyResult,
    required this.signature,
    this.attachmentManifest = const AttachmentSyncManifest.empty(),
    this.requesterAttachmentPlan = const AttachmentSyncPlan.empty(),
    this.responderAttachmentPlan = const AttachmentSyncPlan.empty(),
  });

  final String sessionId;
  final String roundId;
  final PairingPeer hostPeer;
  final SyncJournalBatch batch;
  final SyncApplyResult remoteApplyResult;
  final AttachmentSyncManifest attachmentManifest;
  final AttachmentSyncPlan requesterAttachmentPlan;
  final AttachmentSyncPlan responderAttachmentPlan;
  final String signature;

  String get signingPayload => jsonEncode({
    'protocol': lanSyncProtocol,
    'kind': 'exchange-response',
    'sessionId': sessionId,
    'roundId': roundId,
    'hostPeer': hostPeer.toJson(),
    'batch': batch.toJson(),
    'remoteApplyResult': remoteApplyResult.toJson(),
    'attachmentManifest': attachmentManifest.toJson(),
    'requesterAttachmentPlan': requesterAttachmentPlan.toJson(),
    'responderAttachmentPlan': responderAttachmentPlan.toJson(),
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'roundId': roundId,
    'hostPeer': hostPeer.toJson(),
    'batch': batch.toJson(),
    'remoteApplyResult': remoteApplyResult.toJson(),
    'attachmentManifest': attachmentManifest.toJson(),
    'requesterAttachmentPlan': requesterAttachmentPlan.toJson(),
    'responderAttachmentPlan': responderAttachmentPlan.toJson(),
    'signature': signature,
  };

  factory LanSyncExchangeResponse.fromJson(Map<String, dynamic> json) {
    return LanSyncExchangeResponse(
      sessionId: json['sessionId']! as String,
      roundId: json['roundId']! as String,
      hostPeer: PairingPeer.fromJson(
        Map<String, dynamic>.from(json['hostPeer']! as Map),
      ),
      batch: SyncJournalBatch.fromJson(
        Map<String, dynamic>.from(json['batch']! as Map),
      ),
      remoteApplyResult: SyncApplyResult.fromJson(
        Map<String, dynamic>.from(json['remoteApplyResult']! as Map),
      ),
      attachmentManifest: _readAttachmentManifest(json['attachmentManifest']),
      requesterAttachmentPlan: _readAttachmentPlan(
        json['requesterAttachmentPlan'],
      ),
      responderAttachmentPlan: _readAttachmentPlan(
        json['responderAttachmentPlan'],
      ),
      signature: json['signature']! as String,
    );
  }
}

enum LanAttachmentCommandKind {
  download,
  upload,
  record,
  tombstone,
}

class LanAttachmentCommand {
  const LanAttachmentCommand({
    required this.sessionId,
    required this.token,
    required this.transferId,
    required this.peer,
    required this.kind,
    required this.entry,
    required this.signature,
    this.dataBase64,
  });

  final String sessionId;
  final String token;
  final String transferId;
  final PairingPeer peer;
  final LanAttachmentCommandKind kind;
  final AttachmentSyncEntry entry;
  final String? dataBase64;
  final String signature;

  String get signingPayload => jsonEncode({
    'protocol': lanSyncProtocol,
    'kind': 'attachment-command',
    'sessionId': sessionId,
    'token': token,
    'transferId': transferId,
    'peer': peer.toJson(),
    'action': kind.name,
    'entry': entry.toJson(),
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sessionId': sessionId,
    'token': token,
    'transferId': transferId,
    'peer': peer.toJson(),
    'action': kind.name,
    'entry': entry.toJson(),
    if (dataBase64 != null) 'dataBase64': dataBase64,
    'signature': signature,
  };

  factory LanAttachmentCommand.fromJson(Map<String, dynamic> json) {
    final rawAction = json['action']?.toString() ?? '';
    final kind = LanAttachmentCommandKind.values.where(
      (candidate) => candidate.name == rawAction,
    );
    if (kind.isEmpty) {
      throw const FormatException('Unsupported attachment command.');
    }
    return LanAttachmentCommand(
      sessionId: json['sessionId']! as String,
      token: json['token']! as String,
      transferId: json['transferId']! as String,
      peer: PairingPeer.fromJson(
        Map<String, dynamic>.from(json['peer']! as Map),
      ),
      kind: kind.first,
      entry: AttachmentSyncEntry.fromJson(
        Map<String, dynamic>.from(json['entry']! as Map),
      ),
      dataBase64: json['dataBase64'] as String?,
      signature: json['signature']! as String,
    );
  }
}

class LanAttachmentCommandResponse {
  const LanAttachmentCommandResponse({
    required this.sessionId,
    required this.transferId,
    required this.hostPeer,
    required this.kind,
    required this.entry,
    required this.changed,
    required this.signature,
    this.dataBase64,
  });

  final String sessionId;
  final String transferId;
  final PairingPeer hostPeer;
  final LanAttachmentCommandKind kind;
  final AttachmentSyncEntry entry;
  final bool changed;
  final String? dataBase64;
  final String signature;

  String get signingPayload => jsonEncode({
    'protocol': lanSyncProtocol,
    'kind': 'attachment-response',
    'sessionId': sessionId,
    'transferId': transferId,
    'hostPeer': hostPeer.toJson(),
    'action': kind.name,
    'entry': entry.toJson(),
    'changed': changed,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sessionId': sessionId,
    'transferId': transferId,
    'hostPeer': hostPeer.toJson(),
    'action': kind.name,
    'entry': entry.toJson(),
    'changed': changed,
    if (dataBase64 != null) 'dataBase64': dataBase64,
    'signature': signature,
  };

  factory LanAttachmentCommandResponse.fromJson(Map<String, dynamic> json) {
    final rawAction = json['action']?.toString() ?? '';
    final kind = LanAttachmentCommandKind.values.where(
      (candidate) => candidate.name == rawAction,
    );
    if (kind.isEmpty) {
      throw const FormatException('Unsupported attachment response.');
    }
    return LanAttachmentCommandResponse(
      sessionId: json['sessionId']! as String,
      transferId: json['transferId']! as String,
      hostPeer: PairingPeer.fromJson(
        Map<String, dynamic>.from(json['hostPeer']! as Map),
      ),
      kind: kind.first,
      entry: AttachmentSyncEntry.fromJson(
        Map<String, dynamic>.from(json['entry']! as Map),
      ),
      changed: json['changed'] == true,
      dataBase64: json['dataBase64'] as String?,
      signature: json['signature']! as String,
    );
  }
}

class LanSyncAck {
  const LanSyncAck({
    required this.sessionId,
    required this.roundId,
    required this.clientDeviceId,
    required this.receivedThroughSequence,
    required this.signature,
  });

  final String sessionId;
  final String roundId;
  final String clientDeviceId;
  final int receivedThroughSequence;
  final String signature;

  String get signingPayload => jsonEncode({
    'protocol': lanSyncProtocol,
    'kind': 'ack',
    'sessionId': sessionId,
    'roundId': roundId,
    'clientDeviceId': clientDeviceId,
    'receivedThroughSequence': receivedThroughSequence,
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'roundId': roundId,
    'clientDeviceId': clientDeviceId,
    'receivedThroughSequence': receivedThroughSequence,
    'signature': signature,
  };

  factory LanSyncAck.fromJson(Map<String, dynamic> json) => LanSyncAck(
    sessionId: json['sessionId']! as String,
    roundId: json['roundId']! as String,
    clientDeviceId: json['clientDeviceId']! as String,
    receivedThroughSequence: (json['receivedThroughSequence']! as num).toInt(),
    signature: json['signature']! as String,
  );
}


enum LanSyncProgressStage {
  preparing,
  exchangingJournal,
  downloadingAttachment,
  applyingAttachmentMetadata,
  uploadingAttachment,
  finalizing,
}

class LanSyncProgress {
  const LanSyncProgress({
    required this.stage,
    this.round = 0,
    this.completedItems = 0,
    this.totalItems = 0,
    this.bytesTransferred = 0,
    this.totalBytes = 0,
    this.currentFileName,
  });

  final LanSyncProgressStage stage;
  final int round;
  final int completedItems;
  final int totalItems;
  final int bytesTransferred;
  final int totalBytes;
  final String? currentFileName;

  double? get fraction {
    final transferringBytes =
        stage == LanSyncProgressStage.downloadingAttachment ||
        stage == LanSyncProgressStage.uploadingAttachment;
    if (transferringBytes && totalBytes > 0) {
      return (bytesTransferred / totalBytes).clamp(0.0, 1.0).toDouble();
    }
    if (totalItems > 0) {
      return (completedItems / totalItems).clamp(0.0, 1.0).toDouble();
    }
    return null;
  }
}

typedef LanSyncProgressCallback = void Function(LanSyncProgress progress);

class LanSyncReport {
  const LanSyncReport({
    required this.peer,
    required this.startedAt,
    required this.completedAt,
    required this.roundCount,
    required this.sentCount,
    required this.receivedCount,
    required this.appliedCount,
    required this.duplicateCount,
    required this.staleCount,
    required this.unsupportedCount,
    required this.hasMore,
    this.attachmentPlanFromPeer = const AttachmentSyncPlan.empty(),
    this.attachmentPlanByPeer = const AttachmentSyncPlan.empty(),
    this.attachmentFilesReceived = 0,
    this.attachmentFilesSent = 0,
    this.attachmentBytesReceived = 0,
    this.attachmentBytesSent = 0,
    this.attachmentRecordsApplied = 0,
    this.attachmentTombstonesApplied = 0,
  });

  final PairingPeer peer;
  final DateTime startedAt;
  final DateTime completedAt;
  final int roundCount;
  final int sentCount;
  final int receivedCount;
  final int appliedCount;
  final int duplicateCount;
  final int staleCount;
  final int unsupportedCount;
  final bool hasMore;
  final AttachmentSyncPlan attachmentPlanFromPeer;
  final AttachmentSyncPlan attachmentPlanByPeer;
  final int attachmentFilesReceived;
  final int attachmentFilesSent;
  final int attachmentBytesReceived;
  final int attachmentBytesSent;
  final int attachmentRecordsApplied;
  final int attachmentTombstonesApplied;

  int get attachmentConflictCount =>
      attachmentPlanFromPeer.conflictCount +
      attachmentPlanByPeer.conflictCount;

  bool get changedData =>
      appliedCount > 0 ||
      attachmentFilesReceived > 0 ||
      attachmentRecordsApplied > 0 ||
      attachmentTombstonesApplied > 0;

  bool get hasPendingAttachmentWork => attachmentConflictCount > 0;

  LanSyncReport merge(LanSyncReport other) {
    if (peer.deviceId != other.peer.deviceId) {
      throw ArgumentError('Нельзя объединить отчёты разных устройств.');
    }
    return LanSyncReport(
      peer: other.peer,
      startedAt:
          startedAt.isBefore(other.startedAt) ? startedAt : other.startedAt,
      completedAt:
          completedAt.isAfter(other.completedAt)
              ? completedAt
              : other.completedAt,
      roundCount: roundCount + other.roundCount,
      sentCount: sentCount + other.sentCount,
      receivedCount: receivedCount + other.receivedCount,
      appliedCount: appliedCount + other.appliedCount,
      duplicateCount: duplicateCount + other.duplicateCount,
      staleCount: staleCount + other.staleCount,
      unsupportedCount: unsupportedCount + other.unsupportedCount,
      hasMore: other.hasMore,
      attachmentPlanFromPeer: other.attachmentPlanFromPeer,
      attachmentPlanByPeer: other.attachmentPlanByPeer,
      attachmentFilesReceived:
          attachmentFilesReceived + other.attachmentFilesReceived,
      attachmentFilesSent: attachmentFilesSent + other.attachmentFilesSent,
      attachmentBytesReceived:
          attachmentBytesReceived + other.attachmentBytesReceived,
      attachmentBytesSent: attachmentBytesSent + other.attachmentBytesSent,
      attachmentRecordsApplied:
          attachmentRecordsApplied + other.attachmentRecordsApplied,
      attachmentTombstonesApplied:
          attachmentTombstonesApplied + other.attachmentTombstonesApplied,
    );
  }
}

AttachmentSyncManifest _readAttachmentManifest(Object? value) {
  if (value is! Map) {
    return const AttachmentSyncManifest.empty();
  }
  return AttachmentSyncManifest.fromJson(
    value.map(
      (key, item) => MapEntry<String, dynamic>(key.toString(), item),
    ),
  );
}

AttachmentSyncPlan _readAttachmentPlan(Object? value) {
  if (value is! Map) {
    return const AttachmentSyncPlan.empty();
  }
  return AttachmentSyncPlan.fromJson(
    value.map(
      (key, item) => MapEntry<String, dynamic>(key.toString(), item),
    ),
  );
}
