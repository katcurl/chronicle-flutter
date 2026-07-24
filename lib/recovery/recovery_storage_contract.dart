import '../models/app_models.dart';

final class RecoveryProblem {
  const RecoveryProblem({required this.code, required this.message});

  final String code;
  final String message;
}

final class RecoveryDatabaseProbe {
  const RecoveryDatabaseProbe({
    required this.path,
    required this.exists,
    required this.byteLength,
    required this.schemaVersion,
    required this.generation,
    required this.quickCheckHealthy,
    required this.blockingProblems,
  });

  final String path;
  final bool exists;
  final int byteLength;
  final int? schemaVersion;
  final String? generation;
  final bool quickCheckHealthy;
  final List<RecoveryProblem> blockingProblems;

  bool get isHealthy => exists && quickCheckHealthy && blockingProblems.isEmpty;
}

final class RecoveryDatabaseArchive {
  const RecoveryDatabaseArchive({
    required this.path,
    required this.modifiedAt,
    required this.byteLength,
    required this.quickCheckHealthy,
    this.generation,
  });

  final String path;
  final DateTime modifiedAt;
  final int byteLength;
  final bool quickCheckHealthy;
  final String? generation;
}

abstract interface class RecoveryStorage {
  Future<RecoveryDatabaseProbe> inspectActiveDatabase();

  Future<List<RecoveryDatabaseArchive>> listDatabaseArchives();

  Future<String> exportRawDatabase({required String diagnosticsJson});

  Future<void> installDatabase(AppData data, {required String generation});
}
