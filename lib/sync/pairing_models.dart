import 'dart:convert';

import 'sync_models.dart';

const pairingProtocol = 'chronicle-pair-v1';

class DeviceKeyMaterial {
  const DeviceKeyMaterial({
    required this.privateKeyBase64,
    required this.publicKeyBase64,
    required this.createdAt,
  });

  final String privateKeyBase64;
  final String publicKeyBase64;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'privateKey': privateKeyBase64,
    'publicKey': publicKeyBase64,
    'createdAt': createdAt.toIso8601String(),
  };

  factory DeviceKeyMaterial.fromJson(Map<String, dynamic> json) {
    return DeviceKeyMaterial(
      privateKeyBase64: json['privateKey']! as String,
      publicKeyBase64: json['publicKey']! as String,
      createdAt: DateTime.parse(json['createdAt']! as String),
    );
  }
}

class PairingPeer {
  const PairingPeer({
    required this.deviceId,
    required this.displayName,
    required this.platform,
    required this.publicKey,
  });

  final String deviceId;
  final String displayName;
  final String platform;
  final String publicKey;

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
    'publicKey': publicKey,
  };

  factory PairingPeer.fromJson(Map<String, dynamic> json) => PairingPeer(
    deviceId: json['deviceId']! as String,
    displayName: json['displayName']! as String,
    platform: json['platform']! as String,
    publicKey: json['publicKey']! as String,
  );

  factory PairingPeer.local(
    DeviceIdentity identity,
    DeviceKeyMaterial keyMaterial,
  ) {
    return PairingPeer(
      deviceId: identity.deviceId,
      displayName: identity.displayName,
      platform: identity.platform,
      publicKey: keyMaterial.publicKeyBase64,
    );
  }
}

class LocalPairingIdentity {
  const LocalPairingIdentity({required this.peer, required this.keyMaterial});

  final PairingPeer peer;
  final DeviceKeyMaterial keyMaterial;
}

class PairingOffer {
  const PairingOffer({
    required this.host,
    required this.port,
    required this.sessionId,
    required this.token,
    required this.expiresAt,
    required this.hostPeer,
  });

  final String host;
  final int port;
  final String sessionId;
  final String token;
  final DateTime expiresAt;
  final PairingPeer hostPeer;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  PairingOffer copyWithHost(String value) => PairingOffer(
    host: value,
    port: port,
    sessionId: sessionId,
    token: token,
    expiresAt: expiresAt,
    hostPeer: hostPeer,
  );

  Map<String, dynamic> toJson() => {
    'protocol': pairingProtocol,
    'host': host,
    'port': port,
    'sessionId': sessionId,
    'token': token,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'hostPeer': hostPeer.toJson(),
  };

  String encode() {
    final bytes = utf8.encode(jsonEncode(toJson()));
    final payload = base64Url.encode(bytes).replaceAll('=', '');
    return 'chronicle://pair/$payload';
  }

  factory PairingOffer.decode(String raw) {
    final trimmed = raw.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.scheme != 'chronicle' || uri.host != 'pair') {
      throw const FormatException('Это не QR-код Chronicle.');
    }
    final payload = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
    if (payload.isEmpty) {
      throw const FormatException('QR-код не содержит данных сопряжения.');
    }
    final normalized = base64Url.normalize(payload);
    final decoded = jsonDecode(utf8.decode(base64Url.decode(normalized)));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Неверный формат QR-кода Chronicle.');
    }
    if (decoded['protocol'] != pairingProtocol) {
      throw const FormatException('Эта версия протокола не поддерживается.');
    }
    final offer = PairingOffer(
      host: decoded['host']! as String,
      port: (decoded['port']! as num).toInt(),
      sessionId: decoded['sessionId']! as String,
      token: decoded['token']! as String,
      expiresAt: DateTime.parse(decoded['expiresAt']! as String).toLocal(),
      hostPeer: PairingPeer.fromJson(
        Map<String, dynamic>.from(decoded['hostPeer']! as Map),
      ),
    );
    if (offer.isExpired) {
      throw const FormatException('Срок действия QR-кода уже истёк.');
    }
    return offer;
  }
}

