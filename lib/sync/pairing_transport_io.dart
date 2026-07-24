import 'dart:async';
import 'dart:io';

import 'package:uuid/uuid.dart';

import 'bounded_http_io.dart';
import 'lan_address_selector.dart';
import 'pairing_crypto.dart';
import 'pairing_models.dart';

class PairingHostSession {
  PairingHostSession._({
    required HttpServer server,
    required this.addresses,
    required this.sessionId,
    required this.token,
    required this.expiresAt,
    required this.local,
    required this.crypto,
    required Future<void> Function(PairingPeer peer) onTrust,
  }) : _server = server,
       _onTrust = onTrust;

  static Future<PairingHostSession> start({
    required LocalPairingIdentity local,
    required PairingCrypto crypto,
    required Future<void> Function(PairingPeer peer) onTrust,
    bool localNetworkOnly = true,
  }) async {
    final availableAddresses = await localLanIpv4Addresses(
      localNetworkOnly: localNetworkOnly,
    );
    if (availableAddresses.isEmpty) {
      throw StateError(
        'Не найден локальный IPv4-адрес. Подключи компьютер к Wi‑Fi или LAN.',
      );
    }
    final addresses =
        localNetworkOnly
            ? <String>[availableAddresses.first]
            : availableAddresses;
    final bindAddress =
        localNetworkOnly
            ? InternetAddress(addresses.first)
            : InternetAddress.anyIPv4;
    final server = await HttpServer.bind(bindAddress, 0);
    final session = PairingHostSession._(
      server: server,
      addresses: addresses,
      sessionId: const Uuid().v4(),
      token: crypto.randomToken(),
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      local: local,
      crypto: crypto,
      onTrust: onTrust,
    );
    session._subscription = server.listen(session._handleRequest);
    session._expiryTimer = Timer(
      session.expiresAt.difference(DateTime.now()),
      session.close,
    );
    return session;
  }

  final HttpServer _server;
  final List<String> addresses;
  final String sessionId;
  final String token;
  final DateTime expiresAt;
  final LocalPairingIdentity local;
  final PairingCrypto crypto;
  final Future<void> Function(PairingPeer peer) _onTrust;
  final StreamController<PairingIncomingRequest> _requestController =
      StreamController<PairingIncomingRequest>.broadcast();
  final Map<String, _PendingHostRequest> _pending = {};
  final HttpConcurrencyGate _requestGate = HttpConcurrencyGate(
    maxConcurrent: lanMaxUnauthenticatedRequests,
  );

  StreamSubscription<HttpRequest>? _subscription;
  Timer? _expiryTimer;
  bool _closed = false;

  Stream<PairingIncomingRequest> get requests => _requestController.stream;

  PairingOffer offerFor(String address) => PairingOffer(
    host: address,
    port: _server.port,
    sessionId: sessionId,
    token: token,
    expiresAt: expiresAt,
    hostPeer: local.peer,
  );

  Future<void> approve(String requestId) async {
    final pending = _pending[requestId];
    if (pending == null ||
        pending.request.state != PairingRequestState.pending) {
      return;
    }
    final approvedAt = DateTime.now();
    final unsigned = PairingApprovalPayload(
      sessionId: sessionId,
      requestId: requestId,
      confirmationCode: pending.request.confirmationCode,
      approvedAt: approvedAt,
      hostPeer: local.peer,
      clientDeviceId: pending.request.peer.deviceId,
      signature: '',
    );
    final signature = await crypto.sign(
      unsigned.signingPayload,
      local.keyMaterial,
    );
    pending.approval = PairingApprovalPayload(
      sessionId: sessionId,
      requestId: requestId,
      confirmationCode: pending.request.confirmationCode,
      approvedAt: approvedAt,
      hostPeer: local.peer,
      clientDeviceId: pending.request.peer.deviceId,
      signature: signature,
    );
    pending.request = pending.request.copyWith(
      state: PairingRequestState.approved,
    );
    _requestController.add(pending.request);
  }

  Future<void> deny(String requestId) async {
    final pending = _pending[requestId];
    if (pending == null ||
        pending.request.state != PairingRequestState.pending) {
      return;
    }
    pending.request = pending.request.copyWith(
      state: PairingRequestState.denied,
    );
    _requestController.add(pending.request);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (!_requestGate.tryAcquire()) {
      await _jsonResponse(request.response, HttpStatus.serviceUnavailable, {
        'error': 'too_many_requests',
      });
      return;
    }
    try {
      await _handleRequestWithinLimit(request);
    } finally {
      _requestGate.release();
    }
  }

