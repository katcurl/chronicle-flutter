import 'dart:convert';

import 'package:flutter/foundation.dart';

DateTime _readSyncDate(dynamic value, {DateTime? fallback}) {
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return parsed;
    }
  }
  return fallback ?? DateTime.now();
}

DateTime? _readNullableSyncDate(dynamic value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

bool _readSyncBool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is int) {
    return value != 0;
  }
  return fallback;
}

int _readSyncInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

String currentPlatformCode() {
  if (kIsWeb) {
    return 'web';
  }
  return defaultTargetPlatform.name;
}

String defaultDeviceDisplayName() {
  final platform = currentPlatformCode();
  return switch (platform) {
    'android' => 'Телефон Android',
    'iOS' || 'ios' => 'iPhone или iPad',
    'windows' => 'Компьютер Windows',
    'linux' => 'Компьютер Linux',
    'macOS' || 'macos' => 'Компьютер macOS',
    'web' => 'Chronicle Web',
    _ => 'Устройство Chronicle',
  };
}

String platformDisplayName(String platform) {
  return switch (platform.toLowerCase()) {
    'android' => 'Android',
    'ios' => 'iOS',
    'windows' => 'Windows',
    'linux' => 'Linux',
    'macos' => 'macOS',
    'web' => 'Web',
    _ => platform,
  };
}

class DeviceIdentity {
  DeviceIdentity({
    required this.deviceId,
    required this.displayName,
    required this.platform,
    required this.createdAt,
    required this.lastSeenAt,
  });

  final String deviceId;
  String displayName;
  final String platform;
  final DateTime createdAt;
  DateTime lastSeenAt;

  String get shortId {
    final compact = deviceId.replaceAll('-', '').toUpperCase();
    if (compact.length <= 8) {
      return compact;
    }
    return '${compact.substring(0, 4)}…${compact.substring(compact.length - 4)}';
  }

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'displayName': displayName,
    'platform': platform,
    'createdAt': createdAt.toIso8601String(),
    'lastSeenAt': lastSeenAt.toIso8601String(),
  };

  Map<String, Object?> toDb() => {
    'device_id': deviceId,
    'display_name': displayName,
    'platform': platform,
    'created_at': createdAt.toIso8601String(),
    'last_seen_at': lastSeenAt.toIso8601String(),
  };

  factory DeviceIdentity.fromDb(Map<String, Object?> row) => DeviceIdentity(
    deviceId: row['device_id']! as String,
    displayName: row['display_name']! as String,
    platform: row['platform']! as String,
    createdAt: _readSyncDate(row['created_at']),
    lastSeenAt: _readSyncDate(row['last_seen_at']),
  );
}

class TrustedDevice {
  TrustedDevice({
    required this.deviceId,
    required this.displayName,
    required this.platform,
    required this.publicKey,
    required this.pairedAt,
    this.lastSeenAt,
    this.lastSyncAt,
    this.revokedAt,
    this.autoSyncEnabled = true,
  });

  final String deviceId;
  String displayName;
  final String platform;
  final String publicKey;
  final DateTime pairedAt;
  DateTime? lastSeenAt;
  DateTime? lastSyncAt;
  DateTime? revokedAt;
  bool autoSyncEnabled;

  bool get isActive => revokedAt == null;

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'displayName': displayName,
    'platform': platform,
    'publicKey': publicKey,
    'pairedAt': pairedAt.toIso8601String(),
    'lastSeenAt': lastSeenAt?.toIso8601String(),
    'lastSyncAt': lastSyncAt?.toIso8601String(),
    'revokedAt': revokedAt?.toIso8601String(),
    'autoSyncEnabled': autoSyncEnabled,
  };

  Map<String, Object?> toDb() => {
    'device_id': deviceId,
    'display_name': displayName,
    'platform': platform,
    'public_key': publicKey,
    'paired_at': pairedAt.toIso8601String(),
    'last_seen_at': lastSeenAt?.toIso8601String(),
    'last_sync_at': lastSyncAt?.toIso8601String(),
    'revoked_at': revokedAt?.toIso8601String(),
    'auto_sync_enabled': autoSyncEnabled ? 1 : 0,
  };

  factory TrustedDevice.fromDb(Map<String, Object?> row) => TrustedDevice(
    deviceId: row['device_id']! as String,
    displayName: row['display_name']! as String,
    platform: row['platform']! as String,
    publicKey: row['public_key'] as String? ?? '',
    pairedAt: _readSyncDate(row['paired_at']),
    lastSeenAt: _readNullableSyncDate(row['last_seen_at']),
    lastSyncAt: _readNullableSyncDate(row['last_sync_at']),
    revokedAt: _readNullableSyncDate(row['revoked_at']),
    autoSyncEnabled: _readSyncBool(row['auto_sync_enabled'], fallback: true),
  );
}