class PairingRequestPayload {
  const PairingRequestPayload({
    required this.sessionId,
    required this.token,
    required this.nonce,
    required this.peer,
    required this.signature,
  });

  final String sessionId;
  final String token;
  final String nonce;
  final PairingPeer peer;
  final String signature;

  String get signingPayload => jsonEncode({
    'protocol': pairingProtocol,
    'kind': 'request',
    'sessionId': sessionId,
    'token': token,
    'nonce': nonce,
    'peer': peer.toJson(),
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'token': token,
    'nonce': nonce,
    'peer': peer.toJson(),
    'signature': signature,
  };

  factory PairingRequestPayload.fromJson(Map<String, dynamic> json) {
    return PairingRequestPayload(
      sessionId: json['sessionId']! as String,
      token: json['token']! as String,
      nonce: json['nonce']! as String,
      peer: PairingPeer.fromJson(
        Map<String, dynamic>.from(json['peer']! as Map),
      ),
      signature: json['signature']! as String,
    );
  }
}

enum PairingRequestState { pending, approved, denied, completed }

class PairingIncomingRequest {
  const PairingIncomingRequest({
    required this.requestId,
    required this.peer,
    required this.confirmationCode,
    required this.receivedAt,
    required this.state,
  });

  final String requestId;
  final PairingPeer peer;
  final String confirmationCode;
  final DateTime receivedAt;
  final PairingRequestState state;

  PairingIncomingRequest copyWith({PairingRequestState? state}) {
    return PairingIncomingRequest(
      requestId: requestId,
      peer: peer,
      confirmationCode: confirmationCode,
      receivedAt: receivedAt,
      state: state ?? this.state,
    );
  }
}

class PairingPendingResponse {
  const PairingPendingResponse({
    required this.requestId,
    required this.confirmationCode,
    required this.expiresAt,
  });

  final String requestId;
  final String confirmationCode;
  final DateTime expiresAt;

  factory PairingPendingResponse.fromJson(Map<String, dynamic> json) {
    return PairingPendingResponse(
      requestId: json['requestId']! as String,
      confirmationCode: json['confirmationCode']! as String,
      expiresAt: DateTime.parse(json['expiresAt']! as String).toLocal(),
    );
  }
}

class PairingApprovalPayload {
  const PairingApprovalPayload({
    required this.sessionId,
    required this.requestId,
    required this.confirmationCode,
    required this.approvedAt,
    required this.hostPeer,
    required this.clientDeviceId,
    required this.signature,
  });

  final String sessionId;
  final String requestId;
  final String confirmationCode;
  final DateTime approvedAt;
  final PairingPeer hostPeer;
  final String clientDeviceId;
  final String signature;

  String get signingPayload => jsonEncode({
    'protocol': pairingProtocol,
    'kind': 'approval',
    'sessionId': sessionId,
    'requestId': requestId,
    'confirmationCode': confirmationCode,
    'approvedAt': approvedAt.toUtc().toIso8601String(),
    'hostPeer': hostPeer.toJson(),
    'clientDeviceId': clientDeviceId,
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'requestId': requestId,
    'confirmationCode': confirmationCode,
    'approvedAt': approvedAt.toUtc().toIso8601String(),
    'hostPeer': hostPeer.toJson(),
    'clientDeviceId': clientDeviceId,
    'signature': signature,
  };

  factory PairingApprovalPayload.fromJson(Map<String, dynamic> json) {
    return PairingApprovalPayload(
      sessionId: json['sessionId']! as String,
      requestId: json['requestId']! as String,
      confirmationCode: json['confirmationCode']! as String,
      approvedAt: DateTime.parse(json['approvedAt']! as String).toLocal(),
      hostPeer: PairingPeer.fromJson(
        Map<String, dynamic>.from(json['hostPeer']! as Map),
      ),
      clientDeviceId: json['clientDeviceId']! as String,
      signature: json['signature']! as String,
    );
  }
}

class PairingClientResult {
  const PairingClientResult({
    required this.hostPeer,
    required this.confirmationCode,
  });

  final PairingPeer hostPeer;
  final String confirmationCode;
}
