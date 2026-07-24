import '../models/app_models.dart';
import 'recovery_storage_contract.dart';

final class UnsupportedRecoveryStorage implements RecoveryStorage {
  @override
  Future<String> exportRawDatabase({required String diagnosticsJson}) {
    throw UnsupportedError('Recovery export is unavailable on this platform.');
  }

  @override
  Future<RecoveryDatabaseProbe> inspectActiveDatabase() async {
    return const RecoveryDatabaseProbe(
      path: '',
      exists: false,
      byteLength: 0,
      schemaVersion: null,
      generation: null,
      quickCheckHealthy: true,
      blockingProblems: <RecoveryProblem>[],
    );
  }

  @override
  Future<void> installDatabase(AppData data, {required String generation}) {
    throw UnsupportedError('Recovery restore is unavailable on this platform.');
  }

  @override
  Future<List<RecoveryDatabaseArchive>> listDatabaseArchives() async =>
      const <RecoveryDatabaseArchive>[];
}
