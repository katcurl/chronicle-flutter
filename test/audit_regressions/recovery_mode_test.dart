import 'dart:io';

import 'package:chronicle/data/backup/staged_restore.dart';
import 'package:chronicle/data/database/chronicle_database.dart';
import 'package:chronicle/data/repositories/drift_app_repository.dart';
import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/main.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/recovery/recovery_models.dart';
import 'package:chronicle/recovery/recovery_service.dart';
import 'package:chronicle/recovery/recovery_storage_contract.dart';
import 'package:chronicle/recovery/recovery_storage_io.dart';
import 'package:chronicle/services/app_store.dart';
import 'package:chronicle/vault/vault_models.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test(
    'startup inspection reads malformed state without changing SQLite',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'chronicle-recovery-readonly-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final databaseFile = File('${directory.path}/chronicle.sqlite');
      final database = sqlite.sqlite3.open(databaseFile.path);
      database
        ..execute('CREATE TABLE app_state (key TEXT PRIMARY KEY, value TEXT)')
        ..execute('INSERT INTO app_state (key, value) VALUES (?, ?)', <Object?>[
          'active_timer',
          '{"startedAt":',
        ])
        ..execute('PRAGMA user_version = 5')
        ..close();
      final beforeBytes = await databaseFile.readAsBytes();
      final beforeModified = (await databaseFile.stat()).modified;
      final storage = IoRecoveryStorage(
        databasePathResolver: () async => databaseFile.path,
      );

      final probe = await storage.inspectActiveDatabase();

      expect(probe.blockingProblems, isNotEmpty);
      expect(
        probe.blockingProblems.single.code,
        'malformed-state-active_timer',
      );
      expect(await databaseFile.readAsBytes(), beforeBytes);
      expect((await databaseFile.stat()).modified, beforeModified);
      expect(await File('${databaseFile.path}-wal').exists(), isFalse);
      expect(await File('${databaseFile.path}-shm').exists(), isFalse);
    },
  );

  test(
    'inspection reports restore and attachment blockers without writes',
    () async {
      final storage = _RecordingRecoveryStorage(
        probe: const RecoveryDatabaseProbe(
          path: '/data/chronicle.sqlite',
          exists: true,
          byteLength: 4096,
          schemaVersion: 5,
          generation: 'active-generation',
          quickCheckHealthy: true,
          blockingProblems: <RecoveryProblem>[
            RecoveryProblem(
              code: 'migration-failed',
              message: 'Не удалось применить миграцию.',
            ),
          ],
        ),
      );
      final vault = _RecordingVaultService(
        marker: StagedRestoreMarker(
          restoreId: 'restore-id',
          phase: StagedRestorePhase.committing,
          oldGeneration: 'old-generation',
          newGeneration: 'new-generation',
          oldAttachmentsExisted: true,
          oldAttachmentIndexExisted: true,
          expectedSha256ByPath: <String, String>{
            '.chronicle/attachments-index.json': 'a' * 64,
          },
        ),
        attachmentReport: AttachmentIntegrityReport(
          rootPath: '/vault',
          checkedAt: DateTime.utc(2026, 7, 24),
          issues: const <AttachmentIntegrityIssue>[
            AttachmentIntegrityIssue(
              kind: AttachmentIntegrityIssueKind.orphanBinary,
              relativePath: 'Attachments/orphan.png',
            ),
          ],
        ),
      );
      final service = RecoveryService(storage: storage, vaultService: vault);

      final inspection = await service.inspectForStartup();

      expect(inspection.hasBlockingProblems, isTrue);
      expect(
        inspection.candidates.map((candidate) => candidate.kind),
        containsAll(<RecoveryCandidateKind>[
          RecoveryCandidateKind.activeDatabase,
          RecoveryCandidateKind.stagedRestore,
          RecoveryCandidateKind.attachmentIntegrity,
        ]),
      );
      expect(storage.mutationCount, 0);
      expect(vault.mutationCount, 0);
    },
  );

  test(
    'validated database is atomically published and old SQLite is archived',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'chronicle-recovery-install-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final databaseFile = File('${directory.path}/chronicle.sqlite');
      final originalRepository = DriftAppRepository(
        database: ChronicleDatabase(NativeDatabase(databaseFile)),
      );
      await originalRepository.replaceAllForRestore(
        AppData.empty(),
        generation: 'old-generation',
      );
      await originalRepository.close();
      final replacement = AppData(
        projects: <Project>[
          Project(id: 'project-1', title: 'Recovered', emoji: 'R'),
        ],
        tasks: <WorkTask>[],
        notes: <Note>[],
        entries: <TimeEntry>[],
      );
      final storage = IoRecoveryStorage(
        databasePathResolver: () async => databaseFile.path,
      );

      await storage.installDatabase(replacement, generation: 'new-generation');

      final probe = await storage.inspectActiveDatabase();
      expect(probe.isHealthy, isTrue);
      expect(probe.generation, 'new-generation');
      final repository = DriftAppRepository(
        database: ChronicleDatabase(NativeDatabase(databaseFile)),
      );
      expect((await repository.load()).projects.single.title, 'Recovered');
      await repository.close();
      final archives = await storage.listDatabaseArchives();
      expect(archives, hasLength(1));
      expect(archives.single.generation, 'old-generation');
    },
  );

  testWidgets('startup failure opens recovery UI without raw exception text', (
    tester,
  ) async {
    final store = AppStore(
      repository: _FailingOpenRepository(),
      vaultService: _RecordingVaultService(),
    );

    await tester.pumpWidget(
      ChronicleApp(store: store, recoveryService: RecoveryService.disabled()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Режим восстановления Chronicle'), findsOneWidget);
    expect(find.textContaining('RAW_PRIVATE_STACK'), findsNothing);
    expect(find.text('Повторить безопасную проверку'), findsOneWidget);
    expect(find.text('Экспортировать базу и журнал'), findsOneWidget);
    expect(find.text('Инструкция по восстановлению'), findsOneWidget);
  });

  test('only a validated backup candidate can replace the database', () async {
    final data = AppData(
      projects: <Project>[
        Project(id: 'project-1', title: 'Recovered', emoji: 'R'),
      ],
      tasks: <WorkTask>[],
      notes: <Note>[],
      entries: <TimeEntry>[],
    );
    final entry = BackupCatalogEntry(
      path: '/vault/Automatic/backup.chronicle',
      fileName: 'backup.chronicle',
      modifiedAt: DateTime.utc(2026, 7, 24),
      byteLength: 100,
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
    final storage = _RecordingRecoveryStorage(
      probe: const RecoveryDatabaseProbe(
        path: '/data/chronicle.sqlite',
        exists: true,
        byteLength: 4096,
        schemaVersion: 5,
        generation: 'old-generation',
        quickCheckHealthy: true,
        blockingProblems: <RecoveryProblem>[],
      ),
    );
    final vault = _RecordingVaultService(
      backups: <BackupCatalogEntry>[entry],
      payload: BackupImportPayload(
        databaseJson: data.encode(),
        preview: entry.preview!,
        sourceName: entry.fileName,
      ),
    );
    final service = RecoveryService(storage: storage, vaultService: vault);
    final candidate = (await service.inspect()).candidates.singleWhere(
      (item) => item.kind == RecoveryCandidateKind.automaticBackup,
    );

    await service.restoreCandidate(candidate);

    expect(storage.installedData?.projects.single.title, 'Recovered');
    expect(storage.installedGeneration, isNot('old-generation'));
    expect(vault.stageCount, 1);
    expect(vault.commitCount, 1);
    expect(vault.finalizeCount, 1);

    await expectLater(
      service.restoreCandidate(
        const RecoveryCandidate(
          id: 'invalid',
          kind: RecoveryCandidateKind.automaticBackup,
          title: 'Invalid',
          description: 'Invalid',
          severity: RecoverySeverity.warning,
          canRestore: false,
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });
}

final class _FailingOpenRepository extends InMemoryAppRepository {
  @override
  Future<bool> isInitialized() {
    throw StateError('RAW_PRIVATE_STACK database open failed');
  }
}

final class _RecordingRecoveryStorage implements RecoveryStorage {
  _RecordingRecoveryStorage({required this.probe});

  RecoveryDatabaseProbe probe;
  int mutationCount = 0;
  AppData? installedData;
  String? installedGeneration;

  @override
  Future<String> exportRawDatabase({required String diagnosticsJson}) async {
    mutationCount++;
    return '/export';
  }

  @override
  Future<RecoveryDatabaseProbe> inspectActiveDatabase() async => probe;

  @override
  Future<List<RecoveryDatabaseArchive>> listDatabaseArchives() async =>
      const <RecoveryDatabaseArchive>[];

  @override
  Future<void> installDatabase(
    AppData data, {
    required String generation,
  }) async {
    mutationCount++;
    installedData = AppData.decode(data.encode());
    installedGeneration = generation;
    probe = RecoveryDatabaseProbe(
      path: probe.path,
      exists: true,
      byteLength: probe.byteLength,
      schemaVersion: probe.schemaVersion,
      generation: generation,
      quickCheckHealthy: true,
      blockingProblems: const <RecoveryProblem>[],
    );
  }
}

final class _RecordingVaultService extends VaultService {
  _RecordingVaultService({
    this.marker,
    this.attachmentReport,
    this.backups = const <BackupCatalogEntry>[],
    this.payload,
  });

  StagedRestoreMarker? marker;
  final AttachmentIntegrityReport? attachmentReport;
  final List<BackupCatalogEntry> backups;
  final BackupImportPayload? payload;
  int mutationCount = 0;
  int stageCount = 0;
  int commitCount = 0;
  int finalizeCount = 0;

  @override
  Future<StagedRestoreMarker?> readStagedRestoreMarker() async => marker;

  @override
  Future<AttachmentIntegrityReport> inspectAttachmentIntegrity() async {
    return attachmentReport ??
        AttachmentIntegrityReport(
          rootPath: '/vault',
          checkedAt: DateTime.utc(2026, 7, 24),
          issues: const <AttachmentIntegrityIssue>[],
        );
  }

  @override
  Future<List<BackupCatalogEntry>> listRecoveryBackups() async => backups;

  @override
  Future<BackupImportPayload> loadRecoveryBackup(
    BackupCatalogEntry entry,
  ) async {
    return payload!;
  }

  @override
  AppData validateBackupPayload(BackupImportPayload payload) {
    return AppData.decode(payload.databaseJson);
  }

  @override
  Future<StagedRestoreMarker> stageRestoreAttachments({
    required BackupImportPayload payload,
    required String restoreId,
    required String oldGeneration,
    required String newGeneration,
  }) async {
    mutationCount++;
    stageCount++;
    return marker = StagedRestoreMarker(
      restoreId: restoreId,
      phase: StagedRestorePhase.staged,
      oldGeneration: oldGeneration,
      newGeneration: newGeneration,
      oldAttachmentsExisted: false,
      oldAttachmentIndexExisted: false,
      expectedSha256ByPath: <String, String>{
        '.chronicle/attachments-index.json': 'b' * 64,
      },
    );
  }

  @override
  Future<StagedRestoreMarker> updateStagedRestorePhase(
    StagedRestoreMarker marker,
    StagedRestorePhase phase,
  ) async {
    mutationCount++;
    return this.marker = marker.copyWith(phase: phase);
  }

  @override
  Future<void> commitStagedRestoreAttachments(
    StagedRestoreMarker marker,
  ) async {
    mutationCount++;
    commitCount++;
  }

  @override
  Future<void> finalizeStagedRestore(StagedRestoreMarker marker) async {
    mutationCount++;
    finalizeCount++;
    this.marker = null;
  }

  @override
  Future<StagedRestoreMarker?> recoverStagedRestore(
    String currentGeneration,
  ) async {
    mutationCount++;
    return marker;
  }
}
