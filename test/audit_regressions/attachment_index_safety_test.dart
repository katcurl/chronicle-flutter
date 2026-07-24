import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/vault/vault_backend.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late VaultBackend backend;
  late VaultService service;
  late Note note;

  Future<void> writeIndex(String raw) async {
    await backend.writeTextFile(
      rootPath: root.path,
      relativePath: '.chronicle/attachments-index.json',
      content: raw,
    );
  }

  File indexFile() => File('${root.path}/.chronicle/attachments-index.json');

  setUp(() async {
    root = await Directory.systemTemp.createTemp('chronicle-attachment-index-');
    backend = _RootVaultBackend(root);
    service = VaultService(backend: backend);
    note = Note(id: 'n', title: 'Note', projectId: 'p', body: '');
    await service.writeMirror(
      AppData(
        projects: [Project(id: 'p', title: 'Project', emoji: '📌')],
        tasks: const [],
        notes: [note],
        entries: const [],
      ),
      force: true,
    );
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('malformed attachment index makes Vault read-only', () async {
    await writeIndex('{"attachments":');

    final status = await service.inspect();

    expect(status.readOnly, isTrue);
    expect(status.message, contains('индекс вложений'));
  });

  test(
    'future attachment index is preserved and blocks all mutation',
    () async {
      final futureIndex = const JsonEncoder.withIndent('  ').convert({
        'format': 'chronicle-attachment-index',
        'version': 999,
        'attachments': <Object>[],
      });
      await writeIndex(futureIndex);
      final before = await indexFile().readAsBytes();

      await expectLater(
        service.storeAttachmentBytes(
          note: note,
          originalName: 'must-not-appear.txt',
          bytes: Uint8List.fromList('important'.codeUnits),
        ),
        throwsFormatException,
      );

      expect(await indexFile().readAsBytes(), before);
      final attachments = await backend.listBinaryFiles(
        rootPath: root.path,
        directory: 'Attachments',
      );
      expect(attachments, isEmpty);
    },
  );

  test('corrupt index blocks delete before the binary is touched', () async {
    final imported = await service.storeAttachmentBytes(
      note: note,
      originalName: 'keep.txt',
      bytes: Uint8List.fromList('keep'.codeUnits),
    );
    final binary = File('${root.path}/${imported.relativePath}');
    final before = await binary.readAsBytes();
    await writeIndex('{"format":"chronicle-attachment-index","version":');

    await expectLater(
      service.deleteManagedAttachment(imported.relativePath),
      throwsFormatException,
    );

    expect(await binary.readAsBytes(), before);
  });
}

final class _RootVaultBackend extends VaultBackend {
  _RootVaultBackend(this.root);

  final Directory root;

  @override
  Future<String?> resolveRootPath() async => root.path;
}