  Future<void> _handleRequestWithinLimit(HttpRequest request) async {
    try {
      _applyCors(request.response);
      if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        return;
      }
      if (DateTime.now().isAfter(expiresAt)) {
        await _jsonResponse(request.response, HttpStatus.gone, {
          'error': 'pairing_expired',
        });
        return;
      }
      final path = request.uri.path;
      if (request.method == 'POST' && path == '/v1/pair/request') {
        await _handlePairRequest(request);
        return;
      }
      if (request.method == 'GET' && path.startsWith('/v1/pair/status/')) {
        final requestId = path.substring('/v1/pair/status/'.length);
        await _handleStatus(request.response, requestId);
        return;
      }
      if (request.method == 'POST' && path.startsWith('/v1/pair/complete/')) {
        final requestId = path.substring('/v1/pair/complete/'.length);
        await _handleComplete(request.response, requestId);
        return;
      }
      await _jsonResponse(request.response, HttpStatus.notFound, {
        'error': 'not_found',
      });
    } on Object catch (error) {
      try {
        await _jsonResponse(request.response, HttpStatus.badRequest, {
          'error': error.toString(),
        });
      } on Object {
        try {
          await request.response.close();
        } on Object {
          // The client may have disconnected while the error was handled.
        }
      }
    }
  }

  Future<void> _handlePairRequest(HttpRequest request) async {
    final decoded = await _readJson(request);
    final payload = PairingRequestPayload.fromJson(decoded);
    if (payload.sessionId != sessionId || payload.token != token) {
      await _jsonResponse(request.response, HttpStatus.forbidden, {
        'error': 'invalid_session',
      });
      return;
    }
    if (payload.peer.deviceId == local.peer.deviceId) {
      await _jsonResponse(request.response, HttpStatus.conflict, {
        'error': 'same_device',
      });
      return;
    }
    final valid = await crypto.verify(
      message: payload.signingPayload,
      signatureBase64: payload.signature,
      publicKeyBase64: payload.peer.publicKey,
    );
    if (!valid) {
      await _jsonResponse(request.response, HttpStatus.forbidden, {
        'error': 'invalid_signature',
      });
      return;
    }
    final requestId = const Uuid().v4();
    final code = crypto.confirmationCode(
      sessionId: sessionId,
      requestId: requestId,
      token: token,
      hostPublicKey: local.peer.publicKey,
      clientPublicKey: payload.peer.publicKey,
    );
    final incoming = PairingIncomingRequest(
      requestId: requestId,
      peer: payload.peer,
      confirmationCode: code,
      receivedAt: DateTime.now(),
      state: PairingRequestState.pending,
    );
    _pending[requestId] = _PendingHostRequest(request: incoming);
    _requestController.add(incoming);
    await _jsonResponse(request.response, HttpStatus.accepted, {
      'requestId': requestId,
      'confirmationCode': code,
      'expiresAt': expiresAt.toUtc().toIso8601String(),
    });
  }

  Future<void> _handleStatus(HttpResponse response, String requestId) async {
    final pending = _pending[requestId];
    if (pending == null) {
      await _jsonResponse(response, HttpStatus.notFound, {
        'error': 'request_not_found',
      });
      return;
    }
    final state = pending.request.state;
    if (state == PairingRequestState.pending) {
      await _jsonResponse(response, HttpStatus.ok, {'status': 'pending'});
      return;
    }
    if (state == PairingRequestState.denied) {
      await _jsonResponse(response, HttpStatus.ok, {'status': 'denied'});
      return;
    }
    await _jsonResponse(response, HttpStatus.ok, {
      'status': 'approved',
      'approval': pending.approval!.toJson(),
    });
  }

  Future<void> _handleComplete(HttpResponse response, String requestId) async {
    final pending = _pending[requestId];
    if (pending == null || pending.approval == null) {
      await _jsonResponse(response, HttpStatus.notFound, {
        'error': 'request_not_found',
      });
      return;
    }
    await _onTrust(pending.request.peer);
    pending.request = pending.request.copyWith(
      state: PairingRequestState.completed,
    );
    _requestController.add(pending.request);
    await _jsonResponse(response, HttpStatus.ok, {'status': 'completed'});
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _expiryTimer?.cancel();
    await _subscription?.cancel();
    await _server.close(force: true);
    await _requestController.close();
  }
}

class PairingClientSession {
  PairingClientSession._({
    required this.offer,
    required this.local,
    required this.crypto,
    required this.pending,
    required HttpClient client,
  }) : _client = client;

