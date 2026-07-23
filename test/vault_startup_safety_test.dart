import 'dart:io';

import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/services/app_store.dart';
import 'package:chronicle/vault/vault_backend.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'new local database does not overwrite an existing Markdown Vault',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'chronicle-vault-startup-safety-',
      );
      addTearDown(() => root.delete(recursive: true));

      final backend = _TemporaryVaultBackend(root);
      final vaultService = VaultService(backend: backend);
      final originalData = AppData(
        projects: [Project(id: 'project-1', title: 'Research', emoji: '🧬')],
        tasks: const [],
        notes: [
          Note(
            id: 'note-original',
            title: 'Original note',
            projectId: 'project-1',
            body: '# Original note\n\nImportant content',
          ),
        ],
        entries: const [],
      );

      await vaultService.writeMirror(originalData, force: true);
      final markdownBefore = await backend.listTextFiles(
        rootPath: root.path,
        directory: 'Notes',
        extension: '.md',
      );
      expect(markdownBefore, hasLength(1));

      final repository = InMemoryAppRepository();
      final store = AppStore(
        repository: repository,
        vaultService: vaultService,
      );
      addTearDown(store.dispose);

      await store.load();

      expect(store.loadError, isNull);
      expect(store.data.notes, isEmpty);
      expect(store.pendingVaultScan, isNotNull);
      expect(store.pendingVaultScan!.changes, hasLength(1));

      final markdownAfter = await backend.listTextFiles(
        rootPath: root.path,
        directory: 'Notes',
        extension: '.md',
      );
      expect(markdownAfter, markdownBefore);
    },
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
