import 'dart:io';

import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/features/notes/note_document.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/services/app_store.dart';
import 'package:chronicle/vault/vault_backend.dart';
import 'package:chronicle/vault/vault_models.dart';
import 'package:chronicle/vault/vault_revision.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stale scan never overwrites a newer external edit', () async {
    final root = await Directory.systemTemp.createTemp('chronicle-vault-cas-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    final backend = _RootVaultBackend(root);
    final service = VaultService(backend: backend);
    final data = AppData(
      projects: [Project(id: 'p', title: 'Project', emoji: '📌')],
      tasks: const [],
      notes: [Note(id: 'note', title: 'Important', projectId: 'p', body: 'A')],
      entries: const [],
    );
    await service.writeMirror(data, force: true);
    final scan = await service.scan(data);
    final notePath =
        (await backend.listTextFiles(
          rootPath: root.path,
          directory: 'Notes',
          extension: '.md',
        )).keys.single;
    final noteFile = File('${root.path}/$notePath');
    final externalBytes = (await noteFile.readAsBytes())
        .map((byte) => byte)
        .toList(growable: false);
    final externalText = String.fromCharCodes(
      externalBytes,
    ).replaceFirst('\nA\n', '\nB-from-external-editor\n');
    await noteFile.writeAsString(externalText, flush: true);
    final expectedBytes = await noteFile.readAsBytes();

    await expectLater(
      service.rewriteAfterApply(data, scan),
      throwsA(isA<VaultChangedSinceScanException>()),
    );

    expect(await noteFile.readAsBytes(), expectedBytes);
  });

  test('stale scan is rejected before AppStore mutates the database', () async {
    final root = await Directory.systemTemp.createTemp(
      'chronicle-vault-store-cas-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    final repository = InMemoryAppRepository();
    await repository.replaceAll(
      AppData(
        projects: [Project(id: 'p', title: 'Project', emoji: '📌')],
        tasks: const [],
        notes: [
          Note(
            id: 'note',
            title: 'Important',
            projectId: 'p',
            body: 'database',
          ),
        ],
        entries: const [],
      ),
    );
    await repository.markInitialized();
    final store = AppStore(
      repository: repository,
      vaultService: VaultService(backend: _RootVaultBackend(root)),
    );
    addTearDown(store.dispose);
    await store.load();
    final noteFile = root
        .listSync(recursive: true)
        .whereType<File>()
        .singleWhere(
          (file) =>
              file.path.endsWith('.md') &&
              file.path.contains('${Platform.pathSeparator}Notes'),
        );
    await noteFile.writeAsString(
      (await noteFile.readAsString()).replaceFirst(
        '\ndatabase\n',
        '\nexternal-A\n',
      ),
      flush: true,
    );
    final scan = await store.scanVaultChanges();
    expect(scan.safeChanges, hasLength(1));
    await noteFile.writeAsString(
      (await noteFile.readAsString()).replaceFirst(
        '\nexternal-A\n',
        '\nexternal-B\n',
      ),
      flush: true,
    );

    await expectLater(
      store.applyVaultChanges(
        scan,
        conflictResolution: VaultConflictResolution.importFile,
      ),
      throwsA(isA<VaultChangedSinceScanException>()),
    );

    expect(
      NoteDocument.parse(store.noteById('note')!.body).content.trim(),
      'database',
    );
    expect(
      NoteDocument.parse(
        (await repository.load()).notes.single.body,
      ).content.trim(),
      'database',
    );
  });
}

final class _RootVaultBackend extends VaultBackend {
  _RootVaultBackend(this.root);

  final Directory root;

  @override
  Future<String?> resolveRootPath() async => root.path;
}
