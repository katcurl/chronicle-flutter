import 'dart:io';
import 'dart:typed_data';

import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/vault/managed_path_resolver.dart';
import 'package:chronicle/vault/vault_asset_loader.dart';
import 'package:chronicle/vault/vault_backend.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late Directory outside;
  late ManagedPathResolver resolver;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('chronicle-vault-root-');
    outside = await Directory.systemTemp.createTemp('chronicle-vault-outside-');
    resolver = createManagedPathResolver();
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
    if (await outside.exists()) {
      await outside.delete(recursive: true);
    }
  });

  test('lexical traversal and ambiguous separators are rejected', () async {
    for (final relativePath in <String>[
      '../outside.md',
      'Notes/../../outside.md',
      r'Notes\..\..\outside.md',
      '/absolute.md',
      'Notes/./note.md',
      'Notes//note.md',
    ]) {
      await expectLater(
        resolver.resolveForWrite(root.path, relativePath),
        throwsA(isA<FormatException>()),
        reason: relativePath,
      );
    }
  });

  test('valid nested write path remains under canonical root', () async {
    final resolved = await resolver.resolveForWrite(
      root.path,
      'Notes/Research/note.md',
    );

    expect(resolved, startsWith(await root.resolveSymbolicLinks()));
    expect(await Directory('${root.path}/Notes/Research').exists(), isTrue);
  });

  test('symlink cannot redirect managed read, write, or delete', () async {
    if (Platform.isWindows) {
      return;
    }
    final outsideFile = File('${outside.path}/secret.md');
    await outsideFile.writeAsString('keep');
    final link = Link('${root.path}/Notes');
    await link.create(outside.path);
    final attachmentsLink = Link('${root.path}/Attachments');
    await attachmentsLink.create(outside.path);
    final backend = VaultBackend();

    await expectLater(
      resolver.resolveExisting(root.path, 'Notes/secret.md'),
      throwsA(isA<FileSystemException>()),
    );
    await expectLater(
      backend.readTextFile(root.path, 'Notes/secret.md'),
      throwsA(isA<FileSystemException>()),
    );
    await expectLater(
      backend.readBinaryFile(root.path, 'Notes/secret.md'),
      throwsA(isA<FileSystemException>()),
    );
    await expectLater(
      backend.fileExists(root.path, 'Notes/secret.md'),
      throwsA(isA<FileSystemException>()),
    );
    await expectLater(
      backend.writeTextFile(
        rootPath: root.path,
        relativePath: 'Notes/new.md',
        content: 'escape',
      ),
      throwsA(isA<FileSystemException>()),
    );
    await expectLater(
      backend.writeBinaryFile(
        rootPath: root.path,
        relativePath: 'Notes/new.bin',
        bytes: Uint8List.fromList(const [1, 2, 3]),
      ),
      throwsA(isA<FileSystemException>()),
    );
    await expectLater(
      backend.writeFiles(
        rootPath: root.path,
        files: const {'Notes/new.md': 'escape'},
        staleManagedPaths: const {},
      ),
      throwsA(isA<FileSystemException>()),
    );
    await expectLater(
      backend.deleteFiles(
        rootPath: root.path,
        relativePaths: const {'Notes/secret.md'},
      ),
      throwsA(isA<FileSystemException>()),
    );
    await expectLater(
      loadVaultAttachment(root.path, 'Attachments/secret.md'),
      throwsA(isA<FileSystemException>()),
    );
    await expectLater(
      loadVaultAttachment(root.path, 'Attachments/../secret.md'),
      throwsA(isA<FormatException>()),
    );

    expect(await outsideFile.readAsString(), 'keep');
    expect(await File('${outside.path}/new.md').exists(), isFalse);
  });

  test('backend rejects traversal before touching an outside file', () async {
    final outsideFile = File('${outside.path}/outside.md');
    final relative = '../${p.basename(outside.path)}/outside.md';
    final backend = VaultBackend();

    await expectLater(
      backend.writeTextFile(
        rootPath: root.path,
        relativePath: relative,
        content: 'escape',
      ),
      throwsA(isA<FormatException>()),
    );

    expect(await outsideFile.exists(), isFalse);
  });

  test('malformed Vault index disables mirror writes', () async {
    final backend = _RootVaultBackend(root);
    final service = VaultService(backend: backend);
    final note = Note(
      id: 'note',
      title: 'Important',
      projectId: 'p',
      body: 'before',
    );
    final data = AppData(
      projects: [Project(id: 'p', title: 'Project', emoji: '📌')],
      tasks: const [],
      notes: [note],
      entries: const [],
    );
    await service.writeMirror(data, force: true);
    final markdown =
        (await backend.listTextFiles(
          rootPath: root.path,
          directory: 'Notes',
          extension: '.md',
        )).values.single;
    await backend.writeTextFile(
      rootPath: root.path,
      relativePath: '.chronicle/vault-index.json',
      content: '{"notes":',
    );
    note.body = 'after';

    final status = await service.writeMirror(data, force: true);

    expect(status.readOnly, isTrue);
    expect(
      (await backend.listTextFiles(
        rootPath: root.path,
        directory: 'Notes',
        extension: '.md',
      )).values.single,
      markdown,
    );
  });
}

final class _RootVaultBackend extends VaultBackend {
  _RootVaultBackend(this.root);

  final Directory root;

  @override
  Future<String?> resolveRootPath() async => root.path;
}
