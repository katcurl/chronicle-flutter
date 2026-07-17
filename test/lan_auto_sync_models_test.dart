import 'dart:convert';

import 'package:chronicle/sync/lan_auto_sync_models.dart';
import 'package:chronicle/sync/pairing_crypto.dart';
import 'package:chronicle/sync/pairing_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const peer = PairingPeer(
    deviceId: 'desktop-id',
    displayName: 'Desktop',
    platform: 'windows',
    publicKey: 'desktop-public-key',
  );

  test('discovery announcement survives JSON round-trip', () {
    final announcement = LanDiscoveryAnnouncement(
      peer: peer,
      httpPort: 45454,
      sentAt: DateTime.utc(2026, 7, 17, 12, 30),
      nonce: 'nonce-1',
      signature: 'signature-1',
    );

    final restored = LanDiscoveryAnnouncement.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(jsonEncode(announcement.toJson())) as Map,
      ),
    );

    expect(restored.peer.deviceId, peer.deviceId);
    expect(restored.httpPort, 45454);
    expect(restored.nonce, 'nonce-1');
    expect(restored.signingPayload, announcement.signingPayload);
  });

  test('automatic offer request can be signed and verified', () async {
    final crypto = PairingCrypto();
    final keys = await crypto.generateKeyMaterial();
    final signingPeer = PairingPeer(
      deviceId: 'phone-id',
      displayName: 'Phone',
      platform: 'android',
      publicKey: keys.publicKeyBase64,
    );
    final unsigned = LanAutoSyncOfferRequest(
      requestId: 'request-1',
      targetDeviceId: 'desktop-id',
      sentAt: DateTime.utc(2026, 7, 17, 13),
      peer: signingPeer,
      signature: '',
    );
    final signature = await crypto.sign(unsigned.signingPayload, keys);
    final signed = LanAutoSyncOfferRequest(
      requestId: unsigned.requestId,
      targetDeviceId: unsigned.targetDeviceId,
      sentAt: unsigned.sentAt,
      peer: unsigned.peer,
      signature: signature,
    );

    final valid = await crypto.verify(
      message: signed.signingPayload,
      signatureBase64: signed.signature,
      publicKeyBase64: signingPeer.publicKey,
    );

    expect(valid, isTrue);
  });

  test('discovered peer expires after the online window', () {
    final now = DateTime(2026, 7, 17, 14);
    final peerState = LanDiscoveredPeer(
      peer: peer,
      host: '192.168.1.25',
      port: 40404,
      lastSeenAt: now,
    );

    expect(peerState.isOnlineAt(now.add(const Duration(seconds: 17))), isTrue);
    expect(peerState.isOnlineAt(now.add(const Duration(seconds: 19))), isFalse);
    expect(peerState.endpoint, '192.168.1.25:40404');
  });
}
