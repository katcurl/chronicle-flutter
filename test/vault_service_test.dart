import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/vault/vault_backend.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('vault writes Markdown mirror and portable backup', () async {
    final temporary = await Directory.systemTemp.createTemp('chronicle-vault-');
    addTearDown(() => temporary.delete(recursive: true));

    final backend = _TestVaultBackend(temporary);
    final service = VaultService(backend: backend);
    final data = AppData(
      projects: [Project(id: 'project-1', title: 'Наука', emoji: '🧬')],
      tasks: [
        WorkTask(
          id: 'task-1',
          title: 'Проверить Vault',
          projectId: 'project-1',
        ),
      ],
      notes: [
        Note(
          id: 'note-12345678',
          title: 'Строение: атома?',
          projectId: 'project-1',
          folderPath: 'Лекции/Химия',
          tags: const ['химия', 'лекция'],
          body: '''---
status: draft
source: учебник
---

# Строение атома

Текст''',
        ),
      ],
      entries: [],
    );

    final status = await service.writeMirror(data);

    expect(status.supported, isTrue);
    expect(status.noteCount, 1);
    final markdownFiles =
        temporary
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.md'))
            .toList();
    final noteFile = markdownFiles.singleWhere(
      (file) => file.path.contains('note1234'),
    );
    final markdown = await noteFile.readAsString();
    expect(markdown, contains('chronicle_id: "note-12345678"'));
    expect(markdown, contains('# Строение атома'));
    expect(markdown, contains('source: "учебник"'));

    final exported = await service.exportBackup(data: data);
    expect(exported, isNotNull);
    final payload = service.inspectBackup(
      utf8.decode(backend.savedBackupBytes!),
      sourceName: 'test.chronicle',
    );
    expect(payload.preview.checksumsVerified, isTrue);
    expect(payload.preview.projectCount, 1);
    expect(payload.preview.taskCount, 1);
    expect(payload.preview.noteCount, 1);
    expect(
      AppData.decode(payload.databaseJson).notes.single.title,
      'Строение: атома?',
    );
  });

  test('backup inspection rejects modified data', () async {
    final temporary = await Directory.systemTemp.createTemp('chronicle-vault-');
    addTearDown(() => temporary.delete(recursive: true));

    final backend = _TestVaultBackend(temporary);
    final service = VaultService(backend: backend);
    final data = AppData(
      projects: [Project(id: 'p', title: 'P', emoji: '📁')],
      tasks: [],
      notes: [],
      entries: [],
    );

    await service.exportBackup(data: data);
    final decoded =
        jsonDecode(utf8.decode(backend.savedBackupBytes!))
            as Map<String, dynamic>;
    decoded['databaseJson'] = '${decoded['databaseJson']} ';

    expect(
      () => service.inspectBackup(jsonEncode(decoded)),
      throwsA(isA<FormatException>()),
    );
  });
}

class _TestVaultBackend extends VaultBackend {
  _TestVaultBackend(this.root);

  final Directory root;
  Uint8List? savedBackupBytes;

  @override
  Future<String?> resolveRootPath() async => root.path;

  @override
  Future<String?> chooseRootPath() async => root.path;

  @override
  Future<void> writeFiles({
    required String rootPath,
    required Map<String, String> files,
    required Set<String> staleManagedPaths,
  }) async {
    for (final relative in staleManagedPaths) {
      final file = File('$rootPath/$relative');
      if (await file.exists()) {
        await file.delete();
      }
    }
    for (final entry in files.entries) {
      final file = File('$rootPath/${entry.key}');
      await file.parent.create(recursive: true);
      await file.writeAsString(entry.value);
    }
  }

  @override
  Future<String?> readTextFile(String rootPath, String relativePath) async {
    final file = File('$rootPath/$relativePath');
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<bool> fileExists(String rootPath, String relativePath) {
    return File('$rootPath/$relativePath').exists();
  }

  @override
  Future<String?> saveBackup({
    required String fileName,
    required Uint8List bytes,
  }) async {
    savedBackupBytes = bytes;
    return '${root.path}/$fileName';
  }

  @override
  Future<PickedVaultFile?> pickBackup() async => null;

  @override
  Future<String> writeEmergencyBackup({
    required String rootPath,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final file = File('$rootPath/.chronicle/Backups/$fileName');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return file.path;
  }
}
