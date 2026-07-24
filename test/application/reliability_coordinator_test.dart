import 'package:chronicle/application/reliability/reliability_coordinator.dart';
import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/reliability/reliability_models.dart';
import 'package:chronicle/reliability/reliability_service.dart';
import 'package:chronicle/vault/vault_models.dart';
import 'package:chronicle/vault/vault_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('reliability coordinator publishes persisted events', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final data = AppData.empty();
    var notifications = 0;
    VaultScanResult? scan;
    final coordinator = ReliabilityCoordinator(
      repository: InMemoryAppRepository(initialData: data),
      vaultService: VaultService(),
      reliabilityService: ReliabilityService(),
      enabled: true,
      currentData: () => data,
      currentIdentity: () => null,
      diagnosticSnapshot: () => const <String, Object?>{},
      isVaultBusy: () => false,
      setVaultBusy: (_) {},
      setVaultStatus: (_) {},
      setPendingVaultScan: (value) => scan = value,
      undoDepth: () => 0,
      notifyListeners: () => notifications++,
    );

    await coordinator.initialize();
    await coordinator.record(
      stage: ReliabilityStage.system,
      level: ReliabilityLevel.success,
      message: 'checked',
    );

    expect(coordinator.events.single.message, 'checked');
    expect(coordinator.error, isNull);
    expect(notifications, 1);
    expect(scan, isNull);
  });
}
