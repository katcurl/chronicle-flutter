import 'dart:convert';

import 'pairing_models.dart';

const lanAutoSyncProtocol = 'chronicle-auto-sync-v1';
const lanDiscoveryPort = 45891;

class LanDiscoveryAnnouncement {
  const LanDiscoveryAnnouncement({
    required this.peer,
    required this.httpPort,
    required this.sentAt,
    required this.nonce,
    required this.signature,
  });

  final PairingPeer peer;
  final int httpPort;
  final DateTime sentAt;
  final String nonce;
  final String signature;

  String get signingPayload => jsonEncode({
    'protocol': lanAutoSyncProtocol,
    'kind': 'announcement',
    'peer': peer.toJson(),
    'httpPort': httpPort,
    'sentAt': sentAt.toUtc().toIso8601String(),
    'nonce': nonce,
  });

  Map<String, dynamic> toJson() => {
    'protocol': lanAutoSyncProtocol,
    'kind': 'announcement',
    'peer': peer.toJson(),
    'httpPort': httpPort,
    'sentAt': sentAt.toUtc().toIso8601String(),
    'nonce': nonce,
    'signature': signature,
  };

  factory LanDiscoveryAnnouncement.fromJson(Map<String, dynamic> json) {
    if (json['protocol'] != lanAutoSyncProtocol ||
        json['kind'] != 'announcement') {
      throw const FormatException('Unsupported Chronicle discovery packet.');
    }
    return LanDiscoveryAnnouncement(
      peer: PairingPeer.fromJson(
        Map<String, dynamic>.from(json['peer']! as Map),
      ),
      httpPort: (json['httpPort']! as num).toInt(),
      sentAt: DateTime.parse(json['sentAt']! as String).toLocal(),
      nonce: json['nonce']! as String,
      signature: json['signature']! as String,
    );
  }
}

class LanDiscoveredPeer {
  const LanDiscoveredPeer({
    required this.peer,
    required this.host,
    required this.port,
    required this.lastSeenAt,
  });

  final PairingPeer peer;
  final String host;
  final int port;
  final DateTime lastSeenAt;

  String get endpoint => '$host:$port';

  bool isOnlineAt(DateTime now) =>
      now.difference(lastSeenAt) < const Duration(seconds: 18);

  LanDiscoveredPeer seenAgain({
    required String host,
    required int port,
    required DateTime at,
    PairingPeer? peer,
  }) {
    return LanDiscoveredPeer(
      peer: peer ?? this.peer,
      host: host,
      port: port,
      lastSeenAt: at,
    );
  }
}

class LanAutoSyncOfferRequest {
  const LanAutoSyncOfferRequest({
    required this.requestId,
    required this.targetDeviceId,
    required this.sentAt,
    required this.peer,
    required this.signature,
  });

  final String requestId;
  final String targetDeviceId;
  final DateTime sentAt;
  final PairingPeer peer;
  final String signature;

  String get signingPayload => jsonEncode({
    'protocol': lanAutoSyncProtocol,
    'kind': 'offer-request',
    'requestId': requestId,
    'targetDeviceId': targetDeviceId,
    'sentAt': sentAt.toUtc().toIso8601String(),
    'peer': peer.toJson(),
  });

  Map<String, dynamic> toJson() => {
    'protocol': lanAutoSyncProtocol,
    'kind': 'offer-request',
    'requestId': requestId,
    'targetDeviceId': targetDeviceId,
    'sentAt': sentAt.toUtc().toIso8601String(),
    'peer': peer.toJson(),
    'signature': signature,
  };

  factory LanAutoSyncOfferRequest.fromJson(Map<String, dynamic> json) {
    if (json['protocol'] != lanAutoSyncProtocol ||
        json['kind'] != 'offer-request') {
      throw const FormatException('Unsupported Chronicle auto-sync request.');
    }
    return LanAutoSyncOfferRequest(
      requestId: json['requestId']! as String,
      targetDeviceId: json['targetDeviceId']! as String,
      sentAt: DateTime.parse(json['sentAt']! as String).toLocal(),
      peer: PairingPeer.fromJson(
        Map<String, dynamic>.from(json['peer']! as Map),
      ),
      signature: json['signature']! as String,
    );
  }
}

class LanAutoSyncOfferResponse {
  const LanAutoSyncOfferResponse({
    required this.requestId,
    required this.sentAt,
    required this.peer,
    required this.encodedOffer,
    required this.signature,
  });

  final String requestId;
  final DateTime sentAt;
  final PairingPeer peer;
  final String encodedOffer;
  final String signature;

  String get signingPayload => jsonEncode({
    'protocol': lanAutoSyncProtocol,
    'kind': 'offer-response',
    'requestId': requestId,
    'sentAt': sentAt.toUtc().toIso8601String(),
    'peer': peer.toJson(),
    'encodedOffer': encodedOffer,
  });

  Map<String, dynamic> toJson() => {
    'protocol': lanAutoSyncProtocol,
    'kind': 'offer-response',
    'requestId': requestId,
    'sentAt': sentAt.toUtc().toIso8601String(),
    'peer': peer.toJson(),
    'encodedOffer': encodedOffer,
    'signature': signature,
  };

  factory LanAutoSyncOfferResponse.fromJson(Map<String, dynamic> json) {
    if (json['protocol'] != lanAutoSyncProtocol ||
        json['kind'] != 'offer-response') {
      throw const FormatException('Unsupported Chronicle auto-sync response.');
    }
    return LanAutoSyncOfferResponse(
      requestId: json['requestId']! as String,
      sentAt: DateTime.parse(json['sentAt']! as String).toLocal(),
      peer: PairingPeer.fromJson(
        Map<String, dynamic>.from(json['peer']! as Map),
      ),
      encodedOffer: json['encodedOffer']! as String,
      signature: json['signature']! as String,
    );
  }
}
