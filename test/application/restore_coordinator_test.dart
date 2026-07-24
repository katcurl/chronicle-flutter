import 'dart:io';

import 'package:chronicle/application/backup/restore_coordinator.dart';
import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/reliability/reliability_models.dart';
import 'package:chronicle/vault/vault_backend.dart';
import 'package:chronicle/vault/vault_models.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('restore coordinator owns the full checked restore lifecycle', () async {
    final root = await Directory.systemTemp.createTemp(
      'chronicle-restore-coordinator-',
    );
    addTearDown(() => root.delete(recursive: true));
    final original = AppData(
      projects: <Project>[Project(id: 'old', title: 'Old', emoji: 'O')],
      tasks: <WorkTask>[],
      notes: <Note>[],
      entries: <TimeEntry>[],
    );
    final replacement = AppData(
      projects: <Project>[Project(id: 'new', title: 'New', emoji: 'N')],
      tasks: <WorkTask>[],
      notes: <Note>[],
      entries: <TimeEntry>[],
    );
    final repository = InMemoryAppRepository(initialData: original);
    await repository.markInitialized();
    var current = original;
    var busy = false;
    var notifications = 0;
    var catalogRefreshes = 0;
    final stages = <ReliabilityStage>[];
    final coordinator = RestoreCoordinator(
      repository: repository,
      vaultService: VaultService(backend: _RootVaultBackend(root)),
      currentData: () => current,
      currentIdentity: () => null,
      isBusy: () => busy,
      setBusy: (value) => busy = value,
      reloadAfterRestore: () async => current = await repository.load(),
      refreshBackupCatalog: () async => catalogRefreshes++,
      recordReliability: ({
        required stage,
        required level,
        required message,
        details = const <String, Object?>{},
      }) async {
        stages.add(stage);
      },
      notifyListeners: () => notifications++,
    );
    final payload = BackupImportPayload(
      databaseJson: replacement.encode(),
      sourceName: 'replacement.chronicle',
      preview: BackupPreview(
        formatVersion: VaultService.backupFormatVersion,
        exportedAt: DateTime.utc(2026, 7, 24),
        projectCount: 1,
        taskCount: 0,
        noteCount: 0,
        entryCount: 0,
        checksumsVerified: true,
      ),
    );

    await coordinator.restore(payload);

    expect(current.projects.single.title, 'New');
    expect(coordinator.lastEmergencyBackupPath, isNotNull);
    expect(coordinator.lastRestoreRolledBack, isFalse);
    expect(busy, isFalse);
    expect(notifications, 2);
    expect(catalogRefreshes, 1);
    expect(stages, <ReliabilityStage>[
      ReliabilityStage.restore,
      ReliabilityStage.restore,
    ]);
  });
}

final class _RootVaultBackend extends VaultBackend {
  _RootVaultBackend(this.root);

  final Directory root;

  @override
  Future<String?> resolveRootPath() async => root.path;
}
