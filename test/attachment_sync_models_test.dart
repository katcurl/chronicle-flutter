import 'dart:convert';

import 'package:chronicle/sync/attachment_sync_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const hashA =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const hashB =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  AttachmentSyncEntry active({
    String path = 'Attachments/protocol--aaaaaaaa.pdf',
    String hash = hashA,
    DateTime? createdAt,
  }) {
    return AttachmentSyncEntry(
      relativePath: path,
      originalName: 'protocol.pdf',
      sha256: hash,
      mimeType: 'application/pdf',
      byteLength: 42,
      createdAt: createdAt ?? DateTime.utc(2026, 7, 17, 10),
    );
  }

  AttachmentSyncEntry deleted({
    String path = 'Attachments/protocol--aaaaaaaa.pdf',
    DateTime? deletedAt,
  }) {
    return AttachmentSyncEntry(
      relativePath: path,
      originalName: 'protocol.pdf',
      sha256: hashA,
      mimeType: 'application/pdf',
      byteLength: 42,
      createdAt: DateTime.utc(2026, 7, 17, 10),
      deletedAt: deletedAt ?? DateTime.utc(2026, 7, 17, 12),
    );
  }

  test('attachment manifest survives JSON round-trip', () {
    final manifest = AttachmentSyncManifest(
      generatedAt: DateTime.utc(2026, 7, 17, 14),
      entries: <AttachmentSyncEntry>[active(), deleted(path: 'Attachments/old--aaaaaaaa.pdf')],
    );

    final restored = AttachmentSyncManifest.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(jsonEncode(manifest.toJson())) as Map,
      ),
    );

    expect(restored.activeCount, 1);
    expect(restored.tombstoneCount, 1);
    expect(restored.entries.first.relativePath, startsWith('Attachments/'));
  });


  test('manifest rejects duplicate managed paths', () {
    final entry = active();

    expect(
      () => AttachmentSyncManifest.fromJson(<String, dynamic>{
        'version': attachmentSyncManifestVersion,
        'entries': <Map<String, dynamic>>[entry.toJson(), entry.toJson()],
      }),
      throwsFormatException,
    );
  });

  test('missing binary is requested from the remote manifest', () {
    final plan = buildAttachmentSyncPlan(
      local: const AttachmentSyncManifest.empty(),
      remote: AttachmentSyncManifest(entries: <AttachmentSyncEntry>[active()]),
    );

    expect(plan.fileCount, 1);
    expect(plan.recordCount, 0);
    expect(plan.tombstoneCount, 0);
  });

  test('same hash under another path avoids a second binary transfer', () {
    final plan = buildAttachmentSyncPlan(
      local: AttachmentSyncManifest(
        entries: <AttachmentSyncEntry>[
          active(path: 'Attachments/existing--aaaaaaaa.pdf'),
        ],
      ),
      remote: AttachmentSyncManifest(
        entries: <AttachmentSyncEntry>[
          active(path: 'Attachments/renamed--aaaaaaaa.pdf'),
        ],
      ),
    );

    expect(plan.fileCount, 0);
    expect(plan.recordCount, 1);
  });

  test('tombstone is planned and prevents silent resurrection', () {
    final tombstonePlan = buildAttachmentSyncPlan(
      local: AttachmentSyncManifest(entries: <AttachmentSyncEntry>[active()]),
      remote: AttachmentSyncManifest(entries: <AttachmentSyncEntry>[deleted()]),
    );
    final resurrectionPlan = buildAttachmentSyncPlan(
      local: AttachmentSyncManifest(entries: <AttachmentSyncEntry>[deleted()]),
      remote: AttachmentSyncManifest(entries: <AttachmentSyncEntry>[active()]),
    );

    expect(tombstonePlan.tombstoneCount, 1);
    expect(resurrectionPlan.fileCount, 0);
    expect(resurrectionPlan.recordCount, 0);
  });

  test('same managed path with different content is a conflict', () {
    final plan = buildAttachmentSyncPlan(
      local: AttachmentSyncManifest(entries: <AttachmentSyncEntry>[active()]),
      remote: AttachmentSyncManifest(
        entries: <AttachmentSyncEntry>[active(hash: hashB)],
      ),
    );

    expect(plan.conflictCount, 1);
    expect(plan.fileCount, 0);
  });
}
