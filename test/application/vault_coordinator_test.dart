import 'package:chronicle/application/vault/vault_coordinator.dart';
import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/vault/vault_models.dart';
import 'package:chronicle/vault/vault_revision.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'vault coordinator owns busy and scan state around mirror writes',
    () async {
      final service = _RecordingVaultService();
      final repository = InMemoryAppRepository();
      var busy = false;
      var notifications = 0;
      final coordinator = VaultCoordinator(
        repository: repository,
        vaultService: service,
        currentData: AppData.empty,
        currentIdentity: () => null,
        isBusy: () => busy,
        setBusy: (value) => busy = value,
        rebuildAllNoteLinks: () async {},
        refreshSyncFoundation: () async {},
        onEmergencyBackupCreated: (_) {},
        onAttachmentRefresh: () {},
        notifyListeners: () => notifications++,
      );
      addTearDown(coordinator.dispose);

      await coordinator.writeMirror();

      expect(service.writeCount, 1);
      expect(service.scanCount, 1);
      expect(coordinator.pendingScan?.hasChanges, isFalse);
      expect(coordinator.status.pendingChangeCount, 0);
      expect(busy, isFalse);
      expect(notifications, 2);
    },
  );
}

final class _RecordingVaultService extends VaultService {
  int writeCount = 0;
  int scanCount = 0;

  @override
  Future<VaultStatus> writeMirror(AppData data, {bool force = false}) async {
    writeCount++;
    return const VaultStatus(
      supported: true,
      rootPath: '/vault',
      noteCount: 0,
      fileCount: 0,
    );
  }

  @override
  Future<VaultScanResult> scan(AppData database) async {
    scanCount++;
    return VaultScanResult(
      rootPath: '/vault',
      scannedAt: DateTime.utc(2026, 7, 24),
      changes: const <VaultNoteChange>[],
      missingFiles: const <VaultMissingFile>[],
      revision: VaultRevision.empty(),
    );
  }
}
