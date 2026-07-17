import 'dart:convert';
import 'dart:typed_data';

import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/services/app_store.dart';
import 'package:chronicle/sync/sync_models.dart';
import 'package:chronicle/vault/vault_backend.dart';
import 'package:chronicle/vault/vault_models.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('automatic backup catalog validates every stored backup', () async {
    final backend = _CatalogBackend();
    final service = VaultService(backend: backend);
    final data = AppData(
      projects: <Project>[
        Project(id: 'project-1', title: 'Наука', emoji: '🧬'),
      ],
      tasks: <WorkTask>[],
      notes: <Note>[],
      entries: <TimeEntry>[],
    );

    await service.createAutomaticBackup(data: data);
    backend.addCorruptedBackup('corrupted.chronicle');

    final entries = await service.listAutomaticBackups();

    expect(entries, hasLength(2));
    expect(entries.where((entry) => entry.isValid), hasLength(1));
    final invalid = entries.singleWhere((entry) => !entry.isValid);
    expect(invalid.fileName, 'corrupted.chronicle');
    expect(invalid.validationError, isNotEmpty);
  });

  test(
    'attachment restore replaces stale files instead of merging them',
    () async {
      final backend = _AttachmentBackend();
      final service = VaultService(backend: backend);
      final payload = BackupImportPayload(
        databaseJson: AppData.empty().encode(),
        sourceName: 'backup.chronicle',
        preview: BackupPreview(
          formatVersion: VaultService.backupFormatVersion,
          exportedAt: DateTime.utc(2026, 7, 17),
          projectCount: 0,
          taskCount: 0,
          noteCount: 0,
          entryCount: 0,
          checksumsVerified: true,
          attachmentCount: 1,
        ),
        attachments: <String, Uint8List>{
          'Attachments/new.txt': Uint8List.fromList(utf8.encode('new')),
        },
      );

      await service.replaceAttachments(payload);

      expect(backend.files.keys.toList(), <String>['Attachments/new.txt']);
      expect(utf8.decode(backend.files['Attachments/new.txt']!), 'new');
    },
  );

  test(
    'failed restore automatically returns the previous database state',
    () async {
      final original = AppData(
        projects: <Project>[
          Project(id: 'project-1', title: 'Исходный проект', emoji: '🧬'),
        ],
        tasks: <WorkTask>[],
        notes: <Note>[],
        entries: <TimeEntry>[],
      );
      final replacement = AppData(
        projects: <Project>[
          Project(id: 'project-2', title: 'Новая копия', emoji: '📦'),
        ],
        tasks: <WorkTask>[],
        notes: <Note>[],
        entries: <TimeEntry>[],
      );
      final repository = InMemoryAppRepository(initialData: original);
      await repository.markInitialized();
      final service = _FailOnceRestoreVaultService();
      final store = AppStore(repository: repository, vaultService: service);
      addTearDown(store.dispose);
      await store.load();

      final payload = _payloadFor(replacement, 'replacement.chronicle');

      await expectLater(
        store.restoreBackupFile(payload),
        throwsA(isA<StateError>()),
      );

      expect(store.lastRestoreRolledBack, isTrue);
      expect(store.data.projects, hasLength(1));
      expect(store.data.projects.single.title, 'Исходный проект');
      expect(service.replaceCalls, 2);
    },
  );
}

BackupImportPayload _payloadFor(AppData data, String sourceName) {
  return BackupImportPayload(
    databaseJson: data.encode(),
    sourceName: sourceName,
    preview: BackupPreview(
      formatVersion: VaultService.backupFormatVersion,
      exportedAt: DateTime.utc(2026, 7, 17),
      projectCount: data.projects.length,
      taskCount: data.tasks.length,
      noteCount: data.notes.length,
      entryCount: data.entries.length,
      checksumsVerified: true,
    ),
  );
}

class _CatalogBackend extends VaultBackend {
  final Map<String, Uint8List> _files = <String, Uint8List>{};
  final Map<String, DateTime> _modified = <String, DateTime>{};

  @override
  Future<String?> resolveRootPath() async => '/vault';

