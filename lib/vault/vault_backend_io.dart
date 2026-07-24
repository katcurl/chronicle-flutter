import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'atomic_file_writer.dart';
import 'managed_path_resolver.dart';

class PickedVaultFile {
  const PickedVaultFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class VaultBackupFileInfo {
  const VaultBackupFileInfo({
    required this.path,
    required this.name,
    required this.modifiedAt,
    required this.byteLength,
  });

  final String path;
  final String name;
  final DateTime modifiedAt;
  final int byteLength;
}

class VaultBackend {
  VaultBackend({
    ManagedPathResolver? pathResolver,
    AtomicFileWriter? atomicFileWriter,
  }) : _pathResolver = pathResolver ?? createManagedPathResolver(),
       _atomicFileWriter = atomicFileWriter ?? createAtomicFileWriter();

  static const _vaultPathKey = 'chronicle_vault_path';

  final ManagedPathResolver _pathResolver;
  final AtomicFileWriter _atomicFileWriter;

  Future<String?> resolveRootPath() async {
    final preferences = await SharedPreferences.getInstance();
    final configured = preferences.getString(_vaultPathKey)?.trim();
    if (configured != null && configured.isNotEmpty) {
      return configured;
    }
    final documents = await getApplicationDocumentsDirectory();
    return p.join(documents.path, 'Chronicle Vault');
  }

  Future<String?> chooseRootPath() async {
    final selected = await FilePicker.getDirectoryPath(
      dialogTitle: 'Выбери папку Chronicle Vault',
    );
    if (selected == null || selected.trim().isEmpty) {
      return null;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_vaultPathKey, selected);
    return selected;
  }

  Future<void> writeFiles({
    required String rootPath,
    required Map<String, String> files,
    required Set<String> staleManagedPaths,
  }) async {
    await Directory(rootPath).create(recursive: true);

    final orderedEntries = files.entries.toList(growable: false)
      ..sort((left, right) {
        final priority = _writePriority(
          left.key,
        ).compareTo(_writePriority(right.key));
        return priority != 0 ? priority : left.key.compareTo(right.key);
      });
    for (final entry in orderedEntries) {
      final target = File(
        await _pathResolver.resolveForWrite(rootPath, entry.key),
      );
      await _atomicFileWriter.replace(target.path, utf8.encode(entry.value));
    }

    for (final relativePath in staleManagedPaths) {
      final target = await _resolveExistingOrNull(rootPath, relativePath);
      if (target != null) {
        await File(target).delete();
      }
    }

    await _createManagedDirectory(rootPath, 'Attachments');
    await _createManagedDirectory(rootPath, 'Templates');
    await _createManagedDirectory(rootPath, '.chronicle/Backups');
  }

  Future<String?> readTextFile(String rootPath, String relativePath) async {
    final resolved = await _resolveExistingOrNull(rootPath, relativePath);
    if (resolved == null) {
      return null;
    }
    return File(resolved).readAsString();
  }

  Future<void> writeTextFile({
    required String rootPath,
    required String relativePath,
    required String content,
  }) async {
    final target = File(
      await _pathResolver.resolveForWrite(rootPath, relativePath),
    );
    await _atomicFileWriter.replace(target.path, utf8.encode(content));
  }

  Future<Map<String, String>> listTextFiles({
    required String rootPath,
    required String directory,
    required String extension,
  }) async {
    final resolved = await _resolveExistingOrNull(rootPath, directory);
    if (resolved == null) {
      return <String, String>{};
    }
    final base = Directory(resolved);
    final canonicalRoot = await Directory(rootPath).resolveSymbolicLinks();

    final result = <String, String>{};
    await for (final entity in base.list(recursive: true, followLinks: false)) {
      if (entity is! File ||
          !entity.path.toLowerCase().endsWith(extension.toLowerCase())) {
        continue;
      }
      final relative = p
          .relative(entity.path, from: canonicalRoot)
          .replaceAll(p.separator, '/');
      result[relative] = await entity.readAsString();
    }
    return result;
  }

  Future<void> deleteFiles({
    required String rootPath,
    required Set<String> relativePaths,
  }) async {
    for (final relativePath in relativePaths) {
      final resolved = await _resolveExistingOrNull(rootPath, relativePath);
      if (resolved != null) {
        await File(resolved).delete();
      }
    }
  }

  Future<Map<String, Uint8List>> listBinaryFiles({
    required String rootPath,
    required String directory,
  }) async {
    final resolved = await _resolveExistingOrNull(rootPath, directory);
    if (resolved == null) {
      return <String, Uint8List>{};
    }
    final base = Directory(resolved);
    final canonicalRoot = await Directory(rootPath).resolveSymbolicLinks();
    final result = <String, Uint8List>{};
    await for (final entity in base.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final relative = p
          .relative(entity.path, from: canonicalRoot)
          .replaceAll(p.separator, '/');
      result[relative] = await entity.readAsBytes();
    }
    return result;
  }

