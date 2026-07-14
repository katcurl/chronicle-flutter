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
      final target = File(p.join(rootPath, relativePath));
      if (await target.exists()) {
        await target.delete();
      }
    }

    for (final entry in files.entries) {
      final target = File(p.join(rootPath, entry.key));
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
    final file = File(p.join(rootPath, relativePath));
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString();
  }

  Future<bool> fileExists(String rootPath, String relativePath) {
    return File(p.join(rootPath, relativePath)).exists();
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
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Выбрать резервную копию Chronicle',
      type: FileType.custom,
      allowedExtensions: const ['chronicle'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final selected = result.files.single;
    final bytes = selected.bytes ?? await selected.xFile.readAsBytes();
    return PickedVaultFile(name: selected.name, bytes: bytes);
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
}
