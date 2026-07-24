import 'dart:convert';

import 'pairing_models.dart';

const lanSyncProtocol = 'chronicle-sync-v4';
const lanSyncSecurityVersion = 2;

class LanSyncOffer {
  const LanSyncOffer({
    required this.host,
    required this.port,
    required this.sessionId,
    required this.expiresAt,
    required this.hostPeer,
    required this.targetDeviceId,
    required this.hostEphemeralX25519PublicKey,
    required this.signature,
  });

  final String host;
  final int port;
  final String sessionId;
  final DateTime expiresAt;
  final PairingPeer hostPeer;
  final String targetDeviceId;
  final String hostEphemeralX25519PublicKey;
  final String signature;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  String get signingPayload => jsonEncode(<String, dynamic>{
    'protocol': lanSyncProtocol,
    'securityVersion': lanSyncSecurityVersion,
    'hostDeviceId': hostPeer.deviceId,
    'targetDeviceId': targetDeviceId,
    'host': host,
    'port': port,
    'sessionId': sessionId,
    'hostEphemeralX25519PublicKey': hostEphemeralX25519PublicKey,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'hostPeer': hostPeer.toJson(),
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'protocol': lanSyncProtocol,
    'securityVersion': lanSyncSecurityVersion,
    'host': host,
    'port': port,
    'sessionId': sessionId,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'hostPeer': hostPeer.toJson(),
    'targetDeviceId': targetDeviceId,
    'hostEphemeralX25519PublicKey': hostEphemeralX25519PublicKey,
    'signature': signature,
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
    if (json['protocol'] != lanSyncProtocol ||
        json['securityVersion'] != lanSyncSecurityVersion) {
      throw const FormatException(
        'Небезопасная или неподдерживаемая версия протокола.',
      );
    }
    final offer = LanSyncOffer(
      host: json['host']! as String,
      port: (json['port']! as num).toInt(),
      sessionId: json['sessionId']! as String,
      expiresAt: DateTime.parse(json['expiresAt']! as String).toLocal(),
      hostPeer: PairingPeer.fromJson(
        Map<String, dynamic>.from(json['hostPeer']! as Map),
      ),
      targetDeviceId: json['targetDeviceId']! as String,
      hostEphemeralX25519PublicKey:
          json['hostEphemeralX25519PublicKey']! as String,
      signature: json['signature']! as String,
    );
    if (offer.host.isEmpty ||
        offer.port <= 0 ||
        offer.port > 65535 ||
        offer.sessionId.isEmpty ||
        offer.targetDeviceId.isEmpty ||
        offer.hostEphemeralX25519PublicKey.isEmpty ||
        offer.signature.isEmpty) {
      throw const FormatException('Код синхронизации повреждён.');
    }
    if (offer.isExpired) {
      throw const FormatException('Срок действия кода синхронизации истёк.');
    }
    return offer;
  }
}

class LanSyncHandshakeRequest {
  const LanSyncHandshakeRequest({
    required this.sessionId,
    required this.peer,
    required this.clientEphemeralX25519PublicKey,
    required this.clientChallenge,
    required this.sentAt,
    required this.offerSignature,
    required this.signature,
  });

  final String sessionId;
  final PairingPeer peer;
  final String clientEphemeralX25519PublicKey;
  final String clientChallenge;
  final DateTime sentAt;
  final String offerSignature;
  final String signature;

  String signingPayload(String offerSigningPayload) =>
      jsonEncode(<String, dynamic>{
        'protocol': lanSyncProtocol,
        'securityVersion': lanSyncSecurityVersion,
        'kind': 'handshake-request',
        'offerSigningPayload': offerSigningPayload,
        'offerSignature': offerSignature,
        'sessionId': sessionId,
        'peer': peer.toJson(),
        'clientEphemeralX25519PublicKey': clientEphemeralX25519PublicKey,
        'clientChallenge': clientChallenge,
        'sentAt': sentAt.toUtc().toIso8601String(),
      });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'protocol': lanSyncProtocol,
    'securityVersion': lanSyncSecurityVersion,
    'kind': 'handshake-request',
    'sessionId': sessionId,
    'peer': peer.toJson(),
    'clientEphemeralX25519PublicKey': clientEphemeralX25519PublicKey,
    'clientChallenge': clientChallenge,
    'sentAt': sentAt.toUtc().toIso8601String(),
    'offerSignature': offerSignature,
    'signature': signature,
  };

