import 'package:chronicle/sync/pairing_crypto.dart';
import 'package:chronicle/sync/pairing_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pairing offer survives QR encoding and decoding', () {
    final offer = PairingOffer(
      host: '192.168.1.20',
      port: 47821,
      sessionId: 'session-1',
      token: 'one-time-token',
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      hostPeer: const PairingPeer(
        deviceId: 'desktop-1',
        displayName: 'Научный компьютер',
        platform: 'windows',
        publicKey: 'public-key',
      ),
    );

    final decoded = PairingOffer.decode(offer.encode());

    expect(decoded.host, offer.host);
    expect(decoded.port, offer.port);
    expect(decoded.sessionId, offer.sessionId);
    expect(decoded.token, offer.token);
    expect(decoded.hostPeer.deviceId, offer.hostPeer.deviceId);
    expect(decoded.hostPeer.displayName, offer.hostPeer.displayName);
  });

  test('expired pairing offer is rejected', () {
    final offer = PairingOffer(
      host: '192.168.1.20',
      port: 47821,
      sessionId: 'session-expired',
      token: 'expired-token',
      expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      hostPeer: const PairingPeer(
        deviceId: 'desktop-1',
        displayName: 'Desktop',
        platform: 'windows',
        publicKey: 'public-key',
      ),
    );

    expect(() => PairingOffer.decode(offer.encode()), throwsFormatException);
  });

  test('Ed25519 identity signs and verifies pairing messages', () async {
    final crypto = PairingCrypto();
    final material = await crypto.generateKeyMaterial();
    final signature = await crypto.sign('chronicle-pairing-message', material);

    expect(
      await crypto.verify(
        message: 'chronicle-pairing-message',
        signatureBase64: signature,
        publicKeyBase64: material.publicKeyBase64,
      ),
      isTrue,
    );
    expect(
      await crypto.verify(
        message: 'changed-message',
        signatureBase64: signature,
        publicKeyBase64: material.publicKeyBase64,
      ),
      isFalse,
    );
  });

  test('confirmation code is stable and six digits', () {
    final crypto = PairingCrypto();
    final first = crypto.confirmationCode(
      sessionId: 'session',
      requestId: 'request',
      token: 'token',
      hostPublicKey: 'host',
      clientPublicKey: 'client',
    );
    final second = crypto.confirmationCode(
      sessionId: 'session',
      requestId: 'request',
      token: 'token',
      hostPublicKey: 'host',
      clientPublicKey: 'client',
    );

    expect(first, second);
    expect(first, matches(RegExp(r'^\d{6}$')));
  });
}
