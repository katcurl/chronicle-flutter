import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/sync/lan_sync_service.dart';
import 'package:chronicle/sync/pairing_service.dart';
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
}
