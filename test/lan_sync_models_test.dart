import 'dart:convert';

import 'package:chronicle/sync/attachment_sync_models.dart';
import 'package:chronicle/sync/lan_sync_models.dart';
import 'package:chronicle/sync/pairing_models.dart';
import 'package:chronicle/sync/sync_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LAN sync offer survives URI round-trip', () {
    final offer = LanSyncOffer(
      host: '192.168.1.25',
      port: 42424,
      sessionId: 'session-1',
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      hostPeer: const PairingPeer(
        deviceId: 'desktop-id',
        displayName: 'Desktop',
        platform: 'windows',
        publicKey: 'desktop-key',
      ),
      targetDeviceId: 'phone-id',
      hostEphemeralX25519PublicKey: 'ephemeral-key',
      signature: 'signature',
    );

    final restored = LanSyncOffer.decode(offer.encode());

    expect(restored.host, offer.host);
    expect(restored.port, offer.port);
    expect(restored.hostPeer.deviceId, 'desktop-id');
    expect(restored.targetDeviceId, 'phone-id');
  });

  test('legacy cleartext LAN offers cannot downgrade secure sync', () {
    final legacy = base64Url
        .encode(
          utf8.encode(
            jsonEncode(<String, dynamic>{
              'protocol': 'chronicle-sync-v3',
              'host': '127.0.0.1',
              'port': 42424,
            }),
          ),
        )
        .replaceAll('=', '');

    expect(
      () => LanSyncOffer.decode('chronicle://sync/$legacy'),
      throwsA(isA<FormatException>()),
    );
  });

  test('signed exchange payload keeps journal batch and apply counters', () {
    final change = ChangeRecord(
      localSequence: 7,
      changeId: 'change-7',
      entityType: 'project',
      entityId: 'project-7',
      operation: 'upsert',
      revision: 2,
      originDeviceId: 'desktop-id',
      changedAt: DateTime.utc(2026, 7, 16, 12),
      payloadJson: jsonEncode({'id': 'project-7', 'title': 'Project'}),
    );
    final response = LanSyncExchangeResponse(
      sessionId: 'session',
      roundId: 'round',
      hostPeer: const PairingPeer(
        deviceId: 'desktop-id',
        displayName: 'Desktop',
        platform: 'windows',
        publicKey: 'desktop-key',
      ),
      batch: SyncJournalBatch(
        afterSequence: 3,
        throughSequence: 7,
        changes: [change],
        hasMore: false,
      ),
      remoteApplyResult: const SyncApplyResult(
        receivedCount: 2,
        insertedCount: 2,
        appliedCount: 1,
        duplicateCount: 0,
        staleCount: 1,
        unsupportedCount: 0,
      ),
      attachmentManifest: AttachmentSyncManifest(
        generatedAt: DateTime.utc(2026, 7, 16, 12),
        entries: <AttachmentSyncEntry>[
          AttachmentSyncEntry(
            relativePath: 'Attachments/protocol--aaaaaaaa.pdf',
            originalName: 'protocol.pdf',
            sha256:
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            mimeType: 'application/pdf',
            byteLength: 42,
            createdAt: DateTime.utc(2026, 7, 16, 10),
          ),
        ],
      ),
      requesterAttachmentPlan: AttachmentSyncPlan(
        files: <AttachmentSyncEntry>[
          AttachmentSyncEntry(
            relativePath: 'Attachments/protocol--aaaaaaaa.pdf',
            originalName: 'protocol.pdf',
            sha256:
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            mimeType: 'application/pdf',
            byteLength: 42,
            createdAt: DateTime.utc(2026, 7, 16, 10),
          ),
        ],
      ),
      signature: 'signature',
    );

    final restored = LanSyncExchangeResponse.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(jsonEncode(response.toJson())) as Map,
      ),
    );

    expect(restored.batch.throughSequence, 7);
    expect(restored.batch.changes.single.changeId, 'change-7');
    expect(restored.remoteApplyResult.appliedCount, 1);
    expect(restored.remoteApplyResult.staleCount, 1);
    expect(restored.attachmentManifest.activeCount, 1);
    expect(restored.requesterAttachmentPlan.fileCount, 1);
  });
}