  Future<Uint8List?> readBinaryFile(
    String rootPath,
    String relativePath,
  ) async {
    final resolved = await _resolveExistingOrNull(rootPath, relativePath);
    if (resolved == null) {
      return null;
    }
    return File(resolved).readAsBytes();
  }

  Future<bool> fileExists(String rootPath, String relativePath) async {
    return await _resolveExistingOrNull(rootPath, relativePath) != null;
  }

  Future<void> writeBinaryFile({
    required String rootPath,
    required String relativePath,
    required Uint8List bytes,
  }) async {
    final target = File(
      await _pathResolver.resolveForWrite(rootPath, relativePath),
    );
    await _atomicFileWriter.replace(target.path, bytes);
  }

  Future<PickedVaultFile?> pickAttachment() async {
    final selected = await FilePicker.pickFile(
      dialogTitle: 'Добавить вложение в заметку',
      type: FileType.any,
    );

    if (selected == null) {
      return null;
    }

    final bytes = await selected.readAsBytes();
    return PickedVaultFile(name: selected.name, bytes: bytes);
  }

  Future<String?> saveBackup({
    required String fileName,
    required Uint8List bytes,
  }) {
    return FilePicker.saveFile(
      dialogTitle: 'Сохранить резервную копию Chronicle',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['chronicle'],
      bytes: bytes,
    );
  }

  Future<PickedVaultFile?> pickBackup() async {
    final selected = await FilePicker.pickFile(
      dialogTitle: 'Выбрать резервную копию Chronicle',
      type: FileType.custom,
      allowedExtensions: const ['chronicle'],
    );

    if (selected == null) {
      return null;
    }

    final bytes = await selected.readAsBytes();

    return PickedVaultFile(name: selected.name, bytes: bytes);
  }

  Future<List<VaultBackupFileInfo>> listAutomaticBackups({
    required String rootPath,
  }) async {
    final resolved = await _resolveExistingOrNull(
      rootPath,
      '.chronicle/Backups/Automatic',
    );
    if (resolved == null) {
      return const <VaultBackupFileInfo>[];
    }
    final directory = Directory(resolved);

    final result = <VaultBackupFileInfo>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.chronicle')) {
        continue;
      }
      final stat = await entity.stat();
      result.add(
        VaultBackupFileInfo(
          path: entity.path,
          name: p.basename(entity.path),
          modifiedAt: stat.modified,
          byteLength: stat.size,
        ),
      );
    }
    result.sort((left, right) => right.modifiedAt.compareTo(left.modifiedAt));
    return result;
  }

  Future<PickedVaultFile?> readBackupPath(String path) async {
    final file = File(path);
    if (!path.endsWith('.chronicle') || !await file.exists()) {
      return null;
    }
    return PickedVaultFile(
      name: p.basename(path),
      bytes: await file.readAsBytes(),
    );
  }

  Future<String> writeEmergencyBackup({
    required String rootPath,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final relativePath = '.chronicle/Backups/$fileName';
    final target = File(
      await _pathResolver.resolveForWrite(rootPath, relativePath),
    );
    await _atomicFileWriter.replace(target.path, bytes);
    return target.path;
  }

  Future<String> writeAutomaticBackup({
    required String rootPath,
    required String fileName,
    required Uint8List bytes,
    int maxFiles = 5,
  }) async {
    final directory = Directory(
      await _pathResolver.resolveForWrite(
        rootPath,
        '.chronicle/Backups/Automatic',
      ),
    );
    await directory.create(recursive: true);
    final relativePath = '.chronicle/Backups/Automatic/$fileName';
    final target = File(
      await _pathResolver.resolveForWrite(rootPath, relativePath),
    );
    await _atomicFileWriter.replace(target.path, bytes);

    final backups = <File>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File && entity.path.endsWith('.chronicle')) {
        backups.add(entity);
      }
    }
    backups.sort((left, right) {
      final leftTime = left.statSync().modified;
      final rightTime = right.statSync().modified;
      return rightTime.compareTo(leftTime);
    });
    for (final stale in backups.skip(maxFiles < 1 ? 1 : maxFiles)) {
      if (await stale.exists()) {
        await stale.delete();
      }
    }
    return target.path;
  }

  Future<void> _createManagedDirectory(
    String rootPath,
    String relativePath,
  ) async {
    final resolved = await _pathResolver.resolveForWrite(
      rootPath,
      relativePath,
    );
    await Directory(resolved).create();
  }

  int _writePriority(String relativePath) {
    if (relativePath == 'manifest.json') {
      return 2;
    }
    if (relativePath == '.chronicle/vault-index.json') {
      return 1;
    }
    return 0;
  }

  Future<String?> _resolveExistingOrNull(
    String rootPath,
    String relativePath,
  ) async {
    try {
      return await _pathResolver.resolveExisting(rootPath, relativePath);
    } on FileSystemException catch (error) {
      final code = error.osError?.errorCode;
      if (code == 2 || code == 3) {
        return null;
      }
      rethrow;
    }
  }
}
