import 'dart:convert';
import 'dart:typed_data';

import 'package:chronicle/data/backup/backup_limits.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/vault/vault_backend.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('raw backup limit is checked before JSON parsing', () {
    final service = _service(maxRawBytes: 32);

    expect(
      () => service.inspectBackup('x' * 33),
      throwsA(isA<BackupLimitException>()),
    );
  });

  test('oversized encoded attachment is rejected before Base64 decode', () {
    final service = _service(maxAttachmentBytes: 3);
    final raw = _backup(
      attachments: {'Attachments/large.bin': '!' * 16},
      declaredLengths: {'Attachments/large.bin': 12},
    );

    expect(
      () => service.inspectBackup(raw),
      throwsA(
        isA<BackupLimitException>().having(
          (error) => error.message,
          'message',
          contains('одного вложения'),
        ),
      ),
    );
  });

  test('aggregate decoded attachment budget is enforced', () {
    final service = _service(maxTotalBytes: 5);
    final first = base64Encode([1, 2, 3]);
    final second = base64Encode([4, 5, 6]);
    final raw = _backup(
      attachments: {
        'Attachments/first.bin': first,
        'Attachments/second.bin': second,
      },
      declaredLengths: {
        'Attachments/first.bin': 3,
        'Attachments/second.bin': 3,
      },
      attachmentBytes: {
        'Attachments/first.bin': [1, 2, 3],
        'Attachments/second.bin': [4, 5, 6],
      },
    );

    expect(
      () => service.inspectBackup(raw),
      throwsA(isA<BackupLimitException>()),
    );
  });

  test('attachment count is bounded', () {
    final service = _service(maxAttachmentCount: 1);
    final raw = _backup(
      attachments: {
        'Attachments/first.bin': base64Encode([1]),
        'Attachments/second.bin': base64Encode([2]),
      },
      declaredLengths: {
        'Attachments/first.bin': 1,
        'Attachments/second.bin': 1,
      },
      attachmentBytes: {
        'Attachments/first.bin': [1],
        'Attachments/second.bin': [2],
      },
    );

    expect(
      () => service.inspectBackup(raw),
      throwsA(isA<BackupLimitException>()),
    );
  });

  test('declared and decoded attachment lengths must match', () {
    final service = _service();
    final raw = _backup(
      attachments: {
        'Attachments/file.bin': base64Encode([1, 2, 3]),
      },
      declaredLengths: {'Attachments/file.bin': 2},
      attachmentBytes: {
        'Attachments/file.bin': [1, 2, 3],
      },
    );

    expect(() => service.inspectBackup(raw), throwsFormatException);
  });

  test(
    'export checks attachment metadata before reading oversized bytes',
    () async {
      final backend = _OversizedAttachmentBackend();
      final service = VaultService(
        backend: backend,
        backupLimits: const BackupResourceLimits(
          maxRawBytes: 1024,
          maxAttachmentBytes: 3,
          maxDecodedAttachmentBytes: 10,
          maxAttachmentCount: 10,
        ),
      );

      await expectLater(
        service.createAutomaticBackup(
          data: AppData(
            projects: [Project(id: 'p', title: 'Project', emoji: '📌')],
            tasks: const [],
            notes: const [],
            entries: const [],
          ),
        ),
        throwsA(isA<BackupLimitException>()),
      );

      expect(backend.binaryReadCount, 0);
    },
  );
}

VaultService _service({
  int maxRawBytes = 1024 * 1024,
  int maxAttachmentBytes = 1024,
  int maxTotalBytes = 4096,
  int maxAttachmentCount = 100,
}) {
  return VaultService(
    backupLimits: BackupResourceLimits(
      maxRawBytes: maxRawBytes,
      maxAttachmentBytes: maxAttachmentBytes,
      maxDecodedAttachmentBytes: maxTotalBytes,
      maxAttachmentCount: maxAttachmentCount,
    ),
  );
}

String _backup({
  required Map<String, String> attachments,
  required Map<String, int> declaredLengths,
  Map<String, List<int>> attachmentBytes = const {},
}) {
  final databaseJson =
      AppData(
        projects: [Project(id: 'p', title: 'Project', emoji: '📌')],
        tasks: const [],
        notes: const [],
        entries: const [],
      ).encode();
  return jsonEncode({
    'format': 'chronicle-portable-backup',
    'formatVersion': 3,
    'exportedAt': DateTime.utc(2026, 7, 24).toIso8601String(),
    'databaseJson': databaseJson,
    'vaultFiles': <String, String>{},
    'attachmentsBase64': attachments,
    'attachmentMetadata': {
      for (final entry in declaredLengths.entries)
        entry.key: {'byteLength': entry.value},
    },
    'checksums': {
      'database.json': sha256.convert(utf8.encode(databaseJson)).toString(),
      for (final entry in attachmentBytes.entries)
        entry.key: sha256.convert(entry.value).toString(),
    },
  });
}

final class _OversizedAttachmentBackend extends VaultBackend {
  int binaryReadCount = 0;

  @override
  Future<String?> resolveRootPath() async => '/vault';

  @override
  Future<Map<String, int>> listBinaryFileSizes({
    required String rootPath,
    required String directory,
  }) async => {'Attachments/huge.bin': 4};

  @override
  Future<Uint8List?> readBinaryFile(
    String rootPath,
    String relativePath,
  ) async {
    binaryReadCount += 1;
    return Uint8List(4);
  }
}
