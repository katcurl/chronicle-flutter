import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/vault/vault_backend.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'automatic backup is portable and requests rotating retention',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'chronicle-auto-backup-',
      );
      addTearDown(() => temporary.delete(recursive: true));

      final backend = _AutomaticBackupBackend(temporary);
      final service = VaultService(backend: backend);
      final data = AppData(
        projects: <Project>[
          Project(id: 'project-1', title: 'Наука', emoji: '🧬'),
        ],
        tasks: <WorkTask>[],
        notes: <Note>[
          Note(
            id: 'note-1',
            title: 'Метастабильные состояния',
            projectId: 'project-1',
            body: '# Тест',
          ),
        ],
        entries: <TimeEntry>[],
      );

      final result = await service.createAutomaticBackup(
        data: data,
        maxFiles: 5,
      );

      expect(result.fileName, startsWith('automatic-backup-'));
      expect(backend.requestedMaxFiles, 5);
      expect(backend.savedBytes, isNotNull);

      final payload = service.inspectBackup(
        utf8.decode(backend.savedBytes!),
        sourceName: result.fileName,
      );
      expect(payload.preview.checksumsVerified, isTrue);
      expect(payload.preview.noteCount, 1);
      expect(payload.preview.projectCount, 1);
    },
  );

  test('automatic backup backend keeps only the newest five files', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'chronicle-backup-rotation-',
    );
    addTearDown(() => temporary.delete(recursive: true));

    final directory = Directory(
      '${temporary.path}/.chronicle/Backups/Automatic',
    );
    await directory.create(recursive: true);
    for (var index = 0; index < 6; index++) {
      final file = File('${directory.path}/old-$index.chronicle');
      await file.writeAsString('old-$index');
      await file.setLastModified(
        DateTime.utc(2026, 7, 10).add(Duration(minutes: index)),
      );
    }

    final backend = VaultBackend();
    await backend.writeAutomaticBackup(
      rootPath: temporary.path,
      fileName: 'newest.chronicle',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      maxFiles: 5,
    );

    final files =
        directory
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.chronicle'))
            .toList();
    expect(files, hasLength(5));
    expect(files.any((file) => file.path.endsWith('newest.chronicle')), isTrue);
    expect(files.any((file) => file.path.endsWith('old-0.chronicle')), isFalse);
    expect(files.any((file) => file.path.endsWith('old-1.chronicle')), isFalse);
  });
}

class _AutomaticBackupBackend extends VaultBackend {
  _AutomaticBackupBackend(this.root);

  final Directory root;
  Uint8List? savedBytes;
  int? requestedMaxFiles;

  @override
  Future<String?> resolveRootPath() async => root.path;

  @override
  Future<Map<String, Uint8List>> listBinaryFiles({
    required String rootPath,
    required String directory,
  }) async => <String, Uint8List>{};

  @override
  Future<String> writeAutomaticBackup({
    required String rootPath,
    required String fileName,
    required Uint8List bytes,
    int maxFiles = 5,
  }) async {
    savedBytes = bytes;
    requestedMaxFiles = maxFiles;
    return '${root.path}/$fileName';
  }
}