  factory LanSyncHandshakeRequest.fromJson(Map<String, dynamic> json) {
    if (json['protocol'] != lanSyncProtocol ||
        json['securityVersion'] != lanSyncSecurityVersion ||
        json['kind'] != 'handshake-request') {
      throw const FormatException('Unsupported secure handshake.');
    }
    return LanSyncHandshakeRequest(
      sessionId: json['sessionId']! as String,
      peer: PairingPeer.fromJson(
        Map<String, dynamic>.from(json['peer']! as Map),
      ),
      clientEphemeralX25519PublicKey:
          json['clientEphemeralX25519PublicKey']! as String,
      clientChallenge: json['clientChallenge']! as String,
      sentAt: DateTime.parse(json['sentAt']! as String).toLocal(),
      offerSignature: json['offerSignature']! as String,
      signature: json['signature']! as String,
    );
  }
}

class LanSyncHandshakeResponse {
  const LanSyncHandshakeResponse({
    required this.sessionId,
    required this.hostDeviceId,
    required this.clientChallenge,
    required this.hostChallenge,
    required this.sentAt,
    required this.signature,
  });

  final String sessionId;
  final String hostDeviceId;
  final String clientChallenge;
  final String hostChallenge;
  final DateTime sentAt;
  final String signature;

  String signingPayload(
    String requestSigningPayload,
    String requestSignature,
  ) => jsonEncode(<String, dynamic>{
    'protocol': lanSyncProtocol,
    'securityVersion': lanSyncSecurityVersion,
    'kind': 'handshake-response',
    'requestSigningPayload': requestSigningPayload,
    'requestSignature': requestSignature,
    'sessionId': sessionId,
    'hostDeviceId': hostDeviceId,
    'clientChallenge': clientChallenge,
    'hostChallenge': hostChallenge,
    'sentAt': sentAt.toUtc().toIso8601String(),
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'protocol': lanSyncProtocol,
    'securityVersion': lanSyncSecurityVersion,
    'kind': 'handshake-response',
    'sessionId': sessionId,
    'hostDeviceId': hostDeviceId,
    'clientChallenge': clientChallenge,
    'hostChallenge': hostChallenge,
    'sentAt': sentAt.toUtc().toIso8601String(),
    'signature': signature,
  };

  factory LanSyncHandshakeResponse.fromJson(Map<String, dynamic> json) {
    if (json['protocol'] != lanSyncProtocol ||
        json['securityVersion'] != lanSyncSecurityVersion ||
        json['kind'] != 'handshake-response') {
      throw const FormatException('Unsupported secure handshake response.');
    }
    return LanSyncHandshakeResponse(
      sessionId: json['sessionId']! as String,
      hostDeviceId: json['hostDeviceId']! as String,
      clientChallenge: json['clientChallenge']! as String,
      hostChallenge: json['hostChallenge']! as String,
      sentAt: DateTime.parse(json['sentAt']! as String).toLocal(),
      signature: json['signature']! as String,
    );
  }
}

class EncryptedEnvelope {
  const EncryptedEnvelope({
    required this.counter,
    required this.context,
    required this.nonceBase64,
    required this.cipherTextBase64,
    required this.macBase64,
  });

  final int counter;
  final String context;
  final String nonceBase64;
  final String cipherTextBase64;
  final String macBase64;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'protocol': lanSyncProtocol,
    'securityVersion': lanSyncSecurityVersion,
    'counter': counter,
    'context': context,
    'nonce': nonceBase64,
    'cipherText': cipherTextBase64,
    'mac': macBase64,
  };

  factory EncryptedEnvelope.fromJson(Map<String, dynamic> json) {
    if (json['protocol'] != lanSyncProtocol ||
        json['securityVersion'] != lanSyncSecurityVersion) {
      throw const FormatException('Unsupported encrypted envelope.');
    }
    final counter = (json['counter']! as num).toInt();
    if (counter <= 0) {
      throw const FormatException('Invalid encrypted envelope counter.');
    }
    return EncryptedEnvelope(
      counter: counter,
      context: json['context']! as String,
      nonceBase64: json['nonce']! as String,
      cipherTextBase64: json['cipherText']! as String,
      macBase64: json['mac']! as String,
    );
  }
}
