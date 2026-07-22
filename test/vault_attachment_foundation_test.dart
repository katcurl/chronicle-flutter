import 'dart:convert';
import 'dart:typed_data';

import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/sync/attachment_sync_models.dart';
import 'package:chronicle/vault/vault_backend.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:crypto/crypto.dart';
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

  test('clipboard PNG bytes import without opening the file picker', () async {
    final backend = _AttachmentBackend(const <PickedVaultFile>[]);
    final service = VaultService(backend: backend);
    final note = Note(
      id: 'note-clipboard',
      title: 'Clipboard image',
      projectId: 'project-1',
      body: '# Clipboard image',
      folderPath: 'Experiments/Run 1',
    );
    final bytes = Uint8List.fromList(<int>[
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
      1,
      2,
      3,
    ]);

    final imported = await service.storeAttachmentBytes(
      note: note,
      originalName: 'clipboard-image-20260722-130405.png',
      bytes: bytes,
    );

    expect(imported.isImage, isTrue);
    expect(imported.mimeType, 'image/png');
    expect(imported.markdown, startsWith('![clipboard-image-'));
    expect(imported.markdown, contains('../../../Attachments/'));
    expect(backend.binaryWriteCount, 1);
    expect(backend.binaryFiles[imported.relativePath], orderedEquals(bytes));
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


  test('synced attachment is verified, stored, and indexed', () async {
    final backend = _AttachmentBackend(const <PickedVaultFile>[]);
    final service = VaultService(backend: backend);
    final bytes = Uint8List.fromList(utf8.encode('remote-content'));
    final entry = AttachmentSyncEntry(
      relativePath: 'Attachments/remote--12345678.pdf',
      originalName: 'remote.pdf',
      sha256: sha256.convert(bytes).toString(),
      mimeType: 'application/pdf',
      byteLength: bytes.length,
      createdAt: DateTime.utc(2026, 7, 18, 9),
    );

    final result = await service.storeAttachmentFromSync(entry, bytes);
    final restored = await service.readAttachmentForSync(entry);
    final manifest = await service.buildAttachmentSyncManifest();

    expect(result.changed, isTrue);
    expect(restored, orderedEquals(bytes));
    expect(manifest.entries, hasLength(1));
    expect(manifest.entries.single.relativePath, entry.relativePath);
  });

  test('synced attachment with a wrong checksum is rejected', () async {
    final backend = _AttachmentBackend(const <PickedVaultFile>[]);
    final service = VaultService(backend: backend);
    final bytes = Uint8List.fromList(<int>[1, 2, 3]);
    final entry = AttachmentSyncEntry(
      relativePath: 'Attachments/broken--aaaaaaaa.bin',
      originalName: 'broken.bin',
      sha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      mimeType: 'application/octet-stream',
      byteLength: bytes.length,
      createdAt: DateTime.utc(2026, 7, 18, 9),
    );

    await expectLater(
      service.storeAttachmentFromSync(entry, bytes),
      throwsFormatException,
    );
    expect(backend.binaryFiles, isEmpty);
  });

  test('remote tombstone removes a local attachment', () async {
    final backend = _AttachmentBackend(<PickedVaultFile>[
      PickedVaultFile(
        name: 'old.pdf',
        bytes: Uint8List.fromList(utf8.encode('old-content')),
      ),
    ]);
    final service = VaultService(backend: backend);
    final note = Note(
      id: 'note-1',
      title: 'Old',
      projectId: 'project-1',
      body: '# Old',
    );
    final imported = await service.pickAndStoreAttachment(note);
    final active = (await service.buildAttachmentSyncManifest()).entries.single;
    final tombstone = AttachmentSyncEntry(
      relativePath: active.relativePath,
      originalName: active.originalName,
      sha256: active.sha256,
      mimeType: active.mimeType,
      byteLength: active.byteLength,
      createdAt: active.createdAt,
      deletedAt: DateTime.utc(2026, 7, 18, 12),
    );

    final result = await service.applyAttachmentTombstoneFromSync(tombstone);
    final manifest = await service.buildAttachmentSyncManifest();

    expect(imported, isNotNull);
    expect(result.changed, isTrue);
    expect(backend.binaryFiles, isEmpty);
    expect(manifest.tombstoneCount, 1);
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
  Future<Uint8List?> readBinaryFile(
    String rootPath,
    String relativePath,
  ) async {
    final value = binaryFiles[relativePath];
    return value == null ? null : Uint8List.fromList(value);
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
