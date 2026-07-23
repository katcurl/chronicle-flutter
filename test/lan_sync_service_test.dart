import 'dart:typed_data';

import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/sync/attachment_sync_models.dart';
import 'package:chronicle/sync/lan_sync_service.dart';
import 'package:chronicle/sync/pairing_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'trusted LAN exchange synchronizes both repositories and cursors',
    () async {
      final desktopRepository = InMemoryAppRepository();
      final phoneRepository = InMemoryAppRepository();
      final desktopPairing = PairingService(repository: desktopRepository);
      final phonePairing = PairingService(repository: phoneRepository);
      final desktopIdentity = await desktopPairing.ensureLocalIdentity();
      final phoneIdentity = await phonePairing.ensureLocalIdentity();

      await desktopPairing.trustPeer(phoneIdentity.peer);
      await phonePairing.trustPeer(desktopIdentity.peer);

      await desktopRepository.saveProject(
        Project(id: 'desktop-project', title: 'Desktop project', emoji: '💻'),
      );
      await phoneRepository.saveProject(
        Project(id: 'phone-project', title: 'Phone project', emoji: '📱'),
      );

      final desktopSync = LanSyncService(repository: desktopRepository);
      final phoneSync = LanSyncService(repository: phoneRepository);
      final host = await desktopSync.startHost(
        peerDeviceId: phoneIdentity.peer.deviceId,
      );
      addTearDown(host.close);

      final offer = host.offerFor('127.0.0.1');
      final report = await phoneSync.syncFromOffer(
        offer.encode(),
        expectedPeerDeviceId: desktopIdentity.peer.deviceId,
      );

      final desktopData = await desktopRepository.load();
      final phoneData = await phoneRepository.load();
      final desktopCursors = await desktopRepository.loadSyncCursors();
      final phoneCursors = await phoneRepository.loadSyncCursors();
      final desktopTrusted = await desktopRepository.loadTrustedDevices();
      final phoneTrusted = await phoneRepository.loadTrustedDevices();

      expect(
        desktopData.projects.map((project) => project.id),
        containsAll(['desktop-project', 'phone-project']),
      );
      expect(
        phoneData.projects.map((project) => project.id),
        containsAll(['desktop-project', 'phone-project']),
      );
      expect(report.sentCount, 1);
      expect(report.receivedCount, 1);
      expect(report.appliedCount, 1);
      expect(desktopCursors.single.lastSentSequence, greaterThan(0));
      expect(phoneCursors.single.lastSentSequence, greaterThan(0));
      expect(desktopTrusted.single.lastSyncAt, isNotNull);
      expect(phoneTrusted.single.lastSyncAt, isNotNull);
    },
  );

  test('second trusted exchange is idempotent', () async {
    final desktopRepository = InMemoryAppRepository();
    final phoneRepository = InMemoryAppRepository();
    final desktopPairing = PairingService(repository: desktopRepository);
    final phonePairing = PairingService(repository: phoneRepository);
    final desktopIdentity = await desktopPairing.ensureLocalIdentity();
    final phoneIdentity = await phonePairing.ensureLocalIdentity();

    await desktopPairing.trustPeer(phoneIdentity.peer);
    await phonePairing.trustPeer(desktopIdentity.peer);
    await desktopRepository.saveProject(
      Project(id: 'shared-project', title: 'Shared', emoji: '🔄'),
    );

    final desktopSync = LanSyncService(repository: desktopRepository);
    final phoneSync = LanSyncService(repository: phoneRepository);

    final firstHost = await desktopSync.startHost(
      peerDeviceId: phoneIdentity.peer.deviceId,
    );
    await phoneSync.syncFromOffer(
      firstHost.offerFor('127.0.0.1').encode(),
      expectedPeerDeviceId: desktopIdentity.peer.deviceId,
    );
    await firstHost.close();

    final secondHost = await desktopSync.startHost(
      peerDeviceId: phoneIdentity.peer.deviceId,
    );
    addTearDown(secondHost.close);
    final second = await phoneSync.syncFromOffer(
      secondHost.offerFor('127.0.0.1').encode(),
      expectedPeerDeviceId: desktopIdentity.peer.deviceId,
    );

    expect(second.sentCount, 0);
    expect(second.receivedCount, 0);
    expect(second.appliedCount, 0);
    expect((await phoneRepository.load()).projects, hasLength(1));
  });

  test(
    'trusted LAN exchange transfers attachments in both directions',
    () async {
      final desktopRepository = InMemoryAppRepository();
      final phoneRepository = InMemoryAppRepository();
      final desktopPairing = PairingService(repository: desktopRepository);
      final phonePairing = PairingService(repository: phoneRepository);
      final desktopIdentity = await desktopPairing.ensureLocalIdentity();
      final phoneIdentity = await phonePairing.ensureLocalIdentity();

      await desktopPairing.trustPeer(phoneIdentity.peer);
      await phonePairing.trustPeer(desktopIdentity.peer);

      final desktopStore = _MemoryAttachmentStore();
      final phoneStore = _MemoryAttachmentStore();
      final desktopBytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
      final phoneBytes = Uint8List.fromList(<int>[5, 6, 7]);
      final oldBytes = Uint8List.fromList(<int>[8, 9]);
      final desktopEntry = desktopStore.add(
        path: 'Attachments/desktop--a.bin',
        name: 'desktop.bin',
        bytes: desktopBytes,
      );
      final phoneEntry = phoneStore.add(
        path: 'Attachments/phone--b.bin',
        name: 'phone.bin',
        bytes: phoneBytes,
      );
      final oldEntry = desktopStore.add(
        path: 'Attachments/old--c.bin',
        name: 'old.bin',
        bytes: oldBytes,
      );
      phoneStore.addTombstone(oldEntry);

      final desktopSync = LanSyncService(
        repository: desktopRepository,
        buildAttachmentManifest: desktopStore.buildManifest,
        readAttachment: desktopStore.read,
        storeAttachment: desktopStore.store,
        applyAttachmentRecord: desktopStore.applyRecord,
        applyAttachmentTombstone: desktopStore.applyTombstone,
      );
      final phoneSync = LanSyncService(
        repository: phoneRepository,
        buildAttachmentManifest: phoneStore.buildManifest,
        readAttachment: phoneStore.read,
        storeAttachment: phoneStore.store,
        applyAttachmentRecord: phoneStore.applyRecord,
        applyAttachmentTombstone: phoneStore.applyTombstone,
      );
      final host = await desktopSync.startHost(
        peerDeviceId: phoneIdentity.peer.deviceId,
      );
      addTearDown(host.close);

      final report = await phoneSync.syncFromOffer(
        host.offerFor('127.0.0.1').encode(),
        expectedPeerDeviceId: desktopIdentity.peer.deviceId,
      );

      expect(phoneStore.bytes[desktopEntry.relativePath], desktopBytes);
      expect(desktopStore.bytes[phoneEntry.relativePath], phoneBytes);
      expect(desktopStore.bytes.containsKey(oldEntry.relativePath), isFalse);
      expect(desktopStore.entries[oldEntry.relativePath]!.isDeleted, isTrue);
      expect(report.attachmentFilesReceived, 1);
      expect(report.attachmentFilesSent, 1);
      expect(report.attachmentBytesReceived, desktopBytes.length);
      expect(report.attachmentBytesSent, phoneBytes.length);
      expect(report.attachmentConflictCount, 0);
      expect(report.hasPendingAttachmentWork, isFalse);
    },
  );
}

