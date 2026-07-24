import 'dart:io';
import 'dart:typed_data';

import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/vault/vault_backend.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parallel attachment imports cannot lose an index entry', () async {
    final root = await Directory.systemTemp.createTemp(
      'chronicle-attachment-race-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    final service = VaultService(backend: _DelayedIndexBackend(root));
    final note = Note(id: 'n', title: 'Note', projectId: 'p', body: '');

    final imports = await Future.wait([
      service.storeAttachmentBytes(
        note: note,
        originalName: 'first.txt',
        bytes: Uint8List.fromList('first'.codeUnits),
      ),
      service.storeAttachmentBytes(
        note: note,
        originalName: 'second.txt',
        bytes: Uint8List.fromList('second'.codeUnits),
      ),
    ]);

    final catalog = await service.listAttachmentCatalog();
    expect(catalog.map((record) => record.relativePath).toSet(), {
      imports[0].relativePath,
      imports[1].relativePath,
    });
    for (final result in imports) {
      expect(
        await File('${root.path}/${result.relativePath}').exists(),
        isTrue,
      );
    }
  });
}

final class _DelayedIndexBackend extends VaultBackend {
  _DelayedIndexBackend(this.root);

  final Directory root;

  @override
  Future<String?> resolveRootPath() async => root.path;

  @override
  Future<String?> readTextFile(String rootPath, String relativePath) async {
    final snapshot = await super.readTextFile(rootPath, relativePath);
    if (relativePath == '.chronicle/attachments-index.json') {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    return snapshot;
  }
}
