import 'dart:io';
import 'dart:typed_data';

import 'package:chronicle/data/backup/staged_restore.dart';
import 'package:chronicle/data/database/chronicle_database.dart';
import 'package:chronicle/data/repositories/drift_app_repository.dart';
import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/services/app_store.dart';
import 'package:chronicle/vault/vault_backend.dart';
import 'package:chronicle/vault/vault_models.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final cutPoint in RestoreCutPoint.values) {
    test(
      'restart at ${cutPoint.name} exposes one complete generation',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'chronicle-restore-cutpoint-',
        );
        addTearDown(() async {
          if (await root.exists()) {
            await root.delete(recursive: true);
          }
        });
        final repository = InMemoryAppRepository(initialData: _oldData());
        await repository.markInitialized();
        final service = VaultService(backend: _RootVaultBackend(root));
        final interruptedStore = AppStore(
          repository: repository,
          vaultService: service,
          restoreCutPoint: (current) async {
            if (current == cutPoint) {
              throw RestoreInterruption(current);
            }
          },
        );
        await interruptedStore.load();
        expect(interruptedStore.loadError, isNull);
        final oldAttachment = await service.storeAttachmentBytes(
          note: interruptedStore.data.notes.single,
          originalName: 'old.txt',
          bytes: Uint8List.fromList('old-attachment'.codeUnits),
        );
        final payload = _candidatePayload();

        await expectLater(
          interruptedStore.restoreBackupFile(payload),
          throwsA(
            isA<RestoreInterruption>().having(
              (error) => error.point,
              'point',
              cutPoint,
            ),
          ),
        );
        interruptedStore.dispose();

        final recoveredStore = AppStore(
          repository: repository,
          vaultService: service,
        );
        addTearDown(recoveredStore.dispose);
        await recoveredStore.load();

        expect(recoveredStore.loadError, isNull);
        final committed =
            cutPoint.index >= RestoreCutPoint.afterDatabaseCommit.index;
        expect(
          recoveredStore.data.projects.single.title,
          committed ? 'New project' : 'Old project',
        );
        expect(
          recoveredStore.data.notes.single.body,
          committed ? 'new database' : 'old database',
        );
        final catalog = await service.listAttachmentCatalog();
        expect(catalog, hasLength(1));
        expect(
          catalog.single.relativePath,
          committed ? 'Attachments/new.bin' : oldAttachment.relativePath,
        );
        final bytes = await service.readManagedAttachment(
          catalog.single.relativePath,
        );
        expect(
          String.fromCharCodes(bytes!),
          committed ? 'new-attachment' : 'old-attachment',
        );
        expect(await service.readStagedRestoreMarker(), isNull);
      },
    );
  }

  test(
    'SQLite reopen completes a restore committed before process death',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'chronicle-restore-sqlite-',
      );
      addTearDown(() async {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });
      final databaseFile = File('${root.path}/chronicle.sqlite');
      final firstRepository = DriftAppRepository(
        database: ChronicleDatabase(NativeDatabase(databaseFile)),
      );
      await firstRepository.replaceAll(_oldData());
      await firstRepository.markInitialized();
      final service = VaultService(backend: _RootVaultBackend(root));
      final firstStore = AppStore(
        repository: firstRepository,
        vaultService: service,
        restoreCutPoint: (point) async {
          if (point == RestoreCutPoint.afterDatabaseCommit) {
            throw RestoreInterruption(point);
          }
        },
      );
      await firstStore.load();
      await service.storeAttachmentBytes(
        note: firstStore.data.notes.single,
        originalName: 'old.txt',
        bytes: Uint8List.fromList('old-attachment'.codeUnits),
      );

      await expectLater(
        firstStore.restoreBackupFile(_candidatePayload()),
        throwsA(isA<RestoreInterruption>()),
      );
      firstStore.dispose();
      await firstRepository.close();

      final reopenedRepository = DriftAppRepository(
        database: ChronicleDatabase(NativeDatabase(databaseFile)),
      );
      addTearDown(reopenedRepository.close);
      final reopenedStore = AppStore(
        repository: reopenedRepository,
        vaultService: service,
      );
      addTearDown(reopenedStore.dispose);
      await reopenedStore.load();

      expect(reopenedStore.loadError, isNull);
      expect(reopenedStore.data.projects.single.title, 'New project');
      expect(
        String.fromCharCodes(
          (await service.readManagedAttachment('Attachments/new.bin'))!,
        ),
        'new-attachment',
      );
      expect(await service.readStagedRestoreMarker(), isNull);
    },
  );
}

AppData _oldData() => AppData(
  projects: [Project(id: 'old', title: 'Old project', emoji: '📌')],
  tasks: const [],
  notes: [
    Note(
      id: 'old-note',
      title: 'Old note',
      projectId: 'old',
      body: 'old database',
    ),
  ],
  entries: const [],
);

BackupImportPayload _candidatePayload() {
  final data = AppData(
    projects: [Project(id: 'new', title: 'New project', emoji: '🧪')],
    tasks: const [],
    notes: [
      Note(
        id: 'new-note',
        title: 'New note',
        projectId: 'new',
        body: 'new database',
      ),
    ],
    entries: const [],
  );
  final bytes = Uint8List.fromList('new-attachment'.codeUnits);
  return BackupImportPayload(
    databaseJson: data.encode(),
    preview: BackupPreview(
      formatVersion: VaultService.backupFormatVersion,
      exportedAt: DateTime.utc(2026, 7, 24),
      projectCount: 1,
      taskCount: 0,
      noteCount: 1,
      entryCount: 0,
      checksumsVerified: true,
      attachmentCount: 1,
    ),
    sourceName: 'candidate.chronicle',
    attachments: {'Attachments/new.bin': bytes},
  );
}

final class _RootVaultBackend extends VaultBackend {
  _RootVaultBackend(this.root);

  final Directory root;

  @override
  Future<String?> resolveRootPath() async => root.path;
}
