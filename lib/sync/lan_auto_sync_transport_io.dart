import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import 'lan_auto_sync_models.dart';
import 'lan_sync_models.dart';
import 'lan_sync_transport.dart';
import 'pairing_crypto.dart';
import 'pairing_models.dart';

typedef TrustedPeerLookup = Future<PairingPeer?> Function(String deviceId);
typedef StartLanSyncHost =
    Future<LanSyncHostSession> Function(String peerDeviceId);

class LanAutoSyncNode {
  LanAutoSyncNode._({
    required HttpServer server,
    required RawDatagramSocket discoverySocket,
    required this.local,
    required this.crypto,
    required TrustedPeerLookup lookupTrustedPeer,
    required StartLanSyncHost startHost,
  }) : _server = server,
       _discoverySocket = discoverySocket,
       _lookupTrustedPeer = lookupTrustedPeer,
       _startHost = startHost;

  static Future<LanAutoSyncNode> start({
    required LocalPairingIdentity local,
    required PairingCrypto crypto,
    required TrustedPeerLookup lookupTrustedPeer,
    required StartLanSyncHost startHost,
  }) async {
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    RawDatagramSocket discoverySocket;
    try {
      discoverySocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        lanDiscoveryPort,
        reuseAddress: true,
      );
      discoverySocket.broadcastEnabled = true;
    } on Object {
      await server.close(force: true);
      rethrow;
    }

