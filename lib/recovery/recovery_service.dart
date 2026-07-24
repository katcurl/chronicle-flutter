import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../data/backup/staged_restore.dart';
import '../reliability/reliability_service.dart';
import '../vault/vault_service.dart';
import 'recovery_models.dart';
import 'recovery_storage_contract.dart';
import 'recovery_storage_factory.dart';

final class RecoveryService {
  RecoveryService({
    RecoveryStorage? storage,
    VaultService? vaultService,
    ReliabilityService? reliabilityService,
  }) : _storage = storage ?? createRecoveryStorage(),
       _vaultService = vaultService ?? VaultService(),
       _reliabilityService = reliabilityService ?? ReliabilityService(),
       _disabled = false;

  RecoveryService.disabled()
    : _storage = createRecoveryStorage(),
      _vaultService = VaultService(),
      _reliabilityService = ReliabilityService(),
      _disabled = true;

  final RecoveryStorage _storage;
  final VaultService _vaultService;
  final ReliabilityService _reliabilityService;
  final bool _disabled;
  final Uuid _uuid = const Uuid();

  Future<RecoveryInspection> inspectForStartup() {
    return _inspect(includeBackups: false);
  }

  Future<RecoveryInspection> inspect() {
    return _inspect(includeBackups: true);
  }

  Future<String> exportRawDatabase() async {
    if (_disabled) {
      return '';
    }
    final inspection = await inspect();
    final events = <Object?>[];
    try {
      await _reliabilityService.load();
      events.addAll(_reliabilityService.events.map((event) => event.toJson()));
    } on Object {
      // A damaged diagnostic journal must not prevent raw database export.
    }
    final diagnostics = const JsonEncoder.withIndent('  ').convert(
      <String, Object?>{
        'format': 'chronicle-recovery-diagnostics',
        'formatVersion': 1,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'privacy':
            'Technical recovery metadata only. Note and task contents are '
            'stored in the separately exported raw SQLite files.',
        'activeGeneration': inspection.activeGeneration,
        'candidates': <Map<String, Object?>>[
          for (final candidate in inspection.candidates)
            <String, Object?>{
              'id': candidate.id,
              'kind': candidate.kind.name,
              'severity': candidate.severity.name,
              'canRestore': candidate.canRestore,
              'byteLength': candidate.byteLength,
              'modifiedAt': candidate.modifiedAt?.toUtc().toIso8601String(),
            },
        ],
        'events': events,
      },
    );
    return _storage.exportRawDatabase(diagnosticsJson: diagnostics);
  }

  Future<void> restoreCandidate(RecoveryCandidate candidate) async {
    if (_disabled) {
      throw StateError('Восстановление отключено для этого экземпляра.');
    }
    if (!candidate.canRestore) {
      throw StateError('Этот кандидат не прошёл проверку восстановления.');
    }
    if (candidate.kind == RecoveryCandidateKind.stagedRestore) {
      await _recoverInterruptedRestore();
      return;
    }
    if (candidate.kind != RecoveryCandidateKind.automaticBackup &&
        candidate.kind != RecoveryCandidateKind.emergencyBackup) {
      throw StateError('Этот тип кандидата нельзя восстановить автоматически.');
    }
    final entry = candidate.backupEntry;
    if (entry == null || !entry.isValid) {
      throw StateError('Резервная копия не прошла проверку контрольных сумм.');
    }

    final payload = await _vaultService.loadRecoveryBackup(entry);
    final data = _vaultService.validateBackupPayload(payload);
    final probe = await _storage.inspectActiveDatabase();
    final oldGeneration = probe.generation ?? 'recovery-${_uuid.v4()}';
    final newGeneration = _uuid.v4();
    StagedRestoreMarker? marker;
    try {
      marker = await _vaultService.stageRestoreAttachments(
        payload: payload,
        restoreId: _uuid.v4(),
        oldGeneration: oldGeneration,
        newGeneration: newGeneration,
      );
      marker = await _vaultService.updateStagedRestorePhase(
        marker,
        StagedRestorePhase.committing,
      );
      await _storage.installDatabase(data, generation: newGeneration);
      await _vaultService.commitStagedRestoreAttachments(marker);
      marker = await _vaultService.updateStagedRestorePhase(
        marker,
        StagedRestorePhase.committed,
      );
      final attachmentIntegrity =
          await _vaultService.inspectAttachmentIntegrity();
      if (!attachmentIntegrity.isHealthy) {
        throw StateError(
          'Восстановленные вложения не прошли проверку целостности.',
        );
      }
      await _vaultService.finalizeStagedRestore(marker);
    } on Object {
      if (marker != null) {
        final current = await _storage.inspectActiveDatabase();
        final recovered = await _vaultService.recoverStagedRestore(
          current.generation ?? oldGeneration,
        );
        if (recovered != null && current.generation == newGeneration) {
          final integrity = await _vaultService.inspectAttachmentIntegrity();
          if (integrity.isHealthy) {
            await _vaultService.finalizeStagedRestore(recovered);
            return;
          }
        }
      }
      rethrow;
    }
  }

