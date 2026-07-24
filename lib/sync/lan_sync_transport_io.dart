import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import 'attachment_sync_models.dart';
import 'bounded_http_io.dart';
import 'lan_address_selector.dart';
import 'lan_secure_channel.dart';
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
  LanSyncHostSession._({
    required HttpServer server,
    required this.addresses,
    required this.sessionId,
    required this.expiresAt,
    required this.local,
    required this.targetPeer,
    required this.crypto,
    required LanEphemeralKeyPair hostEphemeral,
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
    RemoteAppliedCallback? onRemoteApplied,
  }) : _server = server,
       _buildOutgoing = buildOutgoing,
       _applyIncoming = applyIncoming,
       _loadCursor = loadCursor,
       _saveCursor = saveCursor,
       _markSuccess = markSuccess,
       _buildAttachmentManifest = buildAttachmentManifest,
       _readAttachment = readAttachment,
       _storeAttachment = storeAttachment,
       _applyAttachmentRecord = applyAttachmentRecord,
       _applyAttachmentTombstone = applyAttachmentTombstone,
       _hostEphemeral = hostEphemeral,
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
    required BuildAttachmentSyncManifest buildAttachmentManifest,
    required ReadAttachmentForSync readAttachment,
    required StoreAttachmentFromSync storeAttachment,
    required ApplyAttachmentRecordFromSync applyAttachmentRecord,
    required ApplyAttachmentTombstoneFromSync applyAttachmentTombstone,
    bool localNetworkOnly = true,
    RemoteAppliedCallback? onRemoteApplied,
  }) async {
    final availableAddresses = await localLanIpv4Addresses(
      localNetworkOnly: localNetworkOnly,
    );
    if (availableAddresses.isEmpty) {
      throw StateError(
        'Не найден локальный IPv4-адрес. Подключи устройство к Wi-Fi или LAN.',
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
    final hostEphemeral = await LanEphemeralKeyPair.generate();
    final session = LanSyncHostSession._(
      server: server,
      addresses: addresses,
      sessionId: const Uuid().v4(),
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      local: local,
      targetPeer: targetPeer,
      crypto: crypto,
      hostEphemeral: hostEphemeral,
      buildOutgoing: buildOutgoing,
      applyIncoming: applyIncoming,
      loadCursor: loadCursor,
      saveCursor: saveCursor,
      markSuccess: markSuccess,
      buildAttachmentManifest: buildAttachmentManifest,
      readAttachment: readAttachment,
      storeAttachment: storeAttachment,
      applyAttachmentRecord: applyAttachmentRecord,
      applyAttachmentTombstone: applyAttachmentTombstone,
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
  final DateTime expiresAt;
  final LocalPairingIdentity local;
  final PairingPeer targetPeer;
  final PairingCrypto crypto;
  final LanEphemeralKeyPair _hostEphemeral;
  final BuildOutgoingBatch _buildOutgoing;
  final ApplyIncomingChanges _applyIncoming;
  final LoadPeerCursor _loadCursor;
  final SavePeerCursor _saveCursor;
  final MarkPeerSyncSuccess _markSuccess;
  final BuildAttachmentSyncManifest _buildAttachmentManifest;
  final ReadAttachmentForSync _readAttachment;
  final StoreAttachmentFromSync _storeAttachment;
  final ApplyAttachmentRecordFromSync _applyAttachmentRecord;
  final ApplyAttachmentTombstoneFromSync _applyAttachmentTombstone;
  final RemoteAppliedCallback? _onRemoteApplied;
  final StreamController<LanSyncReport> _reportController =
      StreamController<LanSyncReport>.broadcast();
  final StreamController<LanSyncProgress> _progressController =
      StreamController<LanSyncProgress>.broadcast();
  final Map<String, _PendingSyncRound> _pendingRounds = {};
  final Set<String> _completedAttachmentTransfers = <String>{};
  final HttpConcurrencyGate _requestGate = HttpConcurrencyGate(
    maxConcurrent: lanMaxUnauthenticatedRequests,
  );
  int _attachmentFilesReceived = 0;
  int _attachmentFilesSent = 0;
  int _attachmentBytesReceived = 0;
  int _attachmentBytesSent = 0;
  int _attachmentRecordsApplied = 0;
  int _attachmentTombstonesApplied = 0;
  int _attachmentWorkTotal = 0;
  int _attachmentWorkCompleted = 0;
  int _attachmentBytesTotal = 0;
  int _attachmentBytesTransferred = 0;

  StreamSubscription<HttpRequest>? _subscription;
  Timer? _expiryTimer;
  bool _closed = false;
  LanSecureChannel? _secureChannel;
  String? _authenticatedClientChallenge;

  Stream<LanSyncReport> get reports => _reportController.stream;
  Stream<LanSyncProgress> get progress => _progressController.stream;

  Future<LanSyncOffer> offerFor(String address) async {
    final unsigned = LanSyncOffer(
      host: address,
      port: _server.port,
      sessionId: sessionId,
      expiresAt: expiresAt,
      hostPeer: local.peer,
      targetDeviceId: targetPeer.deviceId,
      hostEphemeralX25519PublicKey: _hostEphemeral.publicKeyBase64,
      signature: '',
    );
    final signature = await crypto.sign(
      unsigned.signingPayload,
      local.keyMaterial,
    );
    return LanSyncOffer(
      host: unsigned.host,
      port: unsigned.port,
      sessionId: unsigned.sessionId,
      expiresAt: unsigned.expiresAt,
      hostPeer: unsigned.hostPeer,
      targetDeviceId: unsigned.targetDeviceId,
      hostEphemeralX25519PublicKey: unsigned.hostEphemeralX25519PublicKey,
      signature: signature,
    );
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
          'error': 'sync_expired',
        });
        return;
      }
      if (request.method == 'POST' &&
          request.uri.path == '/v2/sync/handshake') {
        await _handleHandshake(request);
        return;
      }
      if (request.method == 'POST' && request.uri.path == '/v2/sync/exchange') {
        await _handleExchange(request);
        return;
      }
      if (request.method == 'POST' &&
          request.uri.path == '/v2/sync/attachment') {
        await _handleAttachmentCommand(request);
        return;
      }
      if (request.method == 'POST' && request.uri.path == '/v2/sync/ack') {
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

  Future<void> _handleHandshake(HttpRequest request) async {
    if (_secureChannel != null) {
      await _jsonResponse(
        request.response,
        HttpStatus.conflict,
        <String, dynamic>{'error': 'handshake_already_completed'},
      );
      return;
    }
    final payload = LanSyncHandshakeRequest.fromJson(await _readJson(request));
    if (payload.sessionId != sessionId ||
        payload.offerSignature.isEmpty ||
        payload.clientChallenge.isEmpty ||
        payload.clientEphemeralX25519PublicKey.isEmpty ||
        DateTime.now().difference(payload.sentAt).abs() >
            const Duration(minutes: 2)) {
      await _jsonResponse(
        request.response,
        HttpStatus.forbidden,
        <String, dynamic>{'error': 'invalid_handshake'},
      );
      return;
    }
    _validatePeer(payload.peer);
    final requestedHost = request.requestedUri.host;
    final expectedOffer = await offerFor(requestedHost);
    if (payload.offerSignature != expectedOffer.signature) {
      await _jsonResponse(
        request.response,
        HttpStatus.forbidden,
        <String, dynamic>{'error': 'invalid_offer'},
      );
      return;
    }
    final requestSigningPayload = payload.signingPayload(
      expectedOffer.signingPayload,
    );
    final valid = await crypto.verify(
      message: requestSigningPayload,
      signatureBase64: payload.signature,
      publicKeyBase64: targetPeer.publicKey,
    );
    if (!valid) {
      await _jsonResponse(
        request.response,
        HttpStatus.forbidden,
        <String, dynamic>{'error': 'invalid_signature'},
      );
      return;
    }

    final unsigned = LanSyncHandshakeResponse(
      sessionId: sessionId,
      hostDeviceId: local.peer.deviceId,
      clientChallenge: payload.clientChallenge,
      hostChallenge: crypto.randomToken(),
      sentAt: DateTime.now(),
      signature: '',
    );
    final responseSigningPayload = unsigned.signingPayload(
      requestSigningPayload,
      payload.signature,
    );
    final signature = await crypto.sign(
      responseSigningPayload,
      local.keyMaterial,
    );
    final response = LanSyncHandshakeResponse(
      sessionId: unsigned.sessionId,
      hostDeviceId: unsigned.hostDeviceId,
      clientChallenge: unsigned.clientChallenge,
      hostChallenge: unsigned.hostChallenge,
      sentAt: unsigned.sentAt,
      signature: signature,
    );
    final transcript = _handshakeTranscript(
      requestSigningPayload: requestSigningPayload,
      requestSignature: payload.signature,
      responseSigningPayload: responseSigningPayload,
      responseSignature: signature,
    );
    _secureChannel = await LanSecureChannel.forHost(
      sessionId: sessionId,
      hostKeyPair: _hostEphemeral.keyPair,
      clientPublicKeyBase64: payload.clientEphemeralX25519PublicKey,
      transcript: transcript,
    );
    _hostEphemeral.keyPair.destroy();
    _authenticatedClientChallenge = payload.clientChallenge;
    await _jsonResponse(request.response, HttpStatus.ok, response.toJson());
  }

  Future<void> _handleExchange(HttpRequest request) async {
    final secureRequest = await _readSecureRequest(request);
    final payload = LanSyncExchangeRequest.fromJson(secureRequest.json);
    if (payload.roundId != secureRequest.context) {
      throw StateError('invalid_envelope_context');
    }
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
    final attachmentManifest = await _buildAttachmentManifest();
    final requesterAttachmentPlan = buildAttachmentSyncPlan(
      local: payload.attachmentManifest,
      remote: attachmentManifest,
    );
    final responderAttachmentPlan = buildAttachmentSyncPlan(
      local: attachmentManifest,
      remote: payload.attachmentManifest,
    );
    _attachmentWorkTotal =
        _planWorkCount(requesterAttachmentPlan) +
        _planWorkCount(responderAttachmentPlan);
    _attachmentWorkCompleted = 0;
    _attachmentBytesTotal =
        _planByteCount(requesterAttachmentPlan) +
        _planByteCount(responderAttachmentPlan);
    _attachmentBytesTransferred = 0;
    _emitHostProgress(stage: LanSyncProgressStage.exchangingJournal, round: 1);
    final unsigned = LanSyncExchangeResponse(
      sessionId: sessionId,
      roundId: payload.roundId,
      hostPeer: local.peer,
      batch: outgoing,
      remoteApplyResult: applied,
      attachmentManifest: attachmentManifest,
      requesterAttachmentPlan: requesterAttachmentPlan,
      responderAttachmentPlan: responderAttachmentPlan,
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
      attachmentManifest: attachmentManifest,
      requesterAttachmentPlan: requesterAttachmentPlan,
      responderAttachmentPlan: responderAttachmentPlan,
      signature: signature,
    );
    _pendingRounds[payload.roundId] = _PendingSyncRound(
      request: payload,
      response: response,
      previousCursor: cursor,
      startedAt: startedAt,
    );
    await _secureJsonResponse(
      request.response,
      HttpStatus.ok,
      response.toJson(),
      endpoint: request.uri.path,
      context: secureRequest.context,
    );
  }

  Future<void> _handleAttachmentCommand(HttpRequest request) async {
    final secureRequest = await _readSecureRequest(request);
    final command = LanAttachmentCommand.fromJson(secureRequest.json);
    if (command.transferId != secureRequest.context) {
      throw StateError('invalid_envelope_context');
    }
    _validateSession(command.sessionId, command.token);
    _validatePeer(command.peer);
    final valid = await crypto.verify(
      message: command.signingPayload,
      signatureBase64: command.signature,
      publicKeyBase64: targetPeer.publicKey,
    );
    if (!valid) {
      await _jsonResponse(request.response, HttpStatus.forbidden, {
        'error': 'invalid_signature',
      });
      return;
    }

    final repeatedTransfer = _completedAttachmentTransfers.contains(
      command.transferId,
    );
    Uint8List? responseBytes;
    var changed = false;
    switch (command.kind) {
      case LanAttachmentCommandKind.download:
        _requireManifestEntry(await _buildAttachmentManifest(), command.entry);
        responseBytes = await _readAttachment(command.entry);
        if (responseBytes == null) {
          throw StateError('attachment_not_found');
        }
        _validateTransferredBytes(command.entry, responseBytes);
        if (!repeatedTransfer) {
          _attachmentFilesSent += 1;
          _attachmentBytesSent += responseBytes.length;
          _attachmentWorkCompleted += 1;
          _attachmentBytesTransferred += responseBytes.length;
        }
        _emitHostProgress(
          stage: LanSyncProgressStage.downloadingAttachment,
          currentFileName: _attachmentDisplayName(command.entry),
        );
        break;
      case LanAttachmentCommandKind.upload:
        final uploadManifest = await _buildAttachmentManifest();
        final uploadAlreadyApplied = _manifestContainsExactEntry(
          uploadManifest,
          command.entry,
        );
        if (!uploadAlreadyApplied) {
          _requirePlannedAction(
            local: uploadManifest,
            remoteEntry: command.entry,
            expected: LanAttachmentCommandKind.upload,
          );
          final raw = command.dataBase64;
          if (raw == null || raw.isEmpty) {
            throw const FormatException('Attachment payload is missing.');
          }
          final bytes = base64Decode(raw);
          _validateTransferredBytes(command.entry, bytes);
          final uploadResult = await _storeAttachment(command.entry, bytes);
          changed = uploadResult.changed;
          _attachmentFilesReceived += 1;
          _attachmentBytesReceived += bytes.length;
          _attachmentWorkCompleted += 1;
          _attachmentBytesTransferred += bytes.length;
        }
        _emitHostProgress(
          stage: LanSyncProgressStage.uploadingAttachment,
          currentFileName: _attachmentDisplayName(command.entry),
        );
        break;
      case LanAttachmentCommandKind.record:
        final recordManifest = await _buildAttachmentManifest();
        if (!_manifestContainsExactEntry(recordManifest, command.entry)) {
          _requirePlannedAction(
            local: recordManifest,
            remoteEntry: command.entry,
            expected: LanAttachmentCommandKind.record,
          );
          final recordResult = await _applyAttachmentRecord(command.entry);
          changed = recordResult.changed;
          if (recordResult.changed) {
            _attachmentRecordsApplied += 1;
          }
          _attachmentWorkCompleted += 1;
        }
        _emitHostProgress(
          stage: LanSyncProgressStage.applyingAttachmentMetadata,
          currentFileName: _attachmentDisplayName(command.entry),
        );
        break;
      case LanAttachmentCommandKind.tombstone:
        final tombstoneManifest = await _buildAttachmentManifest();
        if (!_manifestContainsExactEntry(tombstoneManifest, command.entry)) {
          _requirePlannedAction(
            local: tombstoneManifest,
            remoteEntry: command.entry,
            expected: LanAttachmentCommandKind.tombstone,
          );
          final tombstoneResult = await _applyAttachmentTombstone(
            command.entry,
          );
          changed = tombstoneResult.changed;
          if (tombstoneResult.changed) {
            _attachmentTombstonesApplied += 1;
          }
          _attachmentWorkCompleted += 1;
        }
        _emitHostProgress(
          stage: LanSyncProgressStage.applyingAttachmentMetadata,
          currentFileName: _attachmentDisplayName(command.entry),
        );
        break;
    }

    _completedAttachmentTransfers.add(command.transferId);
    final unsigned = LanAttachmentCommandResponse(
      sessionId: sessionId,
      transferId: command.transferId,
      hostPeer: local.peer,
      kind: command.kind,
      entry: command.entry,
      changed: changed,
      dataBase64: responseBytes == null ? null : base64Encode(responseBytes),
      signature: '',
    );
    final signature = await crypto.sign(
      unsigned.signingPayload,
      local.keyMaterial,
    );
    final response = LanAttachmentCommandResponse(
      sessionId: sessionId,
      transferId: command.transferId,
      hostPeer: local.peer,
      kind: command.kind,
      entry: command.entry,
      changed: changed,
      dataBase64: unsigned.dataBase64,
      signature: signature,
    );
    await _secureJsonResponse(
      request.response,
      HttpStatus.ok,
      response.toJson(),
      endpoint: request.uri.path,
      context: secureRequest.context,
    );
  }

  Future<void> _handleAck(HttpRequest request) async {
    final secureRequest = await _readSecureRequest(request);
    final ack = LanSyncAck.fromJson(secureRequest.json);
    if (ack.roundId != secureRequest.context) {
      throw StateError('invalid_envelope_context');
    }
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

    _emitHostProgress(stage: LanSyncProgressStage.finalizing, round: 1);
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
      attachmentPlanFromPeer: pending.response.responderAttachmentPlan,
      attachmentPlanByPeer: pending.response.requesterAttachmentPlan,
      attachmentFilesReceived: _attachmentFilesReceived,
      attachmentFilesSent: _attachmentFilesSent,
      attachmentBytesReceived: _attachmentBytesReceived,
      attachmentBytesSent: _attachmentBytesSent,
      attachmentRecordsApplied: _attachmentRecordsApplied,
      attachmentTombstonesApplied: _attachmentTombstonesApplied,
    );
    _attachmentFilesReceived = 0;
    _attachmentFilesSent = 0;
    _attachmentBytesReceived = 0;
    _attachmentBytesSent = 0;
    _attachmentRecordsApplied = 0;
    _attachmentTombstonesApplied = 0;
    _attachmentWorkTotal = 0;
    _attachmentWorkCompleted = 0;
    _attachmentBytesTotal = 0;
    _attachmentBytesTransferred = 0;
    _completedAttachmentTransfers.clear();
    _pendingRounds.remove(ack.roundId);
    _reportController.add(report);
    await _secureJsonResponse(
      request.response,
      HttpStatus.ok,
      <String, dynamic>{'status': 'acknowledged'},
      endpoint: request.uri.path,
      context: secureRequest.context,
    );
  }

  void _emitHostProgress({
    required LanSyncProgressStage stage,
    int round = 1,
    String? currentFileName,
  }) {
    if (_progressController.isClosed) {
      return;
    }
    _progressController.add(
      LanSyncProgress(
        stage: stage,
        round: round,
        completedItems: _attachmentWorkCompleted,
        totalItems: _attachmentWorkTotal,
        bytesTransferred: _attachmentBytesTransferred,
        totalBytes: _attachmentBytesTotal,
        currentFileName: currentFileName,
      ),
    );
  }

  void _validateSession(String receivedSessionId, String receivedToken) {
    if (receivedSessionId != sessionId || receivedToken.isNotEmpty) {
      throw StateError('invalid_session');
    }
  }

  Future<_DecryptedSecureRequest> _readSecureRequest(
    HttpRequest request,
  ) async {
    final channel = _secureChannel;
    if (channel == null || _authenticatedClientChallenge == null) {
      throw StateError('authentication_required');
    }
    final envelope = EncryptedEnvelope.fromJson(await _readJson(request));
    final json = await channel.decryptJson(
      envelope,
      endpoint: request.uri.path,
    );
    return _DecryptedSecureRequest(json: json, context: envelope.context);
  }

  Future<void> _secureJsonResponse(
    HttpResponse response,
    int statusCode,
    Map<String, dynamic> payload, {
    required String endpoint,
    required String context,
  }) async {
    final channel = _secureChannel;
    if (channel == null) {
      throw StateError('authentication_required');
    }
    final envelope = await channel.encryptJson(
      payload,
      endpoint: endpoint,
      context: context,
    );
    await _jsonResponse(response, statusCode, envelope.toJson());
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
    _secureChannel?.destroy();
    if (!_hostEphemeral.keyPair.hasBeenDestroyed) {
      _hostEphemeral.keyPair.destroy();
    }
    await _subscription?.cancel();
    await _server.close(force: true);
    await _reportController.close();
    await _progressController.close();
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
    required BuildAttachmentSyncManifest buildAttachmentManifest,
    required ReadAttachmentForSync readAttachment,
    required StoreAttachmentFromSync storeAttachment,
    required ApplyAttachmentRecordFromSync applyAttachmentRecord,
    required ApplyAttachmentTombstoneFromSync applyAttachmentTombstone,
    bool localNetworkOnly = true,
    RemoteAppliedCallback? onRemoteApplied,
    LanSyncProgressCallback? onProgress,
    LanSyncCancellationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled();
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
    if (localNetworkOnly && !isLocalOnlyIpv4(offer.host)) {
      throw StateError(
        'Адрес устройства не относится к разрешённой локальной сети.',
      );
    }
    final validOffer = await crypto.verify(
      message: offer.signingPayload,
      signatureBase64: offer.signature,
      publicKeyBase64: trustedHost.publicKey,
    );
    if (!validOffer) {
      throw StateError('Подпись кода синхронизации неверна.');
    }

    final startedAt = DateTime.now();
    onProgress?.call(
      const LanSyncProgress(stage: LanSyncProgressStage.preparing),
    );
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    if (cancellationToken != null) {
      unawaited(
        cancellationToken.whenCancelled.then((_) {
          client.close(force: true);
        }),
      );
    }
    late final LanSecureChannel channel;
    try {
      final clientEphemeral = await LanEphemeralKeyPair.generate();
      final clientChallenge = crypto.randomToken();
      final unsignedHandshake = LanSyncHandshakeRequest(
        sessionId: offer.sessionId,
        peer: local.peer,
        clientEphemeralX25519PublicKey: clientEphemeral.publicKeyBase64,
        clientChallenge: clientChallenge,
        sentAt: DateTime.now(),
        offerSignature: offer.signature,
        signature: '',
      );
      final handshakeSigningPayload = unsignedHandshake.signingPayload(
        offer.signingPayload,
      );
      final handshakeSignature = await crypto.sign(
        handshakeSigningPayload,
        local.keyMaterial,
      );
      final handshakeRequest = LanSyncHandshakeRequest(
        sessionId: unsignedHandshake.sessionId,
        peer: unsignedHandshake.peer,
        clientEphemeralX25519PublicKey:
            unsignedHandshake.clientEphemeralX25519PublicKey,
        clientChallenge: unsignedHandshake.clientChallenge,
        sentAt: unsignedHandshake.sentAt,
        offerSignature: unsignedHandshake.offerSignature,
        signature: handshakeSignature,
      );
      final rawHandshake = await _postPlainJson(
        client,
        offer,
        '/v2/sync/handshake',
        handshakeRequest.toJson(),
      );
      if (rawHandshake.statusCode != HttpStatus.ok) {
        client.close(force: true);
        throw StateError(_friendlySyncError(rawHandshake.json));
      }
      final handshakeResponse = LanSyncHandshakeResponse.fromJson(
        rawHandshake.json,
      );
      if (handshakeResponse.sessionId != offer.sessionId ||
          handshakeResponse.hostDeviceId != trustedHost.deviceId ||
          handshakeResponse.clientChallenge != clientChallenge ||
          handshakeResponse.hostChallenge.isEmpty ||
          DateTime.now().difference(handshakeResponse.sentAt).abs() >
              const Duration(minutes: 2)) {
        client.close(force: true);
        throw StateError('Ответ защищённого соединения не прошёл проверку.');
      }
      final responseSigningPayload = handshakeResponse.signingPayload(
        handshakeSigningPayload,
        handshakeSignature,
      );
      final validHandshakeResponse = await crypto.verify(
        message: responseSigningPayload,
        signatureBase64: handshakeResponse.signature,
        publicKeyBase64: trustedHost.publicKey,
      );
      if (!validHandshakeResponse) {
        client.close(force: true);
        throw StateError('Сервер не доказал владение доверенным ключом.');
      }
      channel = await LanSecureChannel.forClient(
        sessionId: offer.sessionId,
        clientKeyPair: clientEphemeral.keyPair,
        hostPublicKeyBase64: offer.hostEphemeralX25519PublicKey,
        transcript: _handshakeTranscript(
          requestSigningPayload: handshakeSigningPayload,
          requestSignature: handshakeSignature,
          responseSigningPayload: responseSigningPayload,
          responseSignature: handshakeResponse.signature,
        ),
      );
      clientEphemeral.keyPair.destroy();
    } on Object {
      client.close(force: true);
      rethrow;
    }
    var roundCount = 0;
    var sentCount = 0;
    var receivedCount = 0;
    var appliedCount = 0;
    var duplicateCount = 0;
    var staleCount = 0;
    var unsupportedCount = 0;
    var hasMore = false;
    var attachmentPlanFromPeer = const AttachmentSyncPlan.empty();
    var attachmentPlanByPeer = const AttachmentSyncPlan.empty();
    var attachmentFilesReceived = 0;
    var attachmentFilesSent = 0;
    var attachmentBytesReceived = 0;
    var attachmentBytesSent = 0;
    var attachmentRecordsApplied = 0;
    var attachmentTombstonesApplied = 0;
    var attachmentManifest = await buildAttachmentManifest();

    try {
      do {
        cancellationToken?.throwIfCancelled();
        roundCount++;
        onProgress?.call(
          LanSyncProgress(
            stage: LanSyncProgressStage.exchangingJournal,
            round: roundCount,
          ),
        );
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
          token: '',
          roundId: roundId,
          peer: local.peer,
          batch: outgoing,
          attachmentManifest: attachmentManifest,
          signature: '',
        );
        final requestSignature = await crypto.sign(
          unsigned.signingPayload,
          local.keyMaterial,
        );
        final request = LanSyncExchangeRequest(
          sessionId: offer.sessionId,
          token: '',
          roundId: roundId,
          peer: local.peer,
          batch: outgoing,
          attachmentManifest: attachmentManifest,
          signature: requestSignature,
        );
        cancellationToken?.throwIfCancelled();
        final rawResponse = await _postEncryptedJson(
          client,
          offer,
          channel,
          '/v2/sync/exchange',
          request.toJson(),
          context: roundId,
        );
        cancellationToken?.throwIfCancelled();
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
        final expectedPlanFromPeer = buildAttachmentSyncPlan(
          local: attachmentManifest,
          remote: response.attachmentManifest,
        );
        final expectedPlanByPeer = buildAttachmentSyncPlan(
          local: response.attachmentManifest,
          remote: attachmentManifest,
        );
        if (jsonEncode(expectedPlanFromPeer.toJson()) !=
                jsonEncode(response.requesterAttachmentPlan.toJson()) ||
            jsonEncode(expectedPlanByPeer.toJson()) !=
                jsonEncode(response.responderAttachmentPlan.toJson())) {
          throw StateError('План синхронизации вложений не прошёл проверку.');
        }
        attachmentPlanFromPeer = expectedPlanFromPeer;
        attachmentPlanByPeer = expectedPlanByPeer;
        final attachmentWorkTotal =
            _planWorkCount(expectedPlanFromPeer) +
            _planWorkCount(expectedPlanByPeer);
        final attachmentBytesTotal =
            _planByteCount(expectedPlanFromPeer) +
            _planByteCount(expectedPlanByPeer);
        var attachmentWorkCompleted = 0;
        var attachmentBytesTransferred = 0;
        final applied = await applyIncoming(response.batch.changes);
        if (applied.insertedCount > 0 && onRemoteApplied != null) {
          try {
            await onRemoteApplied(applied);
          } on Object {
            // UI refresh failures must not invalidate an already applied batch.
          }
        }

        for (final entry in expectedPlanFromPeer.files) {
          final transferId = const Uuid().v4();
          onProgress?.call(
            LanSyncProgress(
              stage: LanSyncProgressStage.downloadingAttachment,
              round: roundCount,
              completedItems: attachmentWorkCompleted,
              totalItems: attachmentWorkTotal,
              bytesTransferred: attachmentBytesTransferred,
              totalBytes: attachmentBytesTotal,
              currentFileName: _attachmentDisplayName(entry),
            ),
          );
          final response = await runLanSyncOperationWithRetry(
            operation:
                (_) => _sendAttachmentCommand(
                  client: client,
                  offer: offer,
                  channel: channel,
                  local: local,
                  trustedHost: trustedHost,
                  crypto: crypto,
                  kind: LanAttachmentCommandKind.download,
                  entry: entry,
                  transferId: transferId,
                  cancellationToken: cancellationToken,
                ),
            shouldRetry: _isRetryableTransferError,
            cancellationToken: cancellationToken,
            onRetry: (nextAttempt, _) {
              onProgress?.call(
                LanSyncProgress(
                  stage: LanSyncProgressStage.retryingAttachment,
                  round: roundCount,
                  completedItems: attachmentWorkCompleted,
                  totalItems: attachmentWorkTotal,
                  bytesTransferred: attachmentBytesTransferred,
                  totalBytes: attachmentBytesTotal,
                  currentFileName: _attachmentDisplayName(entry),
                  retryAttempt: nextAttempt,
                ),
              );
            },
          );
          final raw = response.dataBase64;
          if (raw == null || raw.isEmpty) {
            throw StateError('Устройство не передало запрошенное вложение.');
          }
          final bytes = base64Decode(raw);
          _validateTransferredBytes(entry, bytes);
          await storeAttachment(entry, bytes);
          attachmentFilesReceived += 1;
          attachmentBytesReceived += bytes.length;
          attachmentWorkCompleted += 1;
          attachmentBytesTransferred += bytes.length;
          onProgress?.call(
            LanSyncProgress(
              stage: LanSyncProgressStage.downloadingAttachment,
              round: roundCount,
              completedItems: attachmentWorkCompleted,
              totalItems: attachmentWorkTotal,
              bytesTransferred: attachmentBytesTransferred,
              totalBytes: attachmentBytesTotal,
              currentFileName: _attachmentDisplayName(entry),
            ),
          );
        }
        for (final entry in expectedPlanFromPeer.records) {
          onProgress?.call(
            LanSyncProgress(
              stage: LanSyncProgressStage.applyingAttachmentMetadata,
              round: roundCount,
              completedItems: attachmentWorkCompleted,
              totalItems: attachmentWorkTotal,
              bytesTransferred: attachmentBytesTransferred,
              totalBytes: attachmentBytesTotal,
              currentFileName: _attachmentDisplayName(entry),
            ),
          );
          final result = await applyAttachmentRecord(entry);
          if (result.changed) {
            attachmentRecordsApplied += 1;
          }
          attachmentWorkCompleted += 1;
        }
        for (final entry in expectedPlanFromPeer.tombstones) {
          onProgress?.call(
            LanSyncProgress(
              stage: LanSyncProgressStage.applyingAttachmentMetadata,
              round: roundCount,
              completedItems: attachmentWorkCompleted,
              totalItems: attachmentWorkTotal,
              bytesTransferred: attachmentBytesTransferred,
              totalBytes: attachmentBytesTotal,
              currentFileName: _attachmentDisplayName(entry),
            ),
          );
          final result = await applyAttachmentTombstone(entry);
          if (result.changed) {
            attachmentTombstonesApplied += 1;
          }
          attachmentWorkCompleted += 1;
        }

        for (final entry in expectedPlanByPeer.files) {
          final transferId = const Uuid().v4();
          onProgress?.call(
            LanSyncProgress(
              stage: LanSyncProgressStage.uploadingAttachment,
              round: roundCount,
              completedItems: attachmentWorkCompleted,
              totalItems: attachmentWorkTotal,
              bytesTransferred: attachmentBytesTransferred,
              totalBytes: attachmentBytesTotal,
              currentFileName: _attachmentDisplayName(entry),
            ),
          );
          final bytes = await readAttachment(entry);
          if (bytes == null) {
            throw StateError(
              'Локальное вложение исчезло во время синхронизации.',
            );
          }
          _validateTransferredBytes(entry, bytes);
          await runLanSyncOperationWithRetry(
            operation:
                (_) => _sendAttachmentCommand(
                  client: client,
                  offer: offer,
                  channel: channel,
                  local: local,
                  trustedHost: trustedHost,
                  crypto: crypto,
                  kind: LanAttachmentCommandKind.upload,
                  entry: entry,
                  dataBase64: base64Encode(bytes),
                  transferId: transferId,
                  cancellationToken: cancellationToken,
                ),
            shouldRetry: _isRetryableTransferError,
            cancellationToken: cancellationToken,
            onRetry: (nextAttempt, _) {
              onProgress?.call(
                LanSyncProgress(
                  stage: LanSyncProgressStage.retryingAttachment,
                  round: roundCount,
                  completedItems: attachmentWorkCompleted,
                  totalItems: attachmentWorkTotal,
                  bytesTransferred: attachmentBytesTransferred,
                  totalBytes: attachmentBytesTotal,
                  currentFileName: _attachmentDisplayName(entry),
                  retryAttempt: nextAttempt,
                ),
              );
            },
          );
          attachmentFilesSent += 1;
          attachmentBytesSent += bytes.length;
          attachmentWorkCompleted += 1;
          attachmentBytesTransferred += bytes.length;
          onProgress?.call(
            LanSyncProgress(
              stage: LanSyncProgressStage.uploadingAttachment,
              round: roundCount,
              completedItems: attachmentWorkCompleted,
              totalItems: attachmentWorkTotal,
              bytesTransferred: attachmentBytesTransferred,
              totalBytes: attachmentBytesTotal,
              currentFileName: _attachmentDisplayName(entry),
            ),
          );
        }
        for (final entry in expectedPlanByPeer.records) {
          final transferId = const Uuid().v4();
          onProgress?.call(
            LanSyncProgress(
              stage: LanSyncProgressStage.applyingAttachmentMetadata,
              round: roundCount,
              completedItems: attachmentWorkCompleted,
              totalItems: attachmentWorkTotal,
              bytesTransferred: attachmentBytesTransferred,
              totalBytes: attachmentBytesTotal,
              currentFileName: _attachmentDisplayName(entry),
            ),
          );
          await runLanSyncOperationWithRetry(
            operation:
                (_) => _sendAttachmentCommand(
                  client: client,
                  offer: offer,
                  channel: channel,
                  local: local,
                  trustedHost: trustedHost,
                  crypto: crypto,
                  kind: LanAttachmentCommandKind.record,
                  entry: entry,
                  transferId: transferId,
                  cancellationToken: cancellationToken,
                ),
            shouldRetry: _isRetryableTransferError,
            cancellationToken: cancellationToken,
            onRetry: (nextAttempt, _) {
              onProgress?.call(
                LanSyncProgress(
                  stage: LanSyncProgressStage.retryingAttachment,
                  round: roundCount,
                  completedItems: attachmentWorkCompleted,
                  totalItems: attachmentWorkTotal,
                  bytesTransferred: attachmentBytesTransferred,
                  totalBytes: attachmentBytesTotal,
                  currentFileName: _attachmentDisplayName(entry),
                  retryAttempt: nextAttempt,
                ),
              );
            },
          );
          attachmentWorkCompleted += 1;
        }
        for (final entry in expectedPlanByPeer.tombstones) {
          final transferId = const Uuid().v4();
          onProgress?.call(
            LanSyncProgress(
              stage: LanSyncProgressStage.applyingAttachmentMetadata,
              round: roundCount,
              completedItems: attachmentWorkCompleted,
              totalItems: attachmentWorkTotal,
              bytesTransferred: attachmentBytesTransferred,
              totalBytes: attachmentBytesTotal,
              currentFileName: _attachmentDisplayName(entry),
            ),
          );
          await runLanSyncOperationWithRetry(
            operation:
                (_) => _sendAttachmentCommand(
                  client: client,
                  offer: offer,
                  channel: channel,
                  local: local,
                  trustedHost: trustedHost,
                  crypto: crypto,
                  kind: LanAttachmentCommandKind.tombstone,
                  entry: entry,
                  transferId: transferId,
                  cancellationToken: cancellationToken,
                ),
            shouldRetry: _isRetryableTransferError,
            cancellationToken: cancellationToken,
            onRetry: (nextAttempt, _) {
              onProgress?.call(
                LanSyncProgress(
                  stage: LanSyncProgressStage.retryingAttachment,
                  round: roundCount,
                  completedItems: attachmentWorkCompleted,
                  totalItems: attachmentWorkTotal,
                  bytesTransferred: attachmentBytesTransferred,
                  totalBytes: attachmentBytesTotal,
                  currentFileName: _attachmentDisplayName(entry),
                  retryAttempt: nextAttempt,
                ),
              );
            },
          );
          attachmentWorkCompleted += 1;
        }
        attachmentManifest = await buildAttachmentManifest();

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
        final ackResponse = await _postEncryptedJson(
          client,
          offer,
          channel,
          '/v2/sync/ack',
          ack.toJson(),
          context: roundId,
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
    } on Object {
      cancellationToken?.throwIfCancelled();
      rethrow;
    } finally {
      channel.destroy();
      client.close(force: true);
    }

    onProgress?.call(
      LanSyncProgress(
        stage: LanSyncProgressStage.finalizing,
        round: roundCount,
        completedItems: 1,
        totalItems: 1,
      ),
    );
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
      attachmentPlanFromPeer: attachmentPlanFromPeer,
      attachmentPlanByPeer: attachmentPlanByPeer,
      attachmentFilesReceived: attachmentFilesReceived,
      attachmentFilesSent: attachmentFilesSent,
      attachmentBytesReceived: attachmentBytesReceived,
      attachmentBytesSent: attachmentBytesSent,
      attachmentRecordsApplied: attachmentRecordsApplied,
      attachmentTombstonesApplied: attachmentTombstonesApplied,
    );
  }

  static Future<LanAttachmentCommandResponse> _sendAttachmentCommand({
    required HttpClient client,
    required LanSyncOffer offer,
    required LanSecureChannel channel,
    required LocalPairingIdentity local,
    required PairingPeer trustedHost,
    required PairingCrypto crypto,
    required LanAttachmentCommandKind kind,
    required AttachmentSyncEntry entry,
    String? dataBase64,
    String? transferId,
    LanSyncCancellationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled();
    final effectiveTransferId = transferId ?? const Uuid().v4();
    final unsigned = LanAttachmentCommand(
      sessionId: offer.sessionId,
      token: '',
      transferId: effectiveTransferId,
      peer: local.peer,
      kind: kind,
      entry: entry,
      dataBase64: dataBase64,
      signature: '',
    );
    final signature = await crypto.sign(
      unsigned.signingPayload,
      local.keyMaterial,
    );
    final command = LanAttachmentCommand(
      sessionId: offer.sessionId,
      token: '',
      transferId: effectiveTransferId,
      peer: local.peer,
      kind: kind,
      entry: entry,
      dataBase64: dataBase64,
      signature: signature,
    );
    cancellationToken?.throwIfCancelled();
    final rawResponse = await _postEncryptedJson(
      client,
      offer,
      channel,
      '/v2/sync/attachment',
      command.toJson(),
      context: effectiveTransferId,
    );
    cancellationToken?.throwIfCancelled();
    if (rawResponse.statusCode != HttpStatus.ok) {
      throw StateError(_friendlySyncError(rawResponse.json));
    }
    final response = LanAttachmentCommandResponse.fromJson(rawResponse.json);
    if (response.sessionId != offer.sessionId ||
        response.transferId != effectiveTransferId ||
        response.hostPeer.deviceId != trustedHost.deviceId ||
        response.hostPeer.publicKey != trustedHost.publicKey ||
        response.kind != kind ||
        !_sameAttachmentEntry(response.entry, entry)) {
      throw StateError('Ответ передачи вложения не прошёл проверку.');
    }
    final valid = await crypto.verify(
      message: response.signingPayload,
      signatureBase64: response.signature,
      publicKeyBase64: trustedHost.publicKey,
    );
    if (!valid) {
      throw StateError('Подпись передачи вложения неверна.');
    }
    return response;
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

int _planWorkCount(AttachmentSyncPlan plan) =>
    plan.files.length + plan.records.length + plan.tombstones.length;

int _planByteCount(AttachmentSyncPlan plan) =>
    plan.files.fold<int>(0, (total, entry) => total + entry.byteLength);

String _attachmentDisplayName(AttachmentSyncEntry entry) {
  final normalized = entry.relativePath.replaceAll('\\', '/');
  final segments = normalized.split('/');
  return segments.isEmpty ? entry.relativePath : segments.last;
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

class _DecryptedSecureRequest {
  const _DecryptedSecureRequest({required this.json, required this.context});

  final Map<String, dynamic> json;
  final String context;
}

Future<_JsonHttpResponse> _postPlainJson(
  HttpClient client,
  LanSyncOffer offer,
  String path,
  Map<String, dynamic> body,
) async {
  final request = await client.postUrl(
    Uri.parse('http://${offer.host}:${offer.port}$path'),
  );
  request.headers.contentType = ContentType.json;
  addJsonBody(request, body);
  return _readHttpResponse(
    await request.close(),
    maxBytes: _syncEndpointBudget(path),
  );
}

Future<_JsonHttpResponse> _postEncryptedJson(
  HttpClient client,
  LanSyncOffer offer,
  LanSecureChannel channel,
  String path,
  Map<String, dynamic> body, {
  required String context,
}) async {
  final envelope = await channel.encryptJson(
    body,
    endpoint: path,
    context: context,
  );
  final rawResponse = await _postPlainJson(
    client,
    offer,
    path,
    envelope.toJson(),
  );
  if (rawResponse.statusCode != HttpStatus.ok) {
    return rawResponse;
  }
  final responseEnvelope = EncryptedEnvelope.fromJson(rawResponse.json);
  if (responseEnvelope.context != context) {
    throw StateError('Ответ защищённого соединения имеет неверный контекст.');
  }
  final clearText = await channel.decryptJson(responseEnvelope, endpoint: path);
  return _JsonHttpResponse(rawResponse.statusCode, clearText);
}

String _handshakeTranscript({
  required String requestSigningPayload,
  required String requestSignature,
  required String responseSigningPayload,
  required String responseSignature,
}) {
  return jsonEncode(<String, dynamic>{
    'protocol': lanSyncProtocol,
    'securityVersion': lanSyncSecurityVersion,
    'requestSigningPayload': requestSigningPayload,
    'requestSignature': requestSignature,
    'responseSigningPayload': responseSigningPayload,
    'responseSignature': responseSignature,
  });
}

Future<_JsonHttpResponse> _readHttpResponse(
  HttpClientResponse response, {
  required int maxBytes,
}) async {
  final json = await readBoundedJsonResponse(response, maxBytes: maxBytes);
  return _JsonHttpResponse(response.statusCode, json);
}

Future<Map<String, dynamic>> _readJson(HttpRequest request) async {
  return readBoundedJson(
    request,
    maxBytes: _syncEndpointBudget(request.uri.path),
  );
}

int _syncEndpointBudget(String path) {
  return switch (path) {
    '/v2/sync/handshake' => lanHandshakeMaxBytes,
    '/v2/sync/exchange' => lanJournalEnvelopeMaxBytes,
    '/v2/sync/attachment' => lanAttachmentEnvelopeMaxBytes,
    '/v2/sync/ack' => lanHandshakeMaxBytes,
    _ => lanHandshakeMaxBytes,
  };
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
    ..set('Access-Control-Allow-Methods', 'POST, OPTIONS');
}

void _requireManifestEntry(
  AttachmentSyncManifest manifest,
  AttachmentSyncEntry requested,
) {
  for (final entry in manifest.entries) {
    if (_sameAttachmentEntry(entry, requested) && !entry.isDeleted) {
      return;
    }
  }
  throw StateError('attachment_not_found');
}

void _requirePlannedAction({
  required AttachmentSyncManifest local,
  required AttachmentSyncEntry remoteEntry,
  required LanAttachmentCommandKind expected,
}) {
  final remote = AttachmentSyncManifest(
    generatedAt: DateTime.now().toUtc(),
    entries: <AttachmentSyncEntry>[remoteEntry],
  );
  final plan = buildAttachmentSyncPlan(local: local, remote: remote);
  final allowed = switch (expected) {
    LanAttachmentCommandKind.upload => plan.files,
    LanAttachmentCommandKind.record => plan.records,
    LanAttachmentCommandKind.tombstone => plan.tombstones,
    LanAttachmentCommandKind.download => const <AttachmentSyncEntry>[],
  };
  if (!allowed.any((entry) => _sameAttachmentEntry(entry, remoteEntry))) {
    throw StateError('attachment_action_not_allowed');
  }
}

bool _manifestContainsExactEntry(
  AttachmentSyncManifest manifest,
  AttachmentSyncEntry expected,
) {
  return manifest.entries.any((entry) => _sameAttachmentEntry(entry, expected));
}

bool _isRetryableTransferError(Object error) {
  if (error is SocketException ||
      error is HttpException ||
      error is TimeoutException) {
    return true;
  }
  final message = error.toString().toLowerCase();
  const retryableFragments = <String>[
    'connection reset',
    'connection closed',
    'broken pipe',
    'timed out',
    'timeout',
    'temporarily unavailable',
    'software caused connection abort',
  ];
  return retryableFragments.any(message.contains);
}

bool _sameAttachmentEntry(AttachmentSyncEntry left, AttachmentSyncEntry right) {
  return left.relativePath == right.relativePath &&
      left.sha256 == right.sha256 &&
      left.byteLength == right.byteLength &&
      left.deletedAt?.toUtc().millisecondsSinceEpoch ==
          right.deletedAt?.toUtc().millisecondsSinceEpoch;
}

void _validateTransferredBytes(AttachmentSyncEntry entry, Uint8List bytes) {
  if (entry.isDeleted ||
      bytes.length != entry.byteLength ||
      bytes.length > maxAttachmentSyncEntryBytes) {
    throw const FormatException('Attachment payload size is invalid.');
  }
  if (sha256.convert(bytes).toString() != entry.sha256) {
    throw const FormatException('Attachment payload checksum is invalid.');
  }
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
  if (raw.contains('attachment_not_found')) {
    return 'Запрошенное вложение больше недоступно на другом устройстве.';
  }
  if (raw.contains('attachment_action_not_allowed')) {
    return 'Передача вложения отклонена из-за изменившегося состояния Vault.';
  }
  return raw.isEmpty ? 'Не удалось синхронизировать устройства.' : raw;
}
