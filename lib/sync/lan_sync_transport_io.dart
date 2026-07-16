import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import 'lan_sync_models.dart';
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
  LanSyncHostSession._({
    required HttpServer server,
    required this.addresses,
    required this.sessionId,
    required this.token,
    required this.expiresAt,
    required this.local,
    required this.targetPeer,
    required this.crypto,
    required BuildOutgoingBatch buildOutgoing,
    required ApplyIncomingChanges applyIncoming,
    required LoadPeerCursor loadCursor,
    required SavePeerCursor saveCursor,
    required MarkPeerSyncSuccess markSuccess,
    RemoteAppliedCallback? onRemoteApplied,
  }) : _server = server,
       _buildOutgoing = buildOutgoing,
       _applyIncoming = applyIncoming,
       _loadCursor = loadCursor,
       _saveCursor = saveCursor,
       _markSuccess = markSuccess,
       _onRemoteApplied = onRemoteApplied;

  static Future<LanSyncHostSession> start({
    required LocalPairingIdentity local,
    required PairingPeer targetPeer,
    required PairingCrypto crypto,
    required BuildOutgoingBatch buildOutgoing,
    required ApplyIncomingChanges applyIncoming,
    required LoadPeerCursor loadCursor,
    required SavePeerCursor saveCursor,
    required MarkPeerSyncSuccess markSuccess,
    RemoteAppliedCallback? onRemoteApplied,
  }) async {
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    final addresses = await _localIpv4Addresses();
    if (addresses.isEmpty) {
      await server.close(force: true);
      throw StateError(
        'Не найден локальный IPv4-адрес. Подключи устройство к Wi-Fi или LAN.',
      );
    }
    final session = LanSyncHostSession._(
      server: server,
      addresses: addresses,
      sessionId: const Uuid().v4(),
      token: crypto.randomToken(),
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      local: local,
      targetPeer: targetPeer,
      crypto: crypto,
      buildOutgoing: buildOutgoing,
      applyIncoming: applyIncoming,
      loadCursor: loadCursor,
      saveCursor: saveCursor,
      markSuccess: markSuccess,
      onRemoteApplied: onRemoteApplied,
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
  final PairingPeer targetPeer;
  final PairingCrypto crypto;
  final BuildOutgoingBatch _buildOutgoing;
  final ApplyIncomingChanges _applyIncoming;
  final LoadPeerCursor _loadCursor;
  final SavePeerCursor _saveCursor;
  final MarkPeerSyncSuccess _markSuccess;
  final RemoteAppliedCallback? _onRemoteApplied;
  final StreamController<LanSyncReport> _reportController =
      StreamController<LanSyncReport>.broadcast();
  final Map<String, _PendingSyncRound> _pendingRounds = {};

  StreamSubscription<HttpRequest>? _subscription;
  Timer? _expiryTimer;
  bool _closed = false;

  Stream<LanSyncReport> get reports => _reportController.stream;

  LanSyncOffer offerFor(String address) => LanSyncOffer(
    host: address,
    port: _server.port,
    sessionId: sessionId,
    token: token,
    expiresAt: expiresAt,
    hostPeer: local.peer,
    targetDeviceId: targetPeer.deviceId,
  );

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      _applyCors(request.response);
      if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        return;
      }
      if (DateTime.now().isAfter(expiresAt)) {
        await _jsonResponse(request.response, HttpStatus.gone, {
          'error': 'sync_expired',
        });
        return;
      }
      if (request.method == 'POST' && request.uri.path == '/v1/sync/exchange') {
        await _handleExchange(request);
        return;
      }
      if (request.method == 'POST' && request.uri.path == '/v1/sync/ack') {
        await _handleAck(request);
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

  Future<void> _handleExchange(HttpRequest request) async {
    final payload = LanSyncExchangeRequest.fromJson(await _readJson(request));
    _validateSession(payload.sessionId, payload.token);
    _validatePeer(payload.peer);
    final valid = await crypto.verify(
      message: payload.signingPayload,
      signatureBase64: payload.signature,
      publicKeyBase64: targetPeer.publicKey,
    );
    if (!valid) {
      await _jsonResponse(request.response, HttpStatus.forbidden, {
        'error': 'invalid_signature',
      });
      return;
    }

    final startedAt = DateTime.now();
    final applied = await _applyIncoming(payload.batch.changes);
    if (applied.insertedCount > 0 && _onRemoteApplied != null) {
      try {
        await _onRemoteApplied(applied);
      } on Object {
        // UI refresh failures must not invalidate an already applied batch.
      }
    }
    final cursor = await _loadCursor(targetPeer.deviceId);
    final outgoing = await _buildOutgoing(
      targetPeer.deviceId,
      cursor.lastSentSequence,
      1000,
    );
    final unsigned = LanSyncExchangeResponse(
      sessionId: sessionId,
      roundId: payload.roundId,
      hostPeer: local.peer,
      batch: outgoing,
      remoteApplyResult: applied,
      signature: '',
    );
    final signature = await crypto.sign(
      unsigned.signingPayload,
      local.keyMaterial,
    );
    final response = LanSyncExchangeResponse(
      sessionId: sessionId,
      roundId: payload.roundId,
      hostPeer: local.peer,
      batch: outgoing,
      remoteApplyResult: applied,
      signature: signature,
    );
    _pendingRounds[payload.roundId] = _PendingSyncRound(
      request: payload,
      response: response,
      previousCursor: cursor,
      startedAt: startedAt,
    );
    await _jsonResponse(request.response, HttpStatus.ok, response.toJson());
  }

  Future<void> _handleAck(HttpRequest request) async {
    final ack = LanSyncAck.fromJson(await _readJson(request));
    if (ack.sessionId != sessionId ||
        ack.clientDeviceId != targetPeer.deviceId) {
      await _jsonResponse(request.response, HttpStatus.forbidden, {
        'error': 'invalid_session',
      });
      return;
    }
    final pending = _pendingRounds[ack.roundId];
    if (pending == null) {
      await _jsonResponse(request.response, HttpStatus.notFound, {
        'error': 'round_not_found',
      });
      return;
    }
    if (ack.receivedThroughSequence != pending.response.batch.throughSequence) {
      await _jsonResponse(request.response, HttpStatus.conflict, {
        'error': 'invalid_ack',
      });
      return;
    }
    final valid = await crypto.verify(
      message: ack.signingPayload,
      signatureBase64: ack.signature,
      publicKeyBase64: targetPeer.publicKey,
    );
    if (!valid) {
      await _jsonResponse(request.response, HttpStatus.forbidden, {
        'error': 'invalid_signature',
      });
      return;
    }

    final completedAt = DateTime.now();
    await _saveCursor(
      SyncCursor(
        peerDeviceId: targetPeer.deviceId,
        lastSentSequence: pending.response.batch.throughSequence,
        lastReceivedChangeId:
            pending.request.batch.changes.isEmpty
                ? pending.previousCursor.lastReceivedChangeId
                : pending.request.batch.changes.last.changeId,
        lastSuccessAt: completedAt,
      ),
    );
    await _markSuccess(pending.request.peer, completedAt);

    final report = LanSyncReport(
      peer: pending.request.peer,
      startedAt: pending.startedAt,
      completedAt: completedAt,
      roundCount: 1,
      sentCount: pending.response.batch.changes.length,
      receivedCount: pending.request.batch.changes.length,
      appliedCount: pending.response.remoteApplyResult.appliedCount,
      duplicateCount: pending.response.remoteApplyResult.duplicateCount,
      staleCount: pending.response.remoteApplyResult.staleCount,
      unsupportedCount: pending.response.remoteApplyResult.unsupportedCount,
      hasMore: pending.response.batch.hasMore || pending.request.batch.hasMore,
    );
    _pendingRounds.remove(ack.roundId);
    _reportController.add(report);
    await _jsonResponse(request.response, HttpStatus.ok, {
      'status': 'acknowledged',
    });
  }

  void _validateSession(String receivedSessionId, String receivedToken) {
    if (receivedSessionId != sessionId || receivedToken != token) {
      throw StateError('invalid_session');
    }
  }

  void _validatePeer(PairingPeer peer) {
    if (peer.deviceId != targetPeer.deviceId ||
        peer.publicKey != targetPeer.publicKey) {
      throw StateError('untrusted_device');
    }
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _expiryTimer?.cancel();
    await _subscription?.cancel();
    await _server.close(force: true);
    await _reportController.close();
  }
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
    RemoteAppliedCallback? onRemoteApplied,
  }) async {
    if (offer.isExpired) {
      throw StateError('Срок действия кода синхронизации истёк.');
    }
    if (offer.targetDeviceId != local.peer.deviceId) {
      throw StateError('Этот код предназначен для другого устройства.');
    }
    if (offer.hostPeer.deviceId != trustedHost.deviceId ||
        offer.hostPeer.publicKey != trustedHost.publicKey) {
      throw StateError('Устройство из кода не является доверенным.');
    }

    final startedAt = DateTime.now();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    var roundCount = 0;
    var sentCount = 0;
    var receivedCount = 0;
    var appliedCount = 0;
    var duplicateCount = 0;
    var staleCount = 0;
    var unsupportedCount = 0;
    var hasMore = false;

    try {
      do {
        roundCount++;
        if (roundCount > 20) {
          throw StateError(
            'Слишком много пакетов синхронизации. Повтори обмен ещё раз.',
          );
        }
        final cursor = await loadCursor(trustedHost.deviceId);
        final outgoing = await buildOutgoing(
          trustedHost.deviceId,
          cursor.lastSentSequence,
          1000,
        );
        final roundId = const Uuid().v4();
        final unsigned = LanSyncExchangeRequest(
          sessionId: offer.sessionId,
          token: offer.token,
          roundId: roundId,
          peer: local.peer,
          batch: outgoing,
          signature: '',
        );
        final requestSignature = await crypto.sign(
          unsigned.signingPayload,
          local.keyMaterial,
        );
        final request = LanSyncExchangeRequest(
          sessionId: offer.sessionId,
          token: offer.token,
          roundId: roundId,
          peer: local.peer,
          batch: outgoing,
          signature: requestSignature,
        );
        final rawResponse = await _postJson(
          client,
          offer,
          '/v1/sync/exchange',
          request.toJson(),
        );
        if (rawResponse.statusCode != HttpStatus.ok) {
          throw StateError(_friendlySyncError(rawResponse.json));
        }
        final response = LanSyncExchangeResponse.fromJson(rawResponse.json);
        await _verifyResponse(
          response: response,
          offer: offer,
          roundId: roundId,
          trustedHost: trustedHost,
          crypto: crypto,
        );
        final applied = await applyIncoming(response.batch.changes);
        if (applied.insertedCount > 0 && onRemoteApplied != null) {
          try {
            await onRemoteApplied(applied);
          } on Object {
            // UI refresh failures must not invalidate an already applied batch.
          }
        }

        final completedAt = DateTime.now();
        await saveCursor(
          SyncCursor(
            peerDeviceId: trustedHost.deviceId,
            lastSentSequence: outgoing.throughSequence,
            lastReceivedChangeId:
                response.batch.changes.isEmpty
                    ? cursor.lastReceivedChangeId
                    : response.batch.changes.last.changeId,
            lastSuccessAt: completedAt,
          ),
        );
        await markSuccess(response.hostPeer, completedAt);

        final unsignedAck = LanSyncAck(
          sessionId: offer.sessionId,
          roundId: roundId,
          clientDeviceId: local.peer.deviceId,
          receivedThroughSequence: response.batch.throughSequence,
          signature: '',
        );
        final ackSignature = await crypto.sign(
          unsignedAck.signingPayload,
          local.keyMaterial,
        );
        final ack = LanSyncAck(
          sessionId: offer.sessionId,
          roundId: roundId,
          clientDeviceId: local.peer.deviceId,
          receivedThroughSequence: response.batch.throughSequence,
          signature: ackSignature,
        );
        final ackResponse = await _postJson(
          client,
          offer,
          '/v1/sync/ack',
          ack.toJson(),
        );
        if (ackResponse.statusCode != HttpStatus.ok) {
          throw StateError(_friendlySyncError(ackResponse.json));
        }

        sentCount += outgoing.changes.length;
        receivedCount += response.batch.changes.length;
        appliedCount += applied.appliedCount;
        duplicateCount += applied.duplicateCount;
        staleCount += applied.staleCount;
        unsupportedCount += applied.unsupportedCount;
        hasMore = outgoing.hasMore || response.batch.hasMore;
      } while (hasMore);
    } finally {
      client.close(force: true);
    }

    return LanSyncReport(
      peer: trustedHost,
      startedAt: startedAt,
      completedAt: DateTime.now(),
      roundCount: roundCount,
      sentCount: sentCount,
      receivedCount: receivedCount,
      appliedCount: appliedCount,
      duplicateCount: duplicateCount,
      staleCount: staleCount,
      unsupportedCount: unsupportedCount,
      hasMore: hasMore,
    );
  }

  static Future<void> _verifyResponse({
    required LanSyncExchangeResponse response,
    required LanSyncOffer offer,
    required String roundId,
    required PairingPeer trustedHost,
    required PairingCrypto crypto,
  }) async {
    if (response.sessionId != offer.sessionId ||
        response.roundId != roundId ||
        response.hostPeer.deviceId != trustedHost.deviceId ||
        response.hostPeer.publicKey != trustedHost.publicKey) {
      throw StateError('Ответ устройства не прошёл проверку.');
    }
    final valid = await crypto.verify(
      message: response.signingPayload,
      signatureBase64: response.signature,
      publicKeyBase64: trustedHost.publicKey,
    );
    if (!valid) {
      throw StateError('Криптографическая подпись ответа неверна.');
    }
  }
}

