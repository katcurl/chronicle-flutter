import 'dart:io';
import 'dart:typed_data';

import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/vault/vault_backend.dart';
import 'package:chronicle/vault/vault_models.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('two-way Vault detects external edits and conflicts', () async {
    final root = await Directory.systemTemp.createTemp('chronicle-v014-');
    addTearDown(() => root.delete(recursive: true));

    final backend = _TemporaryVaultBackend(root);
    final service = VaultService(backend: backend);
    final note = Note(
      id: 'note-12345678',
      title: 'Исходная заметка',
      projectId: 'project-1',
      body: '# Исходная заметка\n\nНачальный текст',
      folderPath: 'Лекции',
    );
    final data = AppData(
      projects: [Project(id: 'project-1', title: 'Наука', emoji: '🧬')],
      tasks: [],
      notes: [note],
      entries: [],
    );

    await service.writeMirror(data, force: true);
    final noteFile = root
        .listSync(recursive: true)
        .whereType<File>()
        .singleWhere(
          (file) => file.path.endsWith('.md') && file.path.contains('note1234'),
        );
    final original = await noteFile.readAsString();
    await noteFile.writeAsString(
      original.replaceFirst('Начальный текст', 'Изменение из Sublime Text'),
    );

    final externalScan = await service.scan(data);
    expect(externalScan.safeChanges, hasLength(1));
    expect(
      externalScan.safeChanges.single.kind,
      VaultChangeKind.externalUpdate,
    );

    note.body = '# Исходная заметка\n\nИзменение внутри Chronicle';
    note.revision++;
    final conflictScan = await service.scan(data);
    expect(conflictScan.conflicts, hasLength(1));
  });

  test(
    'new Markdown files are import candidates and deletions are protected',
    () async {
      final root = await Directory.systemTemp.createTemp('chronicle-v014-');
      addTearDown(() => root.delete(recursive: true));

      final service = VaultService(backend: _TemporaryVaultBackend(root));
      final data = AppData(
        projects: [Project(id: 'project-1', title: 'Наука', emoji: '🧬')],
        tasks: [],
        notes: [
          Note(
            id: 'note-abcdefgh',
            title: 'Управляемая',
            projectId: 'project-1',
            body: '# Управляемая',
          ),
        ],
        entries: [],
      );

      await service.writeMirror(data, force: true);
      final managed = root
          .listSync(recursive: true)
          .whereType<File>()
          .singleWhere(
            (file) =>
                file.path.endsWith('.md') && file.path.contains('noteabcd'),
          );
      await managed.delete();

      final newFile = File('${root.path}/Notes/Импорт/Новая заметка.md');
      await newFile.parent.create(recursive: true);
      await newFile.writeAsString('''---
title: Новая заметка
project_id: project-1
tags: [импорт, markdown]
---

# Новая заметка

Текст из внешнего файла.
''');

      final scan = await service.scan(data);
      expect(scan.safeChanges.where((change) => change.isNew), hasLength(1));
      expect(scan.missingFiles, hasLength(1));
    },
  );

  test(
    'attachments are copied inside Vault and produce portable Markdown',
    () async {
      final root = await Directory.systemTemp.createTemp('chronicle-v014-');
      addTearDown(() => root.delete(recursive: true));

      final backend = _TemporaryVaultBackend(
        root,
        attachment: PickedVaultFile(
          name: 'схема клетки.png',
          bytes: Uint8List.fromList([1, 2, 3, 4]),
        ),
      );
      final service = VaultService(backend: backend);
      final note = Note(
        id: 'note-1',
        title: 'Клетка',
        projectId: 'project-1',
        folderPath: 'Биология/Лекции',
        body: '# Клетка',
      );

      final result = await service.pickAndStoreAttachment(note);

      expect(result, isNotNull);
      expect(result!.isImage, isTrue);
      expect(result.relativePath, startsWith('Attachments/'));
      expect(result.markdown, startsWith('!['));
      expect(File('${root.path}/${result.relativePath}').existsSync(), isTrue);
    },
  );
}

class _TemporaryVaultBackend extends VaultBackend {
  _TemporaryVaultBackend(this.root, {this.attachment});

  final Directory root;
  final PickedVaultFile? attachment;

  @override
  Future<String?> resolveRootPath() async => root.path;

  @override
  Future<String?> chooseRootPath() async => root.path;

  @override
  Future<PickedVaultFile?> pickAttachment() async => attachment;
}
