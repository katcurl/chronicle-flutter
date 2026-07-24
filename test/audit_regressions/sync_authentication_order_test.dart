import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chronicle/sync/attachment_sync_models.dart';
import 'package:chronicle/sync/lan_sync_models.dart';
import 'package:chronicle/sync/lan_sync_transport.dart';
import 'package:chronicle/sync/pairing_crypto.dart';
import 'package:chronicle/sync/pairing_models.dart';
import 'package:chronicle/sync/sync_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'an endpoint without the trusted host key receives no local data',
    () async {
      final crypto = PairingCrypto();
      final clientKeys = await crypto.generateKeyMaterial();
      final trustedHostKeys = await crypto.generateKeyMaterial();
      final client = LocalPairingIdentity(
        peer: PairingPeer(
          deviceId: 'client-device',
          displayName: 'Client',
          platform: 'test',
          publicKey: clientKeys.publicKeyBase64,
        ),
        keyMaterial: clientKeys,
      );
      final trustedHost = PairingPeer(
        deviceId: 'trusted-host',
        displayName: 'Trusted host',
        platform: 'test',
        publicKey: trustedHostKeys.publicKeyBase64,
      );

      final receivedBodies = <String>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final subscription = server.listen((request) async {
        receivedBodies.add(await utf8.decoder.bind(request).join());
        request.response.statusCode = HttpStatus.forbidden;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, dynamic>{'error': 'invalid_signature'}),
        );
        await request.response.close();
      });
      addTearDown(subscription.cancel);

      var journalReads = 0;
      var manifestReads = 0;
      final offer = LanSyncOffer(
        host: InternetAddress.loopbackIPv4.address,
        port: server.port,
        sessionId: 'forged-session',
        expiresAt: DateTime.now().add(const Duration(minutes: 1)),
        hostPeer: trustedHost,
        targetDeviceId: client.peer.deviceId,
        hostEphemeralX25519PublicKey: 'forged-ephemeral-key',
        signature: 'forged-signature',
      );

      await expectLater(
        LanSyncClient.sync(
          offer: offer,
          local: client,
          trustedHost: trustedHost,
          crypto: crypto,
          buildOutgoing: (_, afterSequence, _) async {
            journalReads += 1;
            return SyncJournalBatch(
              afterSequence: afterSequence,
              throughSequence: afterSequence + 1,
              changes: <ChangeRecord>[
                ChangeRecord(
                  localSequence: afterSequence + 1,
                  changeId: 'secret-change',
                  entityType: 'note',
                  entityId: 'secret-note',
                  operation: 'upsert',
                  revision: 1,
                  originDeviceId: client.peer.deviceId,
                  changedAt: DateTime.now(),
                  payloadJson: jsonEncode(<String, dynamic>{
                    'title': 'PRIVATE JOURNAL SENTINEL',
                  }),
                ),
              ],
              hasMore: false,
            );
          },
          applyIncoming: (_) async => _emptyApplyResult,
          loadCursor:
              (_) async => SyncCursor(peerDeviceId: trustedHost.deviceId),
          saveCursor: (_) async {},
          markSuccess: (_, _) async {},
          buildAttachmentManifest: () async {
            manifestReads += 1;
            return AttachmentSyncManifest(
              entries: <AttachmentSyncEntry>[
                AttachmentSyncEntry(
                  relativePath: 'Attachments/private--12345678.bin',
                  originalName: 'PRIVATE ATTACHMENT SENTINEL.bin',
                  sha256: 'a' * 64,
                  mimeType: 'application/octet-stream',
                  byteLength: 4,
                  createdAt: DateTime.now(),
                ),
              ],
            );
          },
          readAttachment: (_) async => Uint8List.fromList(<int>[1, 2, 3, 4]),
          storeAttachment:
              (_, _) async => const AttachmentSyncApplyResult.unchanged(),
          applyAttachmentRecord:
              (_) async => const AttachmentSyncApplyResult.unchanged(),
          applyAttachmentTombstone:
              (_) async => const AttachmentSyncApplyResult.unchanged(),
          localNetworkOnly: false,
        ),
        throwsA(isA<StateError>()),
      );

      expect(journalReads, 0);
      expect(manifestReads, 0);
      expect(receivedBodies, isEmpty);
    },
  );
}

const _emptyApplyResult = SyncApplyResult(
  receivedCount: 0,
  insertedCount: 0,
  appliedCount: 0,
  duplicateCount: 0,
  staleCount: 0,
  unsupportedCount: 0,
);
