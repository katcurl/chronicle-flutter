import 'dart:typed_data';

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

  Future<void> writeTextFile({
    required String rootPath,
    required String relativePath,
    required String content,
  }) async {
    throw UnsupportedError('Markdown Vault is unavailable on this platform.');
  }

  Future<Map<String, String>> listTextFiles({
    required String rootPath,
    required String directory,
    required String extension,
  }) async => <String, String>{};

  Future<void> deleteFiles({
    required String rootPath,
    required Set<String> relativePaths,
  }) async {}

  Future<Map<String, Uint8List>> listBinaryFiles({
    required String rootPath,
    required String directory,
  }) async => <String, Uint8List>{};

  Future<Uint8List?> readBinaryFile(
    String rootPath,
    String relativePath,
  ) async {
    return null;
  }

  Future<bool> fileExists(String rootPath, String relativePath) async => false;

  Future<void> writeBinaryFile({
    required String rootPath,
    required String relativePath,
    required Uint8List bytes,
  }) async {
    throw UnsupportedError('Attachments are unavailable on this platform.');
  }

  Future<PickedVaultFile?> pickAttachment() async => null;

  Future<String?> saveBackup({
    required String fileName,
    required Uint8List bytes,
  }) async => null;

  Future<PickedVaultFile?> pickBackup() async => null;

  Future<List<VaultBackupFileInfo>> listAutomaticBackups({
    required String rootPath,
  }) async => const <VaultBackupFileInfo>[];

  Future<PickedVaultFile?> readBackupPath(String path) async => null;

  Future<String> writeEmergencyBackup({
    required String rootPath,
    required String fileName,
    required Uint8List bytes,
  }) async {
    throw UnsupportedError('Backups are unavailable on this platform.');
  }

  Future<String> writeAutomaticBackup({
    required String rootPath,
    required String fileName,
    required Uint8List bytes,
    int maxFiles = 5,
  }) async {
    throw UnsupportedError('Backups are unavailable on this platform.');
  }
}