class _PendingSyncRound {
  const _PendingSyncRound({
    required this.request,
    required this.response,
    required this.previousCursor,
    required this.startedAt,
  });

  final LanSyncExchangeRequest request;
  final LanSyncExchangeResponse response;
  final SyncCursor previousCursor;
  final DateTime startedAt;
}

class _JsonHttpResponse {
  const _JsonHttpResponse(this.statusCode, this.json);

  final int statusCode;
  final Map<String, dynamic> json;
}

Future<_JsonHttpResponse> _postJson(
  HttpClient client,
  LanSyncOffer offer,
  String path,
  Map<String, dynamic> body,
) async {
  final request = await client.postUrl(
    Uri.parse('http://${offer.host}:${offer.port}$path'),
  );
  request.headers.contentType = ContentType.json;
  request.write(jsonEncode(body));
  return _readHttpResponse(await request.close());
}

Future<_JsonHttpResponse> _readHttpResponse(HttpClientResponse response) async {
  final raw = await utf8.decoder.bind(response).join();
  Map<String, dynamic> json = {};
  if (raw.isNotEmpty) {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      json = Map<String, dynamic>.from(decoded);
    }
  }
  return _JsonHttpResponse(response.statusCode, json);
}

Future<Map<String, dynamic>> _readJson(HttpRequest request) async {
  final raw = await utf8.decoder.bind(request).join();
  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    throw const FormatException('Expected a JSON object.');
  }
  return Map<String, dynamic>.from(decoded);
}

