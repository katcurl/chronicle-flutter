import 'dart:io';
import 'dart:typed_data';

import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/vault/vault_backend.dart';
import 'package:chronicle/vault/vault_models.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'attachment reconciliation is diagnostic and never mutates files',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'chronicle-attachment-integrity-',
      );
      addTearDown(() async {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });
      final backend = _RootVaultBackend(root);
      final service = VaultService(backend: backend);
      final note = Note(id: 'n', title: 'Note', projectId: 'p', body: '');

      final missing = await _store(service, note, 'missing.bin', [1, 2, 3]);
      await backend.deleteFiles(
        rootPath: root.path,
        relativePaths: {missing.relativePath},
      );

      final tombstone = await _store(service, note, 'deleted.bin', [4, 5, 6]);
      await service.deleteManagedAttachment(tombstone.relativePath);
      await _write(backend, root, tombstone.relativePath, [4, 5, 6]);

      final badHash = await _store(service, note, 'hash.bin', [7, 8, 9]);
      await _write(backend, root, badHash.relativePath, [9, 8, 7]);

      final badSize = await _store(service, note, 'size.bin', [10, 11, 12]);
      await _write(backend, root, badSize.relativePath, [10]);

      const orphanPath = 'Attachments/orphan.bin';
      await _write(backend, root, orphanPath, [99]);
      final orphanBefore = await File('${root.path}/$orphanPath').readAsBytes();

      final report = await service.inspectAttachmentIntegrity();

      expect(report.issues.map((issue) => issue.kind).toSet(), {
        AttachmentIntegrityIssueKind.missingBinary,
        AttachmentIntegrityIssueKind.tombstoneHasBinary,
        AttachmentIntegrityIssueKind.hashMismatch,
        AttachmentIntegrityIssueKind.sizeMismatch,
        AttachmentIntegrityIssueKind.orphanBinary,
      });
      expect(
        await File('${root.path}/$orphanPath').readAsBytes(),
        orphanBefore,
      );
    },
  );
}

Future<AttachmentImportResult> _store(
  VaultService service,
  Note note,
  String name,
  List<int> bytes,
) {
  return service.storeAttachmentBytes(
    note: note,
    originalName: name,
    bytes: Uint8List.fromList(bytes),
  );
}

Future<void> _write(
  VaultBackend backend,
  Directory root,
  String relativePath,
  List<int> bytes,
) {
  return backend.writeBinaryFile(
    rootPath: root.path,
    relativePath: relativePath,
    bytes: Uint8List.fromList(bytes),
  );
}

final class _RootVaultBackend extends VaultBackend {
  _RootVaultBackend(this.root);

  final Directory root;

  @override
  Future<String?> resolveRootPath() async => root.path;
}
