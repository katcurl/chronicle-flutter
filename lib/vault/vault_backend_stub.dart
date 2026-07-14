import 'dart:typed_data';

class PickedVaultFile {
  const PickedVaultFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class VaultBackend {
  Future<String?> resolveRootPath() async => null;

  Future<String?> chooseRootPath() async => null;

  Future<void> writeFiles({
    required String rootPath,
    required Map<String, String> files,
    required Set<String> staleManagedPaths,
  }) async {
    throw UnsupportedError('Markdown Vault is unavailable on this platform.');
  }

  Future<String?> readTextFile(String rootPath, String relativePath) async =>
      null;

  Future<bool> fileExists(String rootPath, String relativePath) async => false;

  Future<String?> saveBackup({
    required String fileName,
    required Uint8List bytes,
  }) async => null;

  Future<PickedVaultFile?> pickBackup() async => null;

  Future<String> writeEmergencyBackup({
    required String rootPath,
    required String fileName,
    required Uint8List bytes,
  }) async {
    throw UnsupportedError('Backups are unavailable on this platform.');
  }
}