class ChangeRecord {
  ChangeRecord({
    required this.localSequence,
    required this.changeId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.revision,
    required this.originDeviceId,
    required this.changedAt,
    required this.payloadJson,
    this.appliedAt,
  });

  final int localSequence;
  final String changeId;
  final String entityType;
  final String entityId;
  final String operation;
  final int revision;
  final String originDeviceId;
  final DateTime changedAt;
  final String payloadJson;
  final DateTime? appliedAt;

  Map<String, dynamic> get payload {
    try {
      final decoded = jsonDecode(payloadJson);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } on Object {
      // The raw payload remains available for diagnostics.
    }
    return const {};
  }

  Map<String, dynamic> toJson() => {
    'localSequence': localSequence,
    'changeId': changeId,
    'entityType': entityType,
    'entityId': entityId,
    'operation': operation,
    'revision': revision,
    'originDeviceId': originDeviceId,
    'changedAt': changedAt.toUtc().toIso8601String(),
    'payload': payload,
    'appliedAt': appliedAt?.toUtc().toIso8601String(),
  };

  ChangeRecord copyWith({int? localSequence, DateTime? appliedAt}) {
    return ChangeRecord(
      localSequence: localSequence ?? this.localSequence,
      changeId: changeId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      revision: revision,
      originDeviceId: originDeviceId,
      changedAt: changedAt,
      payloadJson: payloadJson,
      appliedAt: appliedAt ?? this.appliedAt,
    );
  }

  factory ChangeRecord.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload'];
    final payload =
        rawPayload is Map
            ? Map<String, dynamic>.from(rawPayload)
            : const <String, dynamic>{};
    return ChangeRecord(
      localSequence: _readSyncInt(json['localSequence']),
      changeId: json['changeId']! as String,
      entityType: json['entityType']! as String,
      entityId: json['entityId']! as String,
      operation: json['operation']! as String,
      revision: _readSyncInt(json['revision'], fallback: 1),
      originDeviceId: json['originDeviceId']! as String,
      changedAt: _readSyncDate(json['changedAt']).toLocal(),
      payloadJson: jsonEncode(payload),
      appliedAt: _readNullableSyncDate(json['appliedAt'])?.toLocal(),
    );
  }

  factory ChangeRecord.fromDb(Map<String, Object?> row) => ChangeRecord(
    localSequence: _readSyncInt(row['local_sequence']),
    changeId: row['change_id']! as String,
    entityType: row['entity_type']! as String,
    entityId: row['entity_id']! as String,
    operation: row['operation']! as String,
    revision: _readSyncInt(row['revision'], fallback: 1),
    originDeviceId: row['origin_device_id']! as String,
    changedAt: _readSyncDate(row['changed_at']),
    payloadJson: row['payload_json'] as String? ?? '{}',
    appliedAt: _readNullableSyncDate(row['applied_at']),
  );
}

int compareChangeFreshness(ChangeRecord left, ChangeRecord right) {
  final revision = left.revision.compareTo(right.revision);
  if (revision != 0) {
    return revision;
  }
  final changedAt = left.changedAt.toUtc().compareTo(right.changedAt.toUtc());
  if (changedAt != 0) {
    return changedAt;
  }
  return left.changeId.compareTo(right.changeId);
}

class SyncJournalBatch {
  const SyncJournalBatch({
    required this.afterSequence,
    required this.throughSequence,
    required this.changes,
    required this.hasMore,
  });

  final int afterSequence;
  final int throughSequence;
  final List<ChangeRecord> changes;
  final bool hasMore;

  bool get isEmpty => changes.isEmpty;

  Map<String, dynamic> toJson() => {
    'afterSequence': afterSequence,
    'throughSequence': throughSequence,
    'hasMore': hasMore,
    'changes': changes.map((change) => change.toJson()).toList(growable: false),
  };

  factory SyncJournalBatch.fromJson(Map<String, dynamic> json) {
    final rawChanges = json['changes'] as List? ?? const [];
    return SyncJournalBatch(
      afterSequence: _readSyncInt(json['afterSequence']),
      throughSequence: _readSyncInt(json['throughSequence']),
      hasMore: _readSyncBool(json['hasMore']),
      changes: rawChanges
          .map(
            (change) =>
                ChangeRecord.fromJson(Map<String, dynamic>.from(change as Map)),
          )
          .toList(growable: false),
    );
  }
}

