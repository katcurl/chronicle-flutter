import 'dart:io';

import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/features/notes/note_document.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/services/app_store.dart';
import 'package:chronicle/vault/vault_backend.dart';
import 'package:chronicle/vault/vault_models.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Vault conflicts can be resolved independently', () async {
    final root = await Directory.systemTemp.createTemp(
      'chronicle-v019-conflicts-',
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

    final firstFile = _managedMarkdown(root, 'noteaaaa');
    final secondFile = _managedMarkdown(root, 'notebbbb');
    await firstFile.writeAsString(
      (await firstFile.readAsString()).replaceFirst(
        'Исходный текст A',
        'Версия Vault A',
      ),
    );
    await secondFile.writeAsString(
      (await secondFile.readAsString()).replaceFirst(
        'Исходный текст B',
        'Версия Vault B',
      ),
    );

    final first = store.noteById('note-aaaaaaaa')!;
    first.body = NoteDocument.serialize(
      first,
      '# Первая\n\nВерсия Chronicle A',
    );
    first.revision += 1;
    first.updatedAt = DateTime.now();

    final second = store.noteById('note-bbbbbbbb')!;
    second.body = NoteDocument.serialize(
      second,
      '# Вторая\n\nВерсия Chronicle B',
    );
    second.revision += 1;
    second.updatedAt = DateTime.now();

    final scan = await store.scanVaultChanges();
    expect(scan.conflicts, hasLength(2));

    final decisions = <String, VaultConflictResolution>{
      for (final conflict in scan.conflicts)
        conflict.decisionKey:
            conflict.currentNoteId == first.id
                ? VaultConflictResolution.keepChronicle
                : VaultConflictResolution.importFile,
    };

    final result = await store.applyVaultChanges(
      scan,
      conflictResolution: VaultConflictResolution.keepBoth,
      conflictResolutions: decisions,
    );

    expect(result.keptChronicleCount, 1);
    expect(result.updatedCount, 1);
    expect(result.duplicatedCount, 0);
    expect(result.safetyBackupPath, isNotNull);
    expect(File(result.safetyBackupPath!).existsSync(), isTrue);

    expect(
      NoteDocument.parse(store.noteById(first.id)!.body).content,
      contains('Версия Chronicle A'),
    );
    expect(
      NoteDocument.parse(store.noteById(second.id)!.body).content,
      contains('Версия Vault B'),
    );
    expect(
      store.data.noteVersions.any((version) => version.noteId == second.id),
      isTrue,
    );

    final cleanScan = await store.scanVaultChanges();
    expect(cleanScan.hasChanges, isFalse);
  });

  test(
    'keep both remains the safe fallback for an unmapped conflict',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'chronicle-v019-keep-both-',
      );
      addTearDown(() => root.delete(recursive: true));

      final repository = InMemoryAppRepository();
      final data = _fixtureData();
      data.notes.removeLast();
      await repository.replaceAll(data);
      await repository.markInitialized();

      final store = AppStore(
        repository: repository,
        vaultService: VaultService(backend: _TemporaryVaultBackend(root)),
      );
      addTearDown(store.dispose);
      await store.load();

      final file = _managedMarkdown(root, 'noteaaaa');
      await file.writeAsString(
        (await file.readAsString()).replaceFirst(
          'Исходный текст A',
          'Отдельная версия Vault',
        ),
      );
      final current = store.noteById('note-aaaaaaaa')!;
      current.body = NoteDocument.serialize(
        current,
        '# Первая\n\nОтдельная версия Chronicle',
      );
      current.revision += 1;
      current.updatedAt = DateTime.now();

      final scan = await store.scanVaultChanges();
      final result = await store.applyVaultChanges(
        scan,
        conflictResolution: VaultConflictResolution.keepBoth,
      );

      expect(result.duplicatedCount, 1);
      expect(store.data.notes, hasLength(2));
      expect(
        store.data.notes.any(
          (note) => note.title.contains('конфликтная версия Vault'),
        ),
        isTrue,
      );
      expect(result.safetyBackupPath, isNotNull);
    },
  );
}

AppData _fixtureData() {
  return AppData(
    projects: [Project(id: 'project-1', title: 'Наука', emoji: '🧬')],
    tasks: [],
    notes: [
      Note(
        id: 'note-aaaaaaaa',
        title: 'Первая',
        projectId: 'project-1',
        body: '# Первая\n\nИсходный текст A',
        folderPath: 'Исследования',
      ),
      Note(
        id: 'note-bbbbbbbb',
        title: 'Вторая',
        projectId: 'project-1',
        body: '# Вторая\n\nИсходный текст B',
        folderPath: 'Исследования',
      ),
    ],
    entries: [],
  );
}

File _managedMarkdown(Directory root, String compactId) {
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .singleWhere(
        (file) => file.path.endsWith('.md') && file.path.contains(compactId),
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
