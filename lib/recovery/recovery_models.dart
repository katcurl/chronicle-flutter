import '../vault/vault_models.dart';

enum RecoveryCandidateKind {
  activeDatabase,
  previousDatabase,
  stagedRestore,
  automaticBackup,
  emergencyBackup,
  attachmentIntegrity,
  startupFailure,
}

enum RecoverySeverity { information, warning, blocking }

final class RecoveryCandidate {
  const RecoveryCandidate({
    required this.id,
    required this.kind,
    required this.title,
    required this.description,
    required this.severity,
    this.canRestore = false,
    this.path,
    this.generation,
    this.modifiedAt,
    this.byteLength,
    this.backupEntry,
  });

  final String id;
  final RecoveryCandidateKind kind;
  final String title;
  final String description;
  final RecoverySeverity severity;
  final bool canRestore;
  final String? path;
  final String? generation;
  final DateTime? modifiedAt;
  final int? byteLength;
  final BackupCatalogEntry? backupEntry;

  bool get blocksStartup => severity == RecoverySeverity.blocking;
}

final class RecoveryInspection {
  RecoveryInspection({
    required List<RecoveryCandidate> candidates,
    this.activeGeneration,
    this.inspectedAt,
  }) : candidates = List<RecoveryCandidate>.unmodifiable(candidates);

  factory RecoveryInspection.empty() =>
      RecoveryInspection(candidates: const <RecoveryCandidate>[]);

  final List<RecoveryCandidate> candidates;
  final String? activeGeneration;
  final DateTime? inspectedAt;

  bool get hasBlockingProblems =>
      candidates.any((candidate) => candidate.blocksStartup);
}
