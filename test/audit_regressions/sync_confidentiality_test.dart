import 'dart:convert';

import 'package:chronicle/sync/lan_secure_channel.dart';
import 'package:chronicle/sync/lan_sync_models.dart';
import 'package:chronicle/sync/pairing_models.dart';
import 'package:chronicle/sync/sync_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'wire payload is confidential, authenticated, and replay-safe',
    () async {
      final request = LanSyncExchangeRequest(
        sessionId: 'session',
        token: 'secret-token',
        roundId: 'round',
        peer: const PairingPeer(
          deviceId: 'client',
          displayName: 'Client',
          platform: 'test',
          publicKey: 'client-key',
        ),
        batch: SyncJournalBatch(
          afterSequence: 0,
          throughSequence: 1,
          changes: <ChangeRecord>[
            ChangeRecord(
              localSequence: 1,
              changeId: 'change',
              entityType: 'note',
              entityId: 'note',
              operation: 'upsert',
              revision: 1,
              originDeviceId: 'client',
              changedAt: DateTime.utc(2026, 7, 24),
              payloadJson: jsonEncode(<String, dynamic>{
                'title': 'PRIVATE NOTE SENTINEL',
                'body': 'PRIVATE BODY SENTINEL',
              }),
            ),
          ],
          hasMore: false,
        ),
        signature: 'signature',
      );

      final clientKeys = await LanEphemeralKeyPair.generate();
      final hostKeys = await LanEphemeralKeyPair.generate();
      final clientChannel = await LanSecureChannel.forClient(
        sessionId: 'session',
        clientKeyPair: clientKeys.keyPair,
        hostPublicKeyBase64: hostKeys.publicKeyBase64,
        transcript: 'authenticated handshake transcript',
      );
      final hostChannel = await LanSecureChannel.forHost(
        sessionId: 'session',
        hostKeyPair: hostKeys.keyPair,
        clientPublicKeyBase64: clientKeys.publicKeyBase64,
        transcript: 'authenticated handshake transcript',
      );
      final envelope = await clientChannel.encryptJson(
        request.toJson(),
        endpoint: '/v2/sync/exchange',
        context: 'round',
      );
      final wireBody = jsonEncode(envelope.toJson());

      expect(wireBody, isNot(contains('PRIVATE NOTE SENTINEL')));
      expect(wireBody, isNot(contains('PRIVATE BODY SENTINEL')));
      expect(wireBody, isNot(contains('secret-token')));
      final clearText = await hostChannel.decryptJson(
        envelope,
        endpoint: '/v2/sync/exchange',
      );
      expect(
        LanSyncExchangeRequest.fromJson(
          clearText,
        ).batch.changes.single.payload['title'],
        'PRIVATE NOTE SENTINEL',
      );
      await expectLater(
        hostChannel.decryptJson(envelope, endpoint: '/v2/sync/exchange'),
        throwsA(isA<StateError>()),
      );

      final nextEnvelope = await clientChannel.encryptJson(
        request.toJson(),
        endpoint: '/v2/sync/exchange',
        context: 'round-2',
      );
      final tampered = EncryptedEnvelope(
        counter: nextEnvelope.counter,
        context: nextEnvelope.context,
        nonceBase64: nextEnvelope.nonceBase64,
        cipherTextBase64: nextEnvelope.cipherTextBase64,
        macBase64: _tamper(nextEnvelope.macBase64),
      );
      await expectLater(
        hostChannel.decryptJson(tampered, endpoint: '/v2/sync/exchange'),
        throwsA(anything),
      );
    },
  );
}

String _tamper(String value) {
  final first = value.codeUnitAt(0) == 'A'.codeUnitAt(0) ? 'B' : 'A';
  return '$first${value.substring(1)}';
}
