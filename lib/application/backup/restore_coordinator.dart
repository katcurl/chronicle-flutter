import 'package:uuid/uuid.dart';

import '../../data/backup/staged_restore.dart';
import '../../data/repositories/app_repository.dart';
import '../../models/app_models.dart';
import '../../reliability/reliability_models.dart';
import '../../sync/sync_models.dart';
import '../../vault/vault_models.dart';
import '../../vault/vault_service.dart';

typedef RestoreReliabilityRecorder =
    Future<void> Function({
      required ReliabilityStage stage,
      required ReliabilityLevel level,
      required String message,
      Map<String, Object?> details,
    });

final class RestoreCoordinator {
  RestoreCoordinator({
    required AppRepository repository,
    required VaultService vaultService,
    required AppData Function() currentData,
    required DeviceIdentity? Function() currentIdentity,
    required bool Function() isBusy,
    required void Function(bool value) setBusy,
    required Future<void> Function() reloadAfterRestore,
    required Future<void> Function() refreshBackupCatalog,
    required RestoreReliabilityRecorder recordReliability,
    required void Function() notifyListeners,
    RestoreCutPointCallback? restoreCutPoint,
    Uuid uuid = const Uuid(),
  }) : _repository = repository,
       _vaultService = vaultService,
       _currentData = currentData,
       _currentIdentity = currentIdentity,
       _isBusy = isBusy,
       _setBusy = setBusy,
       _reloadAfterRestore = reloadAfterRestore,
       _refreshBackupCatalog = refreshBackupCatalog,
       _recordReliability = recordReliability,
       _notifyListeners = notifyListeners,
       _restoreCutPoint = restoreCutPoint,
       _uuid = uuid;

  final AppRepository _repository;
  final VaultService _vaultService;
  final AppData Function() _currentData;
  final DeviceIdentity? Function() _currentIdentity;
  final bool Function() _isBusy;
  final void Function(bool value) _setBusy;
  final Future<void> Function() _reloadAfterRestore;
  final Future<void> Function() _refreshBackupCatalog;
  final RestoreReliabilityRecorder _recordReliability;
  final void Function() _notifyListeners;
  final RestoreCutPointCallback? _restoreCutPoint;
  final Uuid _uuid;

  String? lastEmergencyBackupPath;
  bool lastRestoreRolledBack = false;

  Future<void> restore(BackupImportPayload payload) async {
    if (_isBusy()) {
      return;
    }
    _setBusy(true);
    lastRestoreRolledBack = false;
    _notifyListeners();
    EmergencyBackupSnapshot? emergencySnapshot;
    StagedRestoreMarker? restoreMarker;
    try {
      await _recordReliability(
        stage: ReliabilityStage.restore,
        level: ReliabilityLevel.info,
        message: 'Начато восстановление проверенной резервной копии.',
        details: <String, Object?>{
          'sourceName': payload.sourceName,
          'formatVersion': payload.preview.formatVersion,
          'checksumsVerified': payload.preview.checksumsVerified,
        },
      );
      final candidate = _vaultService.validateBackupPayload(payload);
      final snapshot = await _vaultService.createEmergencyBackupSnapshot(
        data: _currentData(),
        identity: _currentIdentity(),
      );
      emergencySnapshot = snapshot;
      lastEmergencyBackupPath = snapshot.path;

      final oldGeneration = await _repository.ensureDataGeneration();
      final newGeneration = _uuid.v4();
      restoreMarker = await _vaultService.stageRestoreAttachments(
        payload: payload,
        restoreId: _uuid.v4(),
        oldGeneration: oldGeneration,
        newGeneration: newGeneration,
      );
      await _runCutPoint(RestoreCutPoint.afterStaged);

      restoreMarker = await _vaultService.updateStagedRestorePhase(
        restoreMarker,
        StagedRestorePhase.committing,
      );
      await _runCutPoint(RestoreCutPoint.afterCommittingMarker);

      await _repository.replaceAllForRestore(
        candidate,
        generation: newGeneration,
      );
      await _runCutPoint(RestoreCutPoint.afterDatabaseCommit);

      await _vaultService.commitStagedRestoreAttachments(restoreMarker);
      await _runCutPoint(RestoreCutPoint.afterAttachmentCommit);

      restoreMarker = await _vaultService.updateStagedRestorePhase(
        restoreMarker,
        StagedRestorePhase.committed,
      );
      await _runCutPoint(RestoreCutPoint.afterCommittedMarker);

      await _reloadAfterRestore();
      final attachmentIntegrity =
          await _vaultService.inspectAttachmentIntegrity();
      if (!attachmentIntegrity.isHealthy) {
        throw StateError(
          'Восстановленные вложения не прошли проверку целостности.',
        );
      }
      await _vaultService.finalizeStagedRestore(restoreMarker);

      await _refreshBackupCatalog();
      await _recordReliability(
        stage: ReliabilityStage.restore,
        level: ReliabilityLevel.success,
        message: 'Резервная копия успешно восстановлена.',
        details: <String, Object?>{
          'projects': payload.preview.projectCount,
          'tasks': payload.preview.taskCount,
          'notes': payload.preview.noteCount,
          'timeEntries': payload.preview.entryCount,
          'attachments': payload.preview.attachmentCount,
          'emergencyBackupCreated': lastEmergencyBackupPath != null,
        },
      );
    } on RestoreInterruption {
      rethrow;
    } on Object catch (error) {
      final recoveredCommitted = await _tryRecoverCommitted(restoreMarker);
      if (recoveredCommitted) {
        await _refreshBackupCatalog();
        await _recordReliability(
          stage: ReliabilityStage.restore,
          level: ReliabilityLevel.warning,
          message:
              'Восстановление завершено через recovery после промежуточной '
              'ошибки.',
          details: <String, Object?>{
            'error': error.toString(),
            'emergencyBackupPath': emergencySnapshot?.path,
          },
        );
        return;
      }
      await _recordReliability(
        stage: ReliabilityStage.restore,
        level: ReliabilityLevel.error,
        message: 'Восстановление резервной копии не выполнено.',
        details: <String, Object?>{
          'error': error.toString(),
          'rolledBack': lastRestoreRolledBack,
          'emergencyBackupPath': emergencySnapshot?.path,
        },
      );
      rethrow;
    } finally {
      _setBusy(false);
      _notifyListeners();
    }
  }

  Future<bool> _tryRecoverCommitted(StagedRestoreMarker? marker) async {
    if (marker == null) {
      return false;
    }
    try {
      final generation = await _repository.ensureDataGeneration();
      final recovered = await _vaultService.recoverStagedRestore(generation);
      lastRestoreRolledBack = recovered == null;
      if (recovered == null) {
        return false;
      }
      await _reloadAfterRestore();
      final integrity = await _vaultService.inspectAttachmentIntegrity();
      if (!integrity.isHealthy) {
        return false;
      }
      await _vaultService.finalizeStagedRestore(recovered);
      return true;
    } on Object {
      // The durable marker is intentionally retained for startup recovery.
      return false;
    }
  }

  Future<void> _runCutPoint(RestoreCutPoint point) async {
    await _restoreCutPoint?.call(point);
  }
}
