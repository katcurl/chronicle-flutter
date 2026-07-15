import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

import 'pairing_models.dart';

class PairingCrypto {
  PairingCrypto({Ed25519? algorithm}) : _algorithm = algorithm ?? Ed25519();

  final Ed25519 _algorithm;
  final Random _random = Random.secure();

  Future<DeviceKeyMaterial> generateKeyMaterial() async {
    final pair = await _algorithm.newKeyPair();
    final data = await pair.extract();
    return DeviceKeyMaterial(
      privateKeyBase64: base64UrlEncode(data.bytes),
      publicKeyBase64: base64UrlEncode(data.publicKey.bytes),
      createdAt: DateTime.now(),
    );
  }

  Future<String> sign(String message, DeviceKeyMaterial keyMaterial) async {
    final pair = SimpleKeyPairData(
      base64Url.decode(base64Url.normalize(keyMaterial.privateKeyBase64)),
      publicKey: SimplePublicKey(
        base64Url.decode(base64Url.normalize(keyMaterial.publicKeyBase64)),
        type: KeyPairType.ed25519,
      ),
      type: KeyPairType.ed25519,
    );
    final signature = await _algorithm.sign(
      utf8.encode(message),
      keyPair: pair,
    );
    return base64UrlEncode(signature.bytes);
  }

  Future<bool> verify({
    required String message,
    required String signatureBase64,
    required String publicKeyBase64,
  }) async {
    try {
      final signature = Signature(
        base64Url.decode(base64Url.normalize(signatureBase64)),
        publicKey: SimplePublicKey(
          base64Url.decode(base64Url.normalize(publicKeyBase64)),
          type: KeyPairType.ed25519,
        ),
      );
      return _algorithm.verify(utf8.encode(message), signature: signature);
    } on Object {
      return false;
    }
  }

  String randomToken([int byteLength = 24]) {
    final bytes = List<int>.generate(byteLength, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  String confirmationCode({
    required String sessionId,
    required String requestId,
    required String token,
    required String hostPublicKey,
    required String clientPublicKey,
  }) {
    final digest = sha256.convert(
      utf8.encode(
        '$pairingProtocol\n$sessionId\n$requestId\n$token\n'
        '$hostPublicKey\n$clientPublicKey',
      ),
    );
    var value = 0;
    for (final byte in digest.bytes.take(6)) {
      value = ((value << 8) | byte) & 0x7FFFFFFF;
    }
    return (value % 1000000).toString().padLeft(6, '0');
  }
}