  Future<RecoveryInspection> _inspect({required bool includeBackups}) async {
    if (_disabled) {
      return RecoveryInspection.empty();
    }
    final candidates = <RecoveryCandidate>[];
    String? activeGeneration;
    try {
      final probe = await _storage.inspectActiveDatabase();
      activeGeneration = probe.generation;
      if (probe.exists) {
        final blocking = probe.blockingProblems.isNotEmpty;
        candidates.add(
          RecoveryCandidate(
            id: 'active-database',
            kind: RecoveryCandidateKind.activeDatabase,
            title: 'Активная база данных',
            description:
                blocking
                    ? probe.blockingProblems
                        .map((problem) => problem.message)
                        .join(' ')
                    : 'SQLite quick_check и системные записи читаются успешно.',
            severity:
                blocking
                    ? RecoverySeverity.blocking
                    : RecoverySeverity.information,
            path: probe.path,
            generation: probe.generation,
            byteLength: probe.byteLength,
          ),
        );
      }
    } on Object {
      candidates.add(
        const RecoveryCandidate(
          id: 'active-database-unreadable',
          kind: RecoveryCandidateKind.activeDatabase,
          title: 'Активная база недоступна',
          description:
              'Безопасная проверка не смогла прочитать SQLite. Исходные '
              'файлы не изменялись.',
          severity: RecoverySeverity.blocking,
        ),
      );
    }

    try {
      final archives = await _storage.listDatabaseArchives();
      for (var index = 0; index < archives.length; index++) {
        final archive = archives[index];
        candidates.add(
          RecoveryCandidate(
            id: 'database-archive-$index',
            kind: RecoveryCandidateKind.previousDatabase,
            title: 'Предыдущая база',
            description:
                archive.quickCheckHealthy
                    ? 'Сохранена перед прошлым восстановлением.'
                    : 'Архив не прошёл SQLite quick_check.',
            severity:
                archive.quickCheckHealthy
                    ? RecoverySeverity.information
                    : RecoverySeverity.warning,
            path: archive.path,
            generation: archive.generation,
            modifiedAt: archive.modifiedAt,
            byteLength: archive.byteLength,
          ),
        );
      }
    } on Object {
      // Archives are optional and never make startup less safe.
    }

    try {
      final marker = await _vaultService.readStagedRestoreMarker();
      if (marker != null) {
        candidates.add(
          RecoveryCandidate(
            id: 'staged-restore-${marker.restoreId}',
            kind: RecoveryCandidateKind.stagedRestore,
            title: 'Прерванное восстановление',
            description:
                'Фаза ${marker.phase.name}; активная generation '
                '${activeGeneration ?? 'не определена'}, предыдущая '
                '${marker.oldGeneration}, новая ${marker.newGeneration}.',
            severity: RecoverySeverity.blocking,
            canRestore: true,
            generation: marker.newGeneration,
          ),
        );
      }
    } on Object {
      candidates.add(
        const RecoveryCandidate(
          id: 'damaged-staged-restore-marker',
          kind: RecoveryCandidateKind.stagedRestore,
          title: 'Маркер восстановления повреждён',
          description:
              'Автоматическое продолжение остановлено, чтобы не смешать '
              'поколения базы и вложений.',
          severity: RecoverySeverity.blocking,
        ),
      );
    }

    try {
      final report = await _vaultService.inspectAttachmentIntegrity();
      if (!report.isHealthy) {
        candidates.add(
          RecoveryCandidate(
            id: 'attachment-integrity',
            kind: RecoveryCandidateKind.attachmentIntegrity,
            title: 'Индекс вложений требует проверки',
            description:
                'Обнаружено расхождений: ${report.issues.length}. '
                'Vault не изменялся.',
            severity: RecoverySeverity.blocking,
          ),
        );
      }
    } on UnsupportedError {
      // A platform without Vault support has nothing to inspect.
    } on Object {
      candidates.add(
        const RecoveryCandidate(
          id: 'attachment-integrity-unreadable',
          kind: RecoveryCandidateKind.attachmentIntegrity,
          title: 'Vault не удалось проверить',
          description:
              'Индекс и файлы вложений недоступны для безопасного чтения.',
          severity: RecoverySeverity.blocking,
        ),
      );
    }

    if (includeBackups) {
      try {
        final backups = await _vaultService.listRecoveryBackups();
        for (var index = 0; index < backups.length; index++) {
          final entry = backups[index];
          final automatic = _isAutomaticBackup(entry.path);
          candidates.add(
            RecoveryCandidate(
              id: 'backup-$index-${entry.fileName}',
              kind:
                  automatic
                      ? RecoveryCandidateKind.automaticBackup
                      : RecoveryCandidateKind.emergencyBackup,
              title:
                  automatic
                      ? 'Автоматическая резервная копия'
                      : 'Аварийная резервная копия',
              description:
                  entry.isValid
                      ? 'Контрольные суммы и формат подтверждены.'
                      : 'Копия исключена: проверка формата или сумм не пройдена.',
              severity:
                  entry.isValid
                      ? RecoverySeverity.information
                      : RecoverySeverity.warning,
              canRestore: entry.isValid,
              path: entry.path,
              modifiedAt: entry.modifiedAt,
              byteLength: entry.byteLength,
              backupEntry: entry,
            ),
          );
        }
      } on Object {
        candidates.add(
          const RecoveryCandidate(
            id: 'backup-catalog-unreadable',
            kind: RecoveryCandidateKind.emergencyBackup,
            title: 'Каталог резервных копий недоступен',
            description:
                'Chronicle не смог прочитать каталог, исходные файлы не '
                'изменялись.',
            severity: RecoverySeverity.warning,
          ),
        );
      }
    }

    return RecoveryInspection(
      candidates: candidates,
      activeGeneration: activeGeneration,
      inspectedAt: DateTime.now().toUtc(),
    );
  }

  Future<void> _recoverInterruptedRestore() async {
    final marker = await _vaultService.readStagedRestoreMarker();
    if (marker == null) {
      throw StateError('Маркер прерванного восстановления больше не найден.');
    }
    final probe = await _storage.inspectActiveDatabase();
    final currentGeneration = probe.generation;
    if (currentGeneration == null) {
      throw StateError('Generation активной базы не определена.');
    }
    final recovered = await _vaultService.recoverStagedRestore(
      currentGeneration,
    );
    if (recovered != null) {
      final integrity = await _vaultService.inspectAttachmentIntegrity();
      if (!integrity.isHealthy) {
        throw StateError(
          'Вложения после продолжения восстановления повреждены.',
        );
      }
      await _vaultService.finalizeStagedRestore(recovered);
    }
  }
}

bool _isAutomaticBackup(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.contains('/Automatic/');
}
