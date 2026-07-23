import 'dart:convert';
import 'dart:io';

import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/vault/vault_backend.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'stable Vault manifest publishes the 1.0 compatibility contract',
    () async {
      final root = await Directory.systemTemp.createTemp('chronicle-vault-v1-');
      addTearDown(() => root.delete(recursive: true));
      final backend = _ManifestBackend(root);
      final service = VaultService(backend: backend);

      final status = await service.writeMirror(
        AppData(
          projects: <Project>[
            Project(id: 'project-1', title: 'Research', emoji: '🧬'),
          ],
          tasks: <WorkTask>[],
          notes: <Note>[],
          entries: <TimeEntry>[],
        ),
      );
      final manifest =
          jsonDecode(await File('${root.path}/manifest.json').readAsString())
              as Map<String, dynamic>;

      expect(status.readOnly, isFalse);
      expect(status.formatVersion, VaultService.currentVaultFormatVersion);
      expect(manifest['version'], VaultService.currentVaultFormatVersion);
      expect(
        manifest['minimumReaderVersion'],
        VaultService.minimumReadableVaultFormatVersion,
      );
      expect(manifest['stableSince'], '1.0.0');
      expect(manifest['unknownFrontmatterPolicy'], 'preserve');
      expect(manifest['conflictPolicy'], 'never-silently-overwrite');
    },
  );

  test('newer Vault stays read-only and is never overwritten', () async {
    final root = await Directory.systemTemp.createTemp('chronicle-vault-v2-');
    addTearDown(() => root.delete(recursive: true));
    final manifest = <String, Object?>{
      'format': 'chronicle-vault',
      'version': VaultService.currentVaultFormatVersion + 5,
      'minimumReaderVersion': VaultService.currentVaultFormatVersion + 1,
      'generatedAt': DateTime.utc(2030).toIso8601String(),
      'noteCount': 42,
      'fileCount': 100,
    };
    await File(
      '${root.path}/manifest.json',
    ).writeAsString(jsonEncode(manifest));
    final backend = _ManifestBackend(root);
    final service = VaultService(backend: backend);

    final inspected = await service.inspect();
    final attempted = await service.writeMirror(AppData.empty());

    expect(inspected.readOnly, isTrue);
    expect(attempted.readOnly, isTrue);
    expect(
      attempted.message,
      allOf(
        contains('более новой версией Chronicle'),
        contains('только для чтения'),
      ),
    );
    expect(backend.writeCount, 0);
    expect(
      jsonDecode(await File('${root.path}/manifest.json').readAsString()),
      manifest,
    );
  });

  test('invalid Vault compatibility version is reported as damaged', () async {
    final root = await Directory.systemTemp.createTemp('chronicle-vault-bad-');
    addTearDown(() => root.delete(recursive: true));
    await File('${root.path}/manifest.json').writeAsString(
      jsonEncode(<String, Object?>{
        'format': 'chronicle-vault',
        'version': 0,
        'minimumReaderVersion': 0,
      }),
    );
    final backend = _ManifestBackend(root);
    final service = VaultService(backend: backend);

    final status = await service.inspect();
    final attempted = await service.writeMirror(AppData.empty());

    expect(status.message, contains('повреждён'));
    expect(status.readOnly, isTrue);
    expect(attempted.readOnly, isTrue);
    expect(backend.writeCount, 0);
  });
}

class _ManifestBackend extends VaultBackend {
  _ManifestBackend(this.root);

  final Directory root;
  int writeCount = 0;

  @override
  Future<String?> resolveRootPath() async => root.path;

  @override
  Future<String?> readTextFile(String rootPath, String relativePath) async {
    final file = File('$rootPath/$relativePath');
    return file.existsSync() ? file.readAsString() : null;
  }

  @override
  Future<void> writeFiles({
    required String rootPath,
    required Map<String, String> files,
    required Set<String> staleManagedPaths,
  }) async {
    writeCount += 1;
    for (final path in staleManagedPaths) {
      final file = File('$rootPath/$path');
      if (file.existsSync()) {
        await file.delete();
      }
    }
    for (final entry in files.entries) {
      final file = File('$rootPath/${entry.key}');
      await file.parent.create(recursive: true);
      await file.writeAsString(entry.value);
    }
  }
}
