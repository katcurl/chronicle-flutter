import 'package:chronicle/vault/vault_backend.dart';

class TestVaultBackend extends VaultBackend {
  final Map<String, String> files = {};

  @override
  Future<String?> resolveRootPath() async => '/memory/Chronicle Vault';

  @override
  Future<String?> readTextFile(String rootPath, String relativePath) async {
    return files[relativePath];
  }

  @override
  Future<void> writeFiles({
    required String rootPath,
    required Map<String, String> files,
    required Set<String> staleManagedPaths,
  }) async {
    for (final path in staleManagedPaths) {
      this.files.remove(path);
    }

    this.files.addAll(files);
  }
}