  @override
  Future<Map<String, Uint8List>> listBinaryFiles({
    required String rootPath,
    required String directory,
  }) async => <String, Uint8List>{};

  @override
  Future<String> writeAutomaticBackup({
    required String rootPath,
    required String fileName,
    required Uint8List bytes,
    int maxFiles = 5,
  }) async {
    final path = '$rootPath/$fileName';
    _files[path] = bytes;
    _modified[path] = DateTime.utc(2026, 7, 17, 12);
    return path;
  }

  void addCorruptedBackup(String name) {
    final path = '/vault/$name';
    _files[path] = Uint8List.fromList(utf8.encode('{broken'));
    _modified[path] = DateTime.utc(2026, 7, 17, 13);
  }

  @override
  Future<List<VaultBackupFileInfo>> listAutomaticBackups({
    required String rootPath,
  }) async {
    final result = <VaultBackupFileInfo>[
      for (final entry in _files.entries)
        VaultBackupFileInfo(
          path: entry.key,
          name: entry.key.split('/').last,
          modifiedAt: _modified[entry.key]!,
          byteLength: entry.value.length,
        ),
    ];
    result.sort((left, right) => right.modifiedAt.compareTo(left.modifiedAt));
    return result;
  }

  @override
  Future<PickedVaultFile?> readBackupPath(String path) async {
    final bytes = _files[path];
    if (bytes == null) {
      return null;
    }
    return PickedVaultFile(name: path.split('/').last, bytes: bytes);
  }
}

class _AttachmentBackend extends VaultBackend {
  final Map<String, Uint8List> files = <String, Uint8List>{
    'Attachments/old.txt': Uint8List.fromList(utf8.encode('old')),
    'Attachments/obsolete.bin': Uint8List.fromList(<int>[1, 2, 3]),
  };

  @override
  Future<String?> resolveRootPath() async => '/vault';

  @override
  Future<Map<String, Uint8List>> listBinaryFiles({
    required String rootPath,
    required String directory,
  }) async => Map<String, Uint8List>.from(files);

  @override
  Future<void> deleteFiles({
    required String rootPath,
    required Set<String> relativePaths,
  }) async {
    for (final path in relativePaths) {
      files.remove(path);
    }
  }

  @override
  Future<void> writeBinaryFile({
    required String rootPath,
    required String relativePath,
    required Uint8List bytes,
  }) async {
    files[relativePath] = bytes;
  }
}

class _FailOnceRestoreVaultService extends VaultService {
  _FailOnceRestoreVaultService() : super(backend: _UnavailableBackend());

  int replaceCalls = 0;

  @override
  Future<VaultStatus> inspect() async => const VaultStatus.unavailable();

  @override
  Future<List<BackupCatalogEntry>> listAutomaticBackups() async =>
      const <BackupCatalogEntry>[];

  @override
  Future<EmergencyBackupSnapshot> createEmergencyBackupSnapshot({
    required AppData data,
    DeviceIdentity? identity,
  }) async {
    return EmergencyBackupSnapshot(
      path: '/vault/pre-import-backup.chronicle',
      payload: _payloadFor(data, 'pre-import-backup.chronicle'),
    );
  }

  @override
  Future<void> replaceAttachments(BackupImportPayload payload) async {
    replaceCalls++;
    if (replaceCalls == 1) {
      throw StateError('Смоделированная ошибка записи вложений.');
    }
  }

  @override
  Future<VaultStatus> writeMirror(AppData data, {bool force = false}) async {
    return VaultStatus(
      supported: true,
      rootPath: '/vault',
      noteCount: data.notes.length,
      fileCount: data.notes.length,
    );
  }

  @override
  Future<VaultScanResult> scan(AppData data) async {
    return VaultScanResult(
      rootPath: '/vault',
      scannedAt: DateTime.utc(2026, 7, 17),
      changes: const <VaultNoteChange>[],
      missingFiles: const <VaultMissingFile>[],
    );
  }
}

class _UnavailableBackend extends VaultBackend {
  @override
  Future<String?> resolveRootPath() async => null;
}