class _MemoryAttachmentStore {
  final Map<String, AttachmentSyncEntry> entries =
      <String, AttachmentSyncEntry>{};
  final Map<String, Uint8List> bytes = <String, Uint8List>{};

  AttachmentSyncEntry add({
    required String path,
    required String name,
    required Uint8List bytes,
  }) {
    final entry = AttachmentSyncEntry(
      relativePath: path,
      originalName: name,
      sha256: sha256.convert(bytes).toString(),
      mimeType: 'application/octet-stream',
      byteLength: bytes.length,
      createdAt: DateTime.utc(2026, 7, 18, 10),
    );
    entries[path] = entry;
    this.bytes[path] = Uint8List.fromList(bytes);
    return entry;
  }

  void addTombstone(AttachmentSyncEntry source) {
    entries[source.relativePath] = AttachmentSyncEntry(
      relativePath: source.relativePath,
      originalName: source.originalName,
      sha256: source.sha256,
      mimeType: source.mimeType,
      byteLength: source.byteLength,
      createdAt: source.createdAt,
      deletedAt: DateTime.utc(2026, 7, 18, 12),
    );
    bytes.remove(source.relativePath);
  }

  Future<AttachmentSyncManifest> buildManifest() async {
    final sorted =
        entries.values.toList()..sort(
          (left, right) => left.relativePath.compareTo(right.relativePath),
        );
    return AttachmentSyncManifest(
      generatedAt: DateTime.now().toUtc(),
      entries: sorted,
    );
  }

  Future<Uint8List?> read(AttachmentSyncEntry entry) async {
    final value = bytes[entry.relativePath];
    return value == null ? null : Uint8List.fromList(value);
  }

  Future<AttachmentSyncApplyResult> store(
    AttachmentSyncEntry entry,
    Uint8List value,
  ) async {
    entries[entry.relativePath] = entry;
    bytes[entry.relativePath] = Uint8List.fromList(value);
    return AttachmentSyncApplyResult(changed: true, byteLength: value.length);
  }

  Future<AttachmentSyncApplyResult> applyRecord(
    AttachmentSyncEntry entry,
  ) async {
    for (final candidate in entries.values) {
      if (!candidate.isDeleted &&
          candidate.sha256 == entry.sha256 &&
          candidate.byteLength == entry.byteLength) {
        final source = bytes[candidate.relativePath];
        if (source != null) {
          entries[entry.relativePath] = entry;
          bytes[entry.relativePath] = Uint8List.fromList(source);
          return AttachmentSyncApplyResult(
            changed: true,
            byteLength: source.length,
          );
        }
      }
    }
    throw StateError('Missing deduplicated attachment.');
  }

  Future<AttachmentSyncApplyResult> applyTombstone(
    AttachmentSyncEntry entry,
  ) async {
    entries[entry.relativePath] = entry;
    bytes.remove(entry.relativePath);
    return const AttachmentSyncApplyResult(changed: true);
  }
}