const int defaultMaxJournalEntries = 50000;
const int defaultMaxJournalPayloadBytes = 100 * 1024 * 1024;

class JournalCompactionResult {
  const JournalCompactionResult({
    required this.didCompact,
    required this.entryCountBefore,
    required this.entryCountAfter,
    required this.payloadBytesBefore,
    required this.payloadBytesAfter,
    required this.generation,
    required this.lastCompactedSequence,
    required this.minimumPeerCursor,
    required this.maxEntries,
    required this.maxPayloadBytes,
  });

  final bool didCompact;
  final int entryCountBefore;
  final int entryCountAfter;
  final int payloadBytesBefore;
  final int payloadBytesAfter;
  final int generation;
  final int lastCompactedSequence;
  final int? minimumPeerCursor;
  final int maxEntries;
  final int maxPayloadBytes;

  bool get withinBudget =>
      entryCountAfter <= maxEntries && payloadBytesAfter <= maxPayloadBytes;
}

class SyncApplyResult {
  const SyncApplyResult({
    required this.receivedCount,
    required this.insertedCount,
    required this.appliedCount,
    required this.duplicateCount,
    required this.staleCount,
    required this.unsupportedCount,
  });

  final int receivedCount;
  final int insertedCount;
  final int appliedCount;
  final int duplicateCount;
  final int staleCount;
  final int unsupportedCount;

  bool get changedData => appliedCount > 0;

  Map<String, dynamic> toJson() => {
    'receivedCount': receivedCount,
    'insertedCount': insertedCount,
    'appliedCount': appliedCount,
    'duplicateCount': duplicateCount,
    'staleCount': staleCount,
    'unsupportedCount': unsupportedCount,
  };

  factory SyncApplyResult.fromJson(Map<String, dynamic> json) {
    return SyncApplyResult(
      receivedCount: _readSyncInt(json['receivedCount']),
      insertedCount: _readSyncInt(json['insertedCount']),
      appliedCount: _readSyncInt(json['appliedCount']),
      duplicateCount: _readSyncInt(json['duplicateCount']),
      staleCount: _readSyncInt(json['staleCount']),
      unsupportedCount: _readSyncInt(json['unsupportedCount']),
    );
  }
}

class SyncCursor {
  SyncCursor({
    required this.peerDeviceId,
    this.lastSentSequence = 0,
    this.lastReceivedChangeId,
    this.lastSuccessAt,
  });

  final String peerDeviceId;
  int lastSentSequence;
  String? lastReceivedChangeId;
  DateTime? lastSuccessAt;

  Map<String, Object?> toDb() => {
    'peer_device_id': peerDeviceId,
    'last_sent_sequence': lastSentSequence,
    'last_received_change_id': lastReceivedChangeId,
    'last_success_at': lastSuccessAt?.toIso8601String(),
  };

  factory SyncCursor.fromDb(Map<String, Object?> row) => SyncCursor(
    peerDeviceId: row['peer_device_id']! as String,
    lastSentSequence: _readSyncInt(row['last_sent_sequence']),
    lastReceivedChangeId: row['last_received_change_id'] as String?,
    lastSuccessAt: _readNullableSyncDate(row['last_success_at']),
  );
}

class SyncPreferences {
  const SyncPreferences({
    this.autoSyncEnabled = true,
    this.discoverOnLocalNetwork = true,
    this.localNetworkOnly = true,
  });

  final bool autoSyncEnabled;
  final bool discoverOnLocalNetwork;
  final bool localNetworkOnly;

  SyncPreferences copyWith({
    bool? autoSyncEnabled,
    bool? discoverOnLocalNetwork,
    bool? localNetworkOnly,
  }) {
    return SyncPreferences(
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      discoverOnLocalNetwork:
          discoverOnLocalNetwork ?? this.discoverOnLocalNetwork,
      localNetworkOnly: localNetworkOnly ?? this.localNetworkOnly,
    );
  }

  Map<String, dynamic> toJson() => {
    'autoSyncEnabled': autoSyncEnabled,
    'discoverOnLocalNetwork': discoverOnLocalNetwork,
    'localNetworkOnly': localNetworkOnly,
  };

  factory SyncPreferences.fromJson(Map<String, dynamic> json) {
    return SyncPreferences(
      autoSyncEnabled: _readSyncBool(json['autoSyncEnabled'], fallback: true),
      discoverOnLocalNetwork: _readSyncBool(
        json['discoverOnLocalNetwork'],
        fallback: true,
      ),
      localNetworkOnly: _readSyncBool(json['localNetworkOnly'], fallback: true),
    );
  }
}