    final node = LanAutoSyncNode._(
      server: server,
      discoverySocket: discoverySocket,
      local: local,
      crypto: crypto,
      lookupTrustedPeer: lookupTrustedPeer,
      startHost: startHost,
    );
    node._httpSubscription = server.listen(node._handleHttpRequest);
    node._discoverySubscription = discoverySocket.listen(
      node._handleDiscoveryEvent,
    );
    node._announcementTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => unawaited(node.announceNow()),
    );
    await node.announceNow();
    return node;
  }

  final HttpServer _server;
  final RawDatagramSocket _discoverySocket;
  final LocalPairingIdentity local;
  final PairingCrypto crypto;
  final TrustedPeerLookup _lookupTrustedPeer;
  final StartLanSyncHost _startHost;
  final StreamController<LanDiscoveredPeer> _peerController =
      StreamController<LanDiscoveredPeer>.broadcast();
  final StreamController<LanSyncReport> _reportController =
      StreamController<LanSyncReport>.broadcast();
  final Set<LanSyncHostSession> _activeSessions = {};
  final Map<String, DateTime> _acceptedRequests = {};

  StreamSubscription<HttpRequest>? _httpSubscription;
  StreamSubscription<RawSocketEvent>? _discoverySubscription;
  Timer? _announcementTimer;
  bool _closed = false;
  bool _announcing = false;

  Stream<LanDiscoveredPeer> get peers => _peerController.stream;
  Stream<LanSyncReport> get reports => _reportController.stream;
  int get port => _server.port;

  Future<void> announceNow() async {
    if (_closed || _announcing) {
      return;
    }
    _announcing = true;
    try {
      final unsigned = LanDiscoveryAnnouncement(
        peer: local.peer,
        httpPort: _server.port,
        sentAt: DateTime.now(),
        nonce: crypto.randomToken(),
        signature: '',
      );
      final signature = await crypto.sign(
        unsigned.signingPayload,
        local.keyMaterial,
      );
      final announcement = LanDiscoveryAnnouncement(
        peer: unsigned.peer,
        httpPort: unsigned.httpPort,
        sentAt: unsigned.sentAt,
        nonce: unsigned.nonce,
        signature: signature,
      );
      final bytes = utf8.encode(jsonEncode(announcement.toJson()));
      final targets = await _broadcastTargets();
      for (final target in targets) {
        try {
          _discoverySocket.send(bytes, target, lanDiscoveryPort);
        } on Object {
          // A VPN or a disabled adapter may reject one target. Other adapters
          // should still receive their announcements.
        }
      }
    } finally {
      _announcing = false;
    }
  }

  void _handleDiscoveryEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read || _closed) {
      return;
    }
    Datagram? datagram;
    while ((datagram = _discoverySocket.receive()) != null) {
      final current = datagram!;
      unawaited(_acceptAnnouncement(current));
    }
  }

  Future<void> _acceptAnnouncement(Datagram datagram) async {
    try {
      final decoded = jsonDecode(utf8.decode(datagram.data));
      if (decoded is! Map) {
        return;
      }
      final announcement = LanDiscoveryAnnouncement.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (announcement.peer.deviceId == local.peer.deviceId ||
          announcement.httpPort <= 0 ||
          announcement.httpPort > 65535 ||
          !_isFresh(announcement.sentAt, const Duration(minutes: 2))) {
        return;
      }
      final trusted = await _lookupTrustedPeer(announcement.peer.deviceId);
      if (trusted == null || trusted.publicKey != announcement.peer.publicKey) {
        return;
      }
      final valid = await crypto.verify(
        message: announcement.signingPayload,
        signatureBase64: announcement.signature,
        publicKeyBase64: trusted.publicKey,
      );
      if (!valid || _closed) {
        return;
      }
      _peerController.add(
        LanDiscoveredPeer(
          peer: announcement.peer,
          host: datagram.address.address,
          port: announcement.httpPort,
          lastSeenAt: DateTime.now(),
        ),
      );
    } on Object {
      // Discovery packets are untrusted network input and are ignored when
      // malformed or signed by an unknown device.
    }
  }

  Future<void> _handleHttpRequest(HttpRequest request) async {
    try {
      _applyCors(request.response);
      if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        return;
      }
      if (request.method != 'POST' ||
          request.uri.path != '/v1/auto-sync/offer') {
        await _jsonResponse(request.response, HttpStatus.notFound, {
          'error': 'not_found',
        });
        return;
      }

      final payload = LanAutoSyncOfferRequest.fromJson(
        await _readJson(request),
      );
      if (payload.targetDeviceId != local.peer.deviceId ||
          !_isFresh(payload.sentAt, const Duration(minutes: 2))) {
        await _jsonResponse(request.response, HttpStatus.forbidden, {
          'error': 'invalid_target_or_time',
        });
        return;
      }
      _pruneAcceptedRequests();
      if (_acceptedRequests.containsKey(payload.requestId)) {
        await _jsonResponse(request.response, HttpStatus.conflict, {
          'error': 'replayed_request',
        });
        return;
      }
      final trusted = await _lookupTrustedPeer(payload.peer.deviceId);
      if (trusted == null || trusted.publicKey != payload.peer.publicKey) {
        await _jsonResponse(request.response, HttpStatus.forbidden, {
          'error': 'untrusted_device',
        });
        return;
      }
      final valid = await crypto.verify(
        message: payload.signingPayload,
        signatureBase64: payload.signature,
        publicKeyBase64: trusted.publicKey,
      );
      if (!valid) {
        await _jsonResponse(request.response, HttpStatus.forbidden, {
          'error': 'invalid_signature',
        });
        return;
      }

      final session = await _startHost(payload.peer.deviceId);
      _activeSessions.add(session);
      unawaited(
        session.reports.first
            .then((report) async {
              if (!_closed) {
                _reportController.add(report);
              }
              await Future<void>.delayed(const Duration(milliseconds: 500));
              await _closeSession(session);
            })
            .catchError((Object _) => _closeSession(session)),
      );
      final connectionAddress = request.connectionInfo?.localAddress.address;
      final address =
          connectionAddress != null && connectionAddress != '0.0.0.0'
              ? connectionAddress
              : session.addresses.first;
      final encodedOffer = session.offerFor(address).encode();
      _acceptedRequests[payload.requestId] = DateTime.now();

      final unsigned = LanAutoSyncOfferResponse(
        requestId: payload.requestId,
        sentAt: DateTime.now(),
        peer: local.peer,
        encodedOffer: encodedOffer,
        signature: '',
      );
      final signature = await crypto.sign(
        unsigned.signingPayload,
        local.keyMaterial,
      );
      final response = LanAutoSyncOfferResponse(
        requestId: unsigned.requestId,
        sentAt: unsigned.sentAt,
        peer: unsigned.peer,
        encodedOffer: unsigned.encodedOffer,
        signature: signature,
      );
      await _jsonResponse(request.response, HttpStatus.ok, response.toJson());
    } on Object catch (error) {
      try {
        await _jsonResponse(request.response, HttpStatus.badRequest, {
          'error': error.toString(),
        });
      } on Object {
        try {
          await request.response.close();
        } on Object {
          // The remote device may have disconnected.
        }
      }
    }
  }

  Future<String> requestOffer(LanDiscoveredPeer discovered) async {
    if (_closed) {
      throw StateError('Локальный сервис синхронизации остановлен.');
    }
    if (!discovered.isOnlineAt(DateTime.now())) {
      throw StateError(
        'Связанное устройство больше не видно в локальной сети.',
      );
    }
    final requestId = const Uuid().v4();
    final unsigned = LanAutoSyncOfferRequest(
      requestId: requestId,
      targetDeviceId: discovered.peer.deviceId,
      sentAt: DateTime.now(),
      peer: local.peer,
      signature: '',
    );
    final signature = await crypto.sign(
      unsigned.signingPayload,
      local.keyMaterial,
    );
    final payload = LanAutoSyncOfferRequest(
      requestId: unsigned.requestId,
      targetDeviceId: unsigned.targetDeviceId,
      sentAt: unsigned.sentAt,
      peer: unsigned.peer,
      signature: signature,
    );

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final uri = Uri.parse(
        'http://${discovered.host}:${discovered.port}/v1/auto-sync/offer',
      );
      final request = await client
          .postUrl(uri)
          .timeout(const Duration(seconds: 6));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload.toJson()));
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      final raw = await utf8.decoder.bind(response).join();
      final decoded = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw);
      final json =
          decoded is Map
              ? Map<String, dynamic>.from(decoded)
              : <String, dynamic>{};
      if (response.statusCode != HttpStatus.ok) {
        throw StateError(_friendlyOfferError(json));
      }
      final offerResponse = LanAutoSyncOfferResponse.fromJson(json);
      if (offerResponse.requestId != requestId ||
          offerResponse.peer.deviceId != discovered.peer.deviceId ||
          offerResponse.peer.publicKey != discovered.peer.publicKey ||
          !_isFresh(offerResponse.sentAt, const Duration(minutes: 2))) {
        throw StateError('Ответ устройства не прошёл проверку.');
      }
      final valid = await crypto.verify(
        message: offerResponse.signingPayload,
        signatureBase64: offerResponse.signature,
        publicKeyBase64: discovered.peer.publicKey,
      );
      if (!valid) {
        throw StateError('Криптографическая подпись устройства неверна.');
      }
      return offerResponse.encodedOffer;
    } on SocketException catch (error) {
      throw StateError(
        'Устройство найдено, но подключение к ${discovered.endpoint} не '
        'установлено. Проверь VPN и брандмауэр. (${error.message})',
      );
    } on TimeoutException {
      throw StateError(
        'Устройство найдено, но не ответило вовремя. Проверь VPN и доступ к '
        'локальной сети.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _closeSession(LanSyncHostSession session) async {
    _activeSessions.remove(session);
    await session.close();
  }

  void _pruneAcceptedRequests() {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 5));
    _acceptedRequests.removeWhere(
      (_, acceptedAt) => acceptedAt.isBefore(cutoff),
    );
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _announcementTimer?.cancel();
    await _httpSubscription?.cancel();
    await _discoverySubscription?.cancel();
    _discoverySocket.close();
    await _server.close(force: true);
    final sessions = _activeSessions.toList(growable: false);
    _activeSessions.clear();
    for (final session in sessions) {
      await session.close();
    }
    await _peerController.close();
    await _reportController.close();
  }
}

