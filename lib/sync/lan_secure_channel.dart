import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';
import 'package:synchronized/synchronized.dart';

import 'lan_sync_protocol_v2.dart';

class LanEphemeralKeyPair {
  const LanEphemeralKeyPair({
    required this.keyPair,
    required this.publicKeyBase64,
  });

  final KeyPair keyPair;
  final String publicKeyBase64;

  static Future<LanEphemeralKeyPair> generate() async {
    final keyPair = await X25519().newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    return LanEphemeralKeyPair(
      keyPair: keyPair,
      publicKeyBase64: base64UrlEncode(publicKey.bytes).replaceAll('=', ''),
    );
  }
}

class LanSecureChannel {
  LanSecureChannel._({
    required String sessionId,
    required SecretKey sendKey,
    required SecretKey receiveKey,
    required String sendDirection,
    required String receiveDirection,
  }) : _sessionId = sessionId,
       _sendKey = sendKey,
       _receiveKey = receiveKey,
       _sendDirection = sendDirection,
       _receiveDirection = receiveDirection;

  static const clientToHostDirection = 'client-to-host';
  static const hostToClientDirection = 'host-to-client';

  final String _sessionId;
  final SecretKey _sendKey;
  final SecretKey _receiveKey;
  final String _sendDirection;
  final String _receiveDirection;
  final Cipher _cipher = Chacha20.poly1305Aead();
  final Lock _sendLock = Lock();
  final Lock _receiveLock = Lock();
  int _sendCounter = 0;
  int _lastReceivedCounter = 0;

  void destroy() {
    _sendKey.destroy();
    _receiveKey.destroy();
  }

  static Future<LanSecureChannel> forClient({
    required String sessionId,
    required KeyPair clientKeyPair,
    required String hostPublicKeyBase64,
    required String transcript,
  }) {
    return _derive(
      sessionId: sessionId,
      localKeyPair: clientKeyPair,
      remotePublicKeyBase64: hostPublicKeyBase64,
      transcript: transcript,
      isHost: false,
    );
  }

  static Future<LanSecureChannel> forHost({
    required String sessionId,
    required KeyPair hostKeyPair,
    required String clientPublicKeyBase64,
    required String transcript,
  }) {
    return _derive(
      sessionId: sessionId,
      localKeyPair: hostKeyPair,
      remotePublicKeyBase64: clientPublicKeyBase64,
      transcript: transcript,
      isHost: true,
    );
  }

  static Future<LanSecureChannel> _derive({
    required String sessionId,
    required KeyPair localKeyPair,
    required String remotePublicKeyBase64,
    required String transcript,
    required bool isHost,
  }) async {
    final remoteBytes = _decodeBase64(remotePublicKeyBase64);
    if (remoteBytes.length != 32) {
      throw const FormatException('Invalid X25519 public key.');
    }
    final shared = await X25519().sharedSecretKey(
      keyPair: localKeyPair,
      remotePublicKey: SimplePublicKey(remoteBytes, type: KeyPairType.x25519),
    );
    final transcriptHash = hashes.sha256.convert(utf8.encode(transcript)).bytes;
    final kdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final clientToHost = await kdf.deriveKey(
      secretKey: shared,
      nonce: transcriptHash,
      info: utf8.encode('chronicle-lan-sync-v2/client-to-host'),
    );
    final hostToClient = await kdf.deriveKey(
      secretKey: shared,
      nonce: transcriptHash,
      info: utf8.encode('chronicle-lan-sync-v2/host-to-client'),
    );
    return LanSecureChannel._(
      sessionId: sessionId,
      sendKey: isHost ? hostToClient : clientToHost,
      receiveKey: isHost ? clientToHost : hostToClient,
      sendDirection: isHost ? hostToClientDirection : clientToHostDirection,
      receiveDirection: isHost ? clientToHostDirection : hostToClientDirection,
    );
  }

  Future<EncryptedEnvelope> encryptJson(
    Map<String, dynamic> payload, {
    required String endpoint,
    required String context,
  }) {
    return _sendLock.synchronized(() async {
      final counter = ++_sendCounter;
      final nonce = _nonceForCounter(counter);
      final additionalData = _additionalData(
        direction: _sendDirection,
        endpoint: endpoint,
        context: context,
        counter: counter,
      );
      final box = await _cipher.encrypt(
        utf8.encode(jsonEncode(payload)),
        secretKey: _sendKey,
        nonce: nonce,
        aad: additionalData,
      );
      return EncryptedEnvelope(
        counter: counter,
        context: context,
        nonceBase64: base64UrlEncode(box.nonce).replaceAll('=', ''),
        cipherTextBase64: base64UrlEncode(box.cipherText).replaceAll('=', ''),
        macBase64: base64UrlEncode(box.mac.bytes).replaceAll('=', ''),
      );
    });
  }

  Future<Map<String, dynamic>> decryptJson(
    EncryptedEnvelope envelope, {
    required String endpoint,
  }) {
    return _receiveLock.synchronized(() async {
      if (envelope.counter <= _lastReceivedCounter) {
        throw StateError('replayed_envelope');
      }
      final expectedNonce = _nonceForCounter(envelope.counter);
      final receivedNonce = _decodeBase64(envelope.nonceBase64);
      if (!_constantTimeEquals(expectedNonce, receivedNonce)) {
        throw StateError('invalid_envelope_nonce');
      }
      final additionalData = _additionalData(
        direction: _receiveDirection,
        endpoint: endpoint,
        context: envelope.context,
        counter: envelope.counter,
      );
      final clearText = await _cipher.decrypt(
        SecretBox(
          _decodeBase64(envelope.cipherTextBase64),
          nonce: receivedNonce,
          mac: Mac(_decodeBase64(envelope.macBase64)),
        ),
        secretKey: _receiveKey,
        aad: additionalData,
      );
      final decoded = jsonDecode(utf8.decode(clearText));
      if (decoded is! Map) {
        throw const FormatException('Encrypted payload must be an object.');
      }
      _lastReceivedCounter = envelope.counter;
      return Map<String, dynamic>.from(decoded);
    });
  }

  List<int> _additionalData({
    required String direction,
    required String endpoint,
    required String context,
    required int counter,
  }) {
    return utf8.encode(
      jsonEncode(<String, dynamic>{
        'protocol': lanSyncProtocol,
        'securityVersion': lanSyncSecurityVersion,
        'sessionId': _sessionId,
        'direction': direction,
        'endpoint': endpoint,
        'context': context,
        'counter': counter,
      }),
    );
  }
}

List<int> _nonceForCounter(int counter) {
  final bytes = Uint8List(12);
  final data = ByteData.sublistView(bytes);
  data.setUint64(4, counter, Endian.big);
  return bytes;
}

List<int> _decodeBase64(String value) =>
    base64Url.decode(base64Url.normalize(value));

bool _constantTimeEquals(List<int> left, List<int> right) {
  if (left.length != right.length) {
    return false;
  }
  var difference = 0;
  for (var index = 0; index < left.length; index++) {
    difference |= left[index] ^ right[index];
  }
  return difference == 0;
}
