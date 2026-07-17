import 'dart:io';

import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/services/app_store.dart';
import 'package:chronicle/vault/vault_backend.dart';
import 'package:chronicle/vault/vault_models.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'missing managed Markdown can create a synchronized note tombstone',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'chronicle-v019-delete-',
      );
      addTearDown(() => root.delete(recursive: true));

      final repository = InMemoryAppRepository();
      await repository.replaceAll(_fixtureData());
      await repository.markInitialized();

      final store = AppStore(
        repository: repository,
        vaultService: VaultService(backend: _TemporaryVaultBackend(root)),
      );
      addTearDown(store.dispose);
      await store.load();

      final managed = _managedMarkdown(root);
      await managed.delete();

      final scan = await store.scanVaultChanges();
      expect(scan.missingFiles, hasLength(1));

      final result = await store.applyVaultChanges(
        scan,
        conflictResolution: VaultConflictResolution.importFile,
        missingFileResolution: VaultMissingFileResolution.deleteNotes,
      );

      expect(result.deletedCount, 1);
      expect(result.restoredFileCount, 0);
      expect(result.safetyBackupPath, isNotNull);
      expect(File(result.safetyBackupPath!).existsSync(), isTrue);
      expect(store.data.notes, isEmpty);
      expect(store.data.tasks.single.noteId, isNull);
      expect(managed.existsSync(), isFalse);

      final persisted = await repository.load();
      expect(persisted.notes, isEmpty);
      expect(persisted.tasks.single.noteId, isNull);
      expect(
        store.recentChanges.any(
          (change) =>
              change.entityType == 'note' &&
              change.entityId == 'note-12345678' &&
              change.operation == 'delete',
        ),
        isTrue,
      );
    },
  );

  test('safe default restores a missing managed Markdown file', () async {
    final root = await Directory.systemTemp.createTemp(
      'chronicle-v019-restore-',
    );
    addTearDown(() => root.delete(recursive: true));

    final repository = InMemoryAppRepository();
    await repository.replaceAll(_fixtureData());
    await repository.markInitialized();

    final store = AppStore(
      repository: repository,
      vaultService: VaultService(backend: _TemporaryVaultBackend(root)),
    );
    addTearDown(store.dispose);
    await store.load();

    final managed = _managedMarkdown(root);
    await managed.delete();
    final scan = await store.scanVaultChanges();

    final result = await store.applyVaultChanges(
      scan,
      conflictResolution: VaultConflictResolution.importFile,
    );

    expect(result.deletedCount, 0);
    expect(result.restoredFileCount, 1);
    expect(store.data.notes, hasLength(1));
    expect(managed.existsSync(), isTrue);
  });
}

AppData _fixtureData() {
  return AppData(
    projects: [Project(id: 'project-1', title: 'Наука', emoji: '🧬')],
    tasks: [
      WorkTask(
        id: 'task-1',
        title: 'Связанная задача',
        projectId: 'project-1',
        noteId: 'note-12345678',
      ),
    ],
    notes: [
      Note(
        id: 'note-12345678',
        title: 'Управляемая заметка',
        projectId: 'project-1',
        body: '# Управляемая заметка\n\nТекст',
      ),
    ],
    entries: [],
  );
}

File _managedMarkdown(Directory root) {
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .singleWhere(
        (file) => file.path.endsWith('.md') && file.path.contains('note1234'),
      );
}

class _TemporaryVaultBackend extends VaultBackend {
  _TemporaryVaultBackend(this.root);

  final Directory root;

  @override
  Future<String?> resolveRootPath() async => root.path;

  @override
  Future<String?> chooseRootPath() async => root.path;
}