  static Future<PairingClientSession> start({
    required PairingOffer offer,
    required LocalPairingIdentity local,
    required PairingCrypto crypto,
    bool localNetworkOnly = true,
  }) async {
    if (offer.isExpired) {
      throw StateError('Срок действия QR-кода истёк.');
    }
    if (localNetworkOnly && !isLocalOnlyIpv4(offer.host)) {
      throw StateError(
        'Адрес устройства не относится к разрешённой локальной сети.',
      );
    }
    final unsigned = PairingRequestPayload(
      sessionId: offer.sessionId,
      token: offer.token,
      nonce: crypto.randomToken(16),
      peer: local.peer,
      signature: '',
    );
    final signature = await crypto.sign(
      unsigned.signingPayload,
      local.keyMaterial,
    );
    final payload = PairingRequestPayload(
      sessionId: offer.sessionId,
      token: offer.token,
      nonce: unsigned.nonce,
      peer: local.peer,
      signature: signature,
    );
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final response = await _postJson(
        client,
        offer,
        '/v1/pair/request',
        payload.toJson(),
      );
      if (response.statusCode != HttpStatus.accepted) {
        throw StateError(_friendlyNetworkError(response.json));
      }
      return PairingClientSession._(
        offer: offer,
        local: local,
        crypto: crypto,
        pending: PairingPendingResponse.fromJson(response.json),
        client: client,
      );
    } on Object {
      client.close(force: true);
      rethrow;
    }
  }

  final PairingOffer offer;
  final LocalPairingIdentity local;
  final PairingCrypto crypto;
  final PairingPendingResponse pending;
  final HttpClient _client;
  bool _closed = false;

  Future<PairingClientResult> waitForApproval() async {
    while (!_closed && DateTime.now().isBefore(pending.expiresAt)) {
      final response = await _getJson(
        _client,
        offer,
        '/v1/pair/status/${pending.requestId}',
      );
      if (response.statusCode != HttpStatus.ok) {
        throw StateError(_friendlyNetworkError(response.json));
      }
      final status = response.json['status'];
      if (status == 'denied') {
        throw StateError('Подключение отклонено на другом устройстве.');
      }
      if (status == 'approved') {
        final approval = PairingApprovalPayload.fromJson(
          Map<String, dynamic>.from(response.json['approval']! as Map),
        );
        await _verifyApproval(approval);
        return PairingClientResult(
          hostPeer: approval.hostPeer,
          confirmationCode: pending.confirmationCode,
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    throw StateError('Срок подтверждения сопряжения истёк.');
  }

  Future<void> _verifyApproval(PairingApprovalPayload approval) async {
    if (approval.sessionId != offer.sessionId ||
        approval.requestId != pending.requestId ||
        approval.confirmationCode != pending.confirmationCode ||
        approval.clientDeviceId != local.peer.deviceId ||
        approval.hostPeer.deviceId != offer.hostPeer.deviceId ||
        approval.hostPeer.publicKey != offer.hostPeer.publicKey) {
      throw StateError('Ответ другого устройства не прошёл проверку.');
    }
    final valid = await crypto.verify(
      message: approval.signingPayload,
      signatureBase64: approval.signature,
      publicKeyBase64: offer.hostPeer.publicKey,
    );
    if (!valid) {
      throw StateError('Криптографическая подпись другого устройства неверна.');
    }
  }

  Future<void> complete() async {
    if (_closed) {
      return;
    }
    final response = await _postJson(
      _client,
      offer,
      '/v1/pair/complete/${pending.requestId}',
      const {},
    );
    if (response.statusCode != HttpStatus.ok) {
      throw StateError(_friendlyNetworkError(response.json));
    }
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _client.close(force: true);
  }
}

class _PendingHostRequest {
  _PendingHostRequest({required this.request});

  PairingIncomingRequest request;
  PairingApprovalPayload? approval;
}

class _JsonHttpResponse {
  const _JsonHttpResponse(this.statusCode, this.json);

  final int statusCode;
  final Map<String, dynamic> json;
}

Future<_JsonHttpResponse> _postJson(
  HttpClient client,
  PairingOffer offer,
  String path,
  Map<String, dynamic> body,
) async {
  final request = await client.postUrl(
    Uri.parse('http://${offer.host}:${offer.port}$path'),
  );
  request.headers.contentType = ContentType.json;
  addJsonBody(request, body);
  return _readHttpResponse(await request.close());
}

Future<_JsonHttpResponse> _getJson(
  HttpClient client,
  PairingOffer offer,
  String path,
) async {
  final request = await client.getUrl(
    Uri.parse('http://${offer.host}:${offer.port}$path'),
  );
  return _readHttpResponse(await request.close());
}

Future<_JsonHttpResponse> _readHttpResponse(HttpClientResponse response) async {
  final json = await readBoundedJsonResponse(
    response,
    maxBytes: lanHandshakeMaxBytes,
  );
  return _JsonHttpResponse(response.statusCode, json);
}

Future<Map<String, dynamic>> _readJson(HttpRequest request) async {
  return readBoundedJson(request, maxBytes: lanHandshakeMaxBytes);
}

Future<void> _jsonResponse(
  HttpResponse response,
  int statusCode,
  Map<String, dynamic> body,
) async {
  _applyCors(response);
  await writeJsonResponse(response, statusCode, body);
}

void _applyCors(HttpResponse response) {
  response.headers
    ..set('Access-Control-Allow-Origin', '*')
    ..set('Access-Control-Allow-Headers', 'Content-Type')
    ..set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
}

String _friendlyNetworkError(Map<String, dynamic> json) {
  return switch (json['error']) {
    'pairing_expired' => 'Срок действия QR-кода истёк.',
    'invalid_session' => 'QR-код больше не действителен.',
    'same_device' => 'Нельзя подключить устройство к самому себе.',
    'invalid_signature' => 'Криптографическая проверка устройства не пройдена.',
    'request_not_found' => 'Запрос сопряжения больше не существует.',
    final Object? value when value != null => '$value',
    _ => 'Не удалось подключиться к устройству.',
  };
}
