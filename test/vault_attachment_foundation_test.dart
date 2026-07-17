import 'dart:convert';
import 'dart:typed_data';

import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/vault/vault_backend.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('attachment import is content-addressed and indexed', () async {
    final backend = _AttachmentBackend(<PickedVaultFile>[
      PickedVaultFile(
        name: 'protocol.pdf',
        bytes: Uint8List.fromList(utf8.encode('same-content')),
      ),
      PickedVaultFile(
        name: 'copy-with-another-name.pdf',
        bytes: Uint8List.fromList(utf8.encode('same-content')),
      ),
    ]);
    final service = VaultService(backend: backend);
    final note = Note(
      id: 'note-1',
      title: 'Protocol',
      projectId: 'project-1',
      body: '# Protocol',
    );

    final first = await service.pickAndStoreAttachment(note);
    final second = await service.pickAndStoreAttachment(note);

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(first!.relativePath, second!.relativePath);
    expect(first.mimeType, 'application/pdf');
    expect(first.sha256, hasLength(64));
    expect(first.alreadyExisted, isFalse);
    expect(second.alreadyExisted, isTrue);
    expect(backend.binaryWriteCount, 1);

    final catalog = await service.listAttachmentCatalog();
    expect(catalog, hasLength(1));
    expect(catalog.single.relativePath, first.relativePath);
    expect(catalog.single.byteLength, utf8.encode('same-content').length);

    final manifest = await service.buildAttachmentSyncManifest();
    expect(manifest.activeCount, 1);
    expect(manifest.tombstoneCount, 0);
    expect(manifest.entries.single.sha256, first.sha256);
  });

  test('managed delete removes file and preserves tombstone', () async {
    final backend = _AttachmentBackend(<PickedVaultFile>[
      PickedVaultFile(
        name: 'image.png',
        bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
      ),
    ]);
    final service = VaultService(backend: backend);
    final note = Note(
      id: 'note-1',
      title: 'Image',
      projectId: 'project-1',
      body: '# Image',
    );

    final imported = await service.pickAndStoreAttachment(note);
    final deleted = await service.deleteManagedAttachment(
      imported!.relativePath,
    );

    expect(deleted.deletedFile, isTrue);
    expect(deleted.tombstoneCreated, isTrue);
    expect(backend.binaryFiles, isEmpty);
    expect(await service.listAttachmentCatalog(), isEmpty);

    final withDeleted = await service.listAttachmentCatalog(
      includeDeleted: true,
    );
    expect(withDeleted, hasLength(1));
    expect(withDeleted.single.isDeleted, isTrue);

    final manifest = await service.buildAttachmentSyncManifest();
    expect(manifest.activeCount, 0);
    expect(manifest.tombstoneCount, 1);
  });

  test('missing indexed binary is not advertised to peers', () async {
    final backend = _AttachmentBackend(<PickedVaultFile>[
      PickedVaultFile(
        name: 'missing.pdf',
        bytes: Uint8List.fromList(utf8.encode('content')),
      ),
    ]);
    final service = VaultService(backend: backend);
    final note = Note(
      id: 'note-1',
      title: 'Missing attachment',
      projectId: 'project-1',
      body: '# Missing attachment',
    );

    final imported = await service.pickAndStoreAttachment(note);
    backend.binaryFiles.remove(imported!.relativePath);

    final manifest = await service.buildAttachmentSyncManifest();
    expect(manifest.entries, isEmpty);
  });

}

class _AttachmentBackend extends VaultBackend {
  _AttachmentBackend(this.pickedFiles);

  final List<PickedVaultFile> pickedFiles;
  int _pickIndex = 0;
  final Map<String, Uint8List> binaryFiles = <String, Uint8List>{};
  final Map<String, String> textFiles = <String, String>{};
  int binaryWriteCount = 0;

  @override
  Future<String?> resolveRootPath() async => '/vault';

  @override
  Future<PickedVaultFile?> pickAttachment() async {
    final index =
        _pickIndex < pickedFiles.length ? _pickIndex : pickedFiles.length - 1;
    _pickIndex += 1;
    return pickedFiles[index];
  }

  @override
  Future<bool> fileExists(String rootPath, String relativePath) async {
    return binaryFiles.containsKey(relativePath);
  }

  @override
  Future<void> writeBinaryFile({
    required String rootPath,
    required String relativePath,
    required Uint8List bytes,
  }) async {
    binaryWriteCount += 1;
    binaryFiles[relativePath] = Uint8List.fromList(bytes);
  }

  @override
  Future<String?> readTextFile(String rootPath, String relativePath) async {
    return textFiles[relativePath];
  }

  @override
  Future<void> writeTextFile({
    required String rootPath,
    required String relativePath,
    required String content,
  }) async {
    textFiles[relativePath] = content;
  }

  @override
  Future<void> deleteFiles({
    required String rootPath,
    required Set<String> relativePaths,
  }) async {
    for (final path in relativePaths) {
      binaryFiles.remove(path);
      textFiles.remove(path);
    }
  }
}