Future<void> _jsonResponse(
  HttpResponse response,
  int statusCode,
  Map<String, dynamic> body,
) async {
  _applyCors(response);
  response.statusCode = statusCode;
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(body));
  await response.close();
}

void _applyCors(HttpResponse response) {
  response.headers
    ..set('Access-Control-Allow-Origin', '*')
    ..set('Access-Control-Allow-Headers', 'Content-Type')
    ..set('Access-Control-Allow-Methods', 'POST, OPTIONS');
}

String _friendlySyncError(Map<String, dynamic> json) {
  final raw = '${json['error'] ?? ''}';
  if (raw.contains('sync_expired')) {
    return 'Срок действия кода синхронизации истёк.';
  }
  if (raw.contains('invalid_session')) {
    return 'Код синхронизации больше не действителен.';
  }
  if (raw.contains('untrusted_device')) {
    return 'Устройство не входит в список доверенных.';
  }
  if (raw.contains('invalid_signature')) {
    return 'Криптографическая проверка устройства не пройдена.';
  }
  if (raw.contains('round_not_found') || raw.contains('invalid_ack')) {
    return 'Подтверждение пакета синхронизации не принято.';
  }
  return raw.isEmpty ? 'Не удалось синхронизировать устройства.' : raw;
}

Future<List<String>> _localIpv4Addresses() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
    includeLinkLocal: false,
  );
  final addresses = <String>{};
  for (final interface in interfaces) {
    for (final address in interface.addresses) {
      if (!address.isLoopback && address.type == InternetAddressType.IPv4) {
        addresses.add(address.address);
      }
    }
  }
  final sorted =
      addresses.toList()..sort((left, right) {
        final rank = _addressRank(left).compareTo(_addressRank(right));
        return rank != 0 ? rank : left.compareTo(right);
      });
  return sorted;
}

int _addressRank(String value) {
  if (value.startsWith('192.168.')) {
    return 0;
  }
  if (value.startsWith('10.')) {
    return 1;
  }
  final parts = value.split('.');
  if (parts.length == 4 && parts.first == '172') {
    final second = int.tryParse(parts[1]) ?? 0;
    if (second >= 16 && second <= 31) {
      return 2;
    }
  }
  return 3;
}
