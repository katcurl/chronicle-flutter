import 'package:chronicle/vault/vault_backend.dart';

/// UI-тесты не проверяют работу файловой системы.
/// Настоящий Vault отдельно проверяется в vault_service_test.dart
/// и vault_two_way_test.dart.
class TestVaultBackend extends VaultBackend {
  @override
  Future<String?> resolveRootPath() async => null;
}