bool _isFresh(DateTime value, Duration tolerance) {
  final difference = DateTime.now().difference(value).abs();
  return difference <= tolerance;
}

Future<Set<InternetAddress>> _broadcastTargets() async {
  final targets = <InternetAddress>{InternetAddress('255.255.255.255')};
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
    includeLinkLocal: false,
  );
  for (final interface in interfaces) {
    if (_isVirtualInterface(interface.name)) {
      continue;
    }
    for (final address in interface.addresses) {
      final parts = address.address.split('.');
      if (parts.length != 4 || !_isPrivateIpv4(parts)) {
        continue;
      }
      targets.add(InternetAddress('${parts[0]}.${parts[1]}.${parts[2]}.255'));
    }
  }
  return targets;
}

bool _isVirtualInterface(String name) {
  final normalized = name.toLowerCase();
  const markers = <String>[
    'vpn',
    'tun',
    'tap',
    'wireguard',
    'wsl',
    'vethernet',
    'virtualbox',
    'vmware',
    'hyper-v',
    'docker',
    'tailscale',
    'zerotier',
    'hiddify',
  ];
  return markers.any(normalized.contains);
}

bool _isPrivateIpv4(List<String> parts) {
  final first = int.tryParse(parts[0]);
  final second = int.tryParse(parts[1]);
  if (first == null || second == null) {
    return false;
  }
  return first == 10 ||
      (first == 192 && second == 168) ||
      (first == 172 && second >= 16 && second <= 31);
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

String _friendlyOfferError(Map<String, dynamic> json) {
  final raw = '${json['error'] ?? ''}';
  if (raw.contains('untrusted_device')) {
    return 'Удалённое устройство больше не считает Chronicle доверенным.';
  }
  if (raw.contains('invalid_signature')) {
    return 'Криптографическая проверка устройства не пройдена.';
  }
  if (raw.contains('replayed_request')) {
    return 'Запрос синхронизации уже использован. Повтори попытку.';
  }
  if (raw.contains('invalid_target_or_time')) {
    return 'На устройствах сильно различается время или запрос адресован не ему.';
  }
  return raw.isEmpty
      ? 'Не удалось получить защищённый сеанс синхронизации.'
      : raw;
}
