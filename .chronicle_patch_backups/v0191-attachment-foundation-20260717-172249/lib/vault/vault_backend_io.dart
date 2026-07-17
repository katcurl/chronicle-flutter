import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const _vaultPathKey = 'chronicle_vault_path';

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
    final root = Directory(rootPath);
    await root.create(recursive: true);

    for (final relativePath in staleManagedPaths) {
      final target = File(p.join(rootPath, _native(relativePath)));
      if (await target.exists()) {
        await target.delete();
      }
    }

    for (final entry in files.entries) {
      final target = File(p.join(rootPath, _native(entry.key)));
      await target.parent.create(recursive: true);
      final temporary = File('${target.path}.tmp');
      await temporary.writeAsString(entry.value, flush: true);
      if (await target.exists()) {
        await target.delete();
      }
      await temporary.rename(target.path);
    }

    await Directory(p.join(rootPath, 'Attachments')).create(recursive: true);
    await Directory(p.join(rootPath, 'Templates')).create(recursive: true);
    await Directory(
      p.join(rootPath, '.chronicle', 'Backups'),
    ).create(recursive: true);
  }

  Future<String?> readTextFile(String rootPath, String relativePath) async {
    final file = File(p.join(rootPath, _native(relativePath)));
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString();
  }

  Future<Map<String, String>> listTextFiles({
    required String rootPath,
    required String directory,
    required String extension,
  }) async {
    final base = Directory(p.join(rootPath, _native(directory)));
    if (!await base.exists()) {
      return <String, String>{};
    }

    final result = <String, String>{};
    await for (final entity in base.list(recursive: true, followLinks: false)) {
      if (entity is! File ||
          !entity.path.toLowerCase().endsWith(extension.toLowerCase())) {
        continue;
      }
      final relative = p
          .relative(entity.path, from: rootPath)
          .replaceAll(p.separator, '/');
      result[relative] = await entity.readAsString();
    }
    return result;
  }

  Future<void> deleteFiles({
    required String rootPath,
    required Set<String> relativePaths,
  }) async {
    final normalizedRoot = p.normalize(p.absolute(rootPath));
    for (final relativePath in relativePaths) {
      final targetPath = p.normalize(
        p.absolute(p.join(rootPath, _native(relativePath))),
      );
      if (targetPath != normalizedRoot &&
          !p.isWithin(normalizedRoot, targetPath)) {
        continue;
      }
      final target = File(targetPath);
      if (await target.exists()) {
        await target.delete();
      }
    }
  }

  Future<Map<String, Uint8List>> listBinaryFiles({
    required String rootPath,
    required String directory,
  }) async {
    final base = Directory(p.join(rootPath, _native(directory)));
    if (!await base.exists()) {
      return <String, Uint8List>{};
    }
    final result = <String, Uint8List>{};
    await for (final entity in base.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final relative = p
          .relative(entity.path, from: rootPath)
          .replaceAll(p.separator, '/');
      result[relative] = await entity.readAsBytes();
    }
    return result;
  }

  Future<bool> fileExists(String rootPath, String relativePath) {
    return File(p.join(rootPath, _native(relativePath))).exists();
  }

  Future<void> writeBinaryFile({
    required String rootPath,
    required String relativePath,
    required Uint8List bytes,
  }) async {
    final target = File(p.join(rootPath, _native(relativePath)));
    await target.parent.create(recursive: true);
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsBytes(bytes, flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await temporary.rename(target.path);
  }

  Future<PickedVaultFile?> pickAttachment() async {
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
    final directory = Directory(
      p.join(rootPath, '.chronicle', 'Backups', 'Automatic'),
    );
    if (!await directory.exists()) {
      return const <VaultBackupFileInfo>[];
    }

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
    final target = File(p.join(rootPath, '.chronicle', 'Backups', fileName));
    await target.parent.create(recursive: true);
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsBytes(bytes, flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await temporary.rename(target.path);
    return target.path;
  }

  Future<String> writeAutomaticBackup({
    required String rootPath,
    required String fileName,
    required Uint8List bytes,
    int maxFiles = 5,
  }) async {
    final directory = Directory(
      p.join(rootPath, '.chronicle', 'Backups', 'Automatic'),
    );
    await directory.create(recursive: true);
    final target = File(p.join(directory.path, fileName));
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsBytes(bytes, flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await temporary.rename(target.path);

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

  String _native(String relativePath) =>
      relativePath.replaceAll('/', p.separator);
}
