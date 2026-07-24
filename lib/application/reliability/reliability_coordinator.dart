import '../../data/repositories/app_repository.dart';
import '../../models/app_models.dart';
import '../../reliability/release_readiness.dart';
import '../../reliability/reliability_models.dart';
import '../../reliability/reliability_service.dart';
import '../../sync/sync_models.dart';
import '../../vault/vault_models.dart';
import '../../vault/vault_service.dart';

final class ReliabilityCoordinator {
  ReliabilityCoordinator({
    required AppRepository repository,
    required VaultService vaultService,
    required ReliabilityService reliabilityService,
    required bool enabled,
    required AppData Function() currentData,
    required DeviceIdentity? Function() currentIdentity,
    required Map<String, Object?> Function() diagnosticSnapshot,
    required bool Function() isVaultBusy,
    required void Function(bool value) setVaultBusy,
    required void Function(VaultStatus value) setVaultStatus,
    required void Function(VaultScanResult? value) setPendingVaultScan,
    required int Function() undoDepth,
    required void Function() notifyListeners,
  }) : _repository = repository,
       _vaultService = vaultService,
       _reliabilityService = reliabilityService,
       _enabled = enabled,
       _currentData = currentData,
       _currentIdentity = currentIdentity,
       _diagnosticSnapshot = diagnosticSnapshot,
       _isVaultBusy = isVaultBusy,
       _setVaultBusy = setVaultBusy,
       _setVaultStatus = setVaultStatus,
       _setPendingVaultScan = setPendingVaultScan,
       _undoDepth = undoDepth,
       _notifyListeners = notifyListeners;

  final AppRepository _repository;
  final VaultService _vaultService;
  final ReliabilityService _reliabilityService;
  final bool _enabled;
  final AppData Function() _currentData;
  final DeviceIdentity? Function() _currentIdentity;
  final Map<String, Object?> Function() _diagnosticSnapshot;
  final bool Function() _isVaultBusy;
  final void Function(bool value) _setVaultBusy;
  final void Function(VaultStatus value) _setVaultStatus;
  final void Function(VaultScanResult? value) _setPendingVaultScan;
  final int Function() _undoDepth;
  final void Function() _notifyListeners;

  List<BackupCatalogEntry> automaticBackups = const <BackupCatalogEntry>[];
  bool backupCatalogBusy = false;
  String? backupCatalogError;

  List<ReliabilityEvent> events = const <ReliabilityEvent>[];
  DateTime? lastAutomaticBackupAt;
  String? lastAutomaticBackupPath;
  bool busy = false;
  String? error;

  ReleaseReadinessReport? releaseReadinessReport;
  bool releaseReadinessBusy = false;
  String? releaseReadinessError;

  void resetReleaseReadiness() {
    releaseReadinessReport = null;
    releaseReadinessError = null;
  }

  Future<void> initialize() async {
    if (!_enabled) {
      return;
    }
    try {
      await _reliabilityService.load();
      _refreshState();
    } on Object catch (caught) {
      error = caught.toString();
    }
  }

  Future<void> refresh({bool notify = true}) async {
    if (!_enabled) {
      return;
    }
    try {
      await _reliabilityService.load();
      error = null;
      _refreshState();
    } on Object catch (caught) {
      error = caught.toString();
    }
    if (notify) {
      _notifyListeners();
    }
  }

  Future<void> record({
    required ReliabilityStage stage,
    required ReliabilityLevel level,
    required String message,
    String? peerDeviceId,
    Map<String, Object?> details = const <String, Object?>{},
    bool notify = true,
  }) async {
    if (!_enabled) {
      return;
    }
    try {
      await _reliabilityService.record(
        stage: stage,
        level: level,
        message: message,
        peerDeviceId: peerDeviceId,
        details: details,
      );
      error = null;
      _refreshState();
    } on Object catch (caught) {
      error = caught.toString();
    }
    if (notify) {
      _notifyListeners();
    }
  }

  Future<BackupExportResult?> createSafetyBackup() async {
    if (busy || _isVaultBusy()) {
      return null;
    }
    busy = true;
    error = null;
    _notifyListeners();
    try {
      final result = await _vaultService.createAutomaticBackup(
        data: _currentData(),
        identity: _currentIdentity(),
        maxFiles: 5,
      );
      await _reliabilityService.markAutomaticBackup(
        createdAt: result.preview.exportedAt,
        path: result.path,
      );
      _refreshState();
      await record(
        stage: ReliabilityStage.backup,
        level: ReliabilityLevel.success,
        message: 'Создана локальная страховочная копия Chronicle.',
        details: <String, Object?>{
          'fileName': result.fileName,
          'projects': result.preview.projectCount,
          'tasks': result.preview.taskCount,
          'notes': result.preview.noteCount,
          'timeEntries': result.preview.entryCount,
          'attachments': result.preview.attachmentCount,
          'retention': 5,
        },
        notify: false,
      );
      await refreshBackupCatalog(notify: false);
      return result;
    } on Object catch (caught) {
      await record(
        stage: ReliabilityStage.backup,
        level: ReliabilityLevel.error,
        message: 'Не удалось создать локальную страховочную копию.',
        details: <String, Object?>{'error': caught.toString()},
        notify: false,
      );
      error = caught.toString();
      rethrow;
    } finally {
      busy = false;
      _notifyListeners();
    }
  }

  Future<void> createAutomaticBackupIfDue() async {
    if (!_enabled || !_reliabilityService.automaticBackupDue()) {
      return;
    }
    try {
      await createSafetyBackup();
    } on Object {
      // The failure has already been recorded and must not block startup.
    }
  }

  Future<String?> exportDiagnosticReport() async {
    if (!_enabled || busy) {
      return null;
    }
    busy = true;
    error = null;
    _notifyListeners();
    try {
      return await _reliabilityService.exportDiagnosticReport(
        snapshot: _diagnosticSnapshot(),
      );
    } on Object catch (caught) {
      error = caught.toString();
      rethrow;
    } finally {
      busy = false;
      _notifyListeners();
    }
  }

  Future<void> clearDiagnosticLog() async {
    if (!_enabled || busy) {
      return;
    }
    busy = true;
    _notifyListeners();
    try {
      await _reliabilityService.clearEvents();
      _refreshState();
      error = null;
    } finally {
      busy = false;
      _notifyListeners();
    }
  }

  Future<void> refreshBackupCatalog({bool notify = true}) async {
    if (backupCatalogBusy) {
      return;
    }
    backupCatalogBusy = true;
    backupCatalogError = null;
    if (notify) {
      _notifyListeners();
    }
    try {
      automaticBackups = await _vaultService.listAutomaticBackups();
    } on Object catch (caught) {
      automaticBackups = const <BackupCatalogEntry>[];
      backupCatalogError = caught.toString();
    } finally {
      backupCatalogBusy = false;
      if (notify) {
        _notifyListeners();
      }
    }
  }

  Future<BackupImportPayload> loadAutomaticBackup(BackupCatalogEntry entry) =>
      _vaultService.loadAutomaticBackup(entry);

  Future<BackupExportResult?> exportBackupFile() async {
    if (_isVaultBusy()) {
      return null;
    }
    _setVaultBusy(true);
    _notifyListeners();
    try {
      final status = await _vaultService.writeMirror(_currentData());
      _setVaultStatus(status);
      final result = await _vaultService.exportBackup(
        data: _currentData(),
        identity: _currentIdentity(),
      );
      if (result != null) {
        await record(
          stage: ReliabilityStage.backup,
          level: ReliabilityLevel.success,
          message: 'Пользователь экспортировал переносимую копию Chronicle.',
          details: <String, Object?>{
            'fileName': result.fileName,
            'notes': result.preview.noteCount,
            'attachments': result.preview.attachmentCount,
          },
          notify: false,
        );
      }
      return result;
    } on Object catch (caught) {
      await record(
        stage: ReliabilityStage.backup,
        level: ReliabilityLevel.error,
        message: 'Экспорт переносимой копии не выполнен.',
        details: <String, Object?>{'error': caught.toString()},
        notify: false,
      );
      rethrow;
    } finally {
      _setVaultBusy(false);
      _notifyListeners();
    }
  }

  Future<BackupImportPayload?> pickBackupFile() => _vaultService.pickBackup();

  Future<ReleaseReadinessReport> runReleaseReadinessAudit() async {
    if (releaseReadinessBusy) {
      final existing = releaseReadinessReport;
      if (existing != null) {
        return existing;
      }
      throw StateError('Проверка готовности уже выполняется.');
    }
    releaseReadinessBusy = true;
    releaseReadinessError = null;
    _notifyListeners();
    try {
      final data = _currentData();
      final integrity = ChronicleIntegrityAuditor.audit(data);
      final rawBackup = await _repository.exportJson();
      final roundTrip = ChronicleIntegrityAuditor.verifyBackupRoundTrip(
        rawBackup,
      );
      final inspectedVault = await _vaultService.inspect();
      VaultScanResult? readinessScan;
      AttachmentIntegrityReport? attachmentIntegrity;
      if (inspectedVault.supported &&
          inspectedVault.rootPath.isNotEmpty &&
          !inspectedVault.readOnly) {
        readinessScan = await _vaultService.scan(data);
        attachmentIntegrity = await _vaultService.inspectAttachmentIntegrity();
      }
      _setPendingVaultScan(readinessScan);
      automaticBackups = await _vaultService.listAutomaticBackups();
      final status = inspectedVault.copyWith(
        pendingChangeCount: readinessScan?.pendingCount ?? 0,
        conflictCount: readinessScan?.conflicts.length ?? 0,
        missingFileCount: readinessScan?.missingFiles.length ?? 0,
      );
      _setVaultStatus(status);
      final report = ReleaseReadinessReport(
        checkedAt: DateTime.now(),
        integrity: integrity,
        backupRoundTrip: roundTrip,
        vaultStatus: status,
        undoDepth: _undoDepth(),
        automaticBackupCount:
            automaticBackups.where((entry) => entry.isValid).length,
        pendingConflictCount:
            readinessScan?.conflicts.length ?? status.conflictCount,
        attachmentIntegrity: attachmentIntegrity,
      );
      releaseReadinessReport = report;
      var level = ReliabilityLevel.warning;
      if (report.ready) {
        level = ReliabilityLevel.success;
      } else if (integrity.errorCount > 0 || !roundTrip.valid) {
        level = ReliabilityLevel.error;
      }
      await record(
        stage: ReliabilityStage.system,
        level: level,
        message:
            report.ready
                ? 'Проверка готовности Chronicle 1.0 завершена успешно.'
                : 'Проверка готовности Chronicle 1.0 требует внимания.',
        details: <String, Object?>{
          'integrityErrors': integrity.errorCount,
          'integrityWarnings': integrity.warningCount,
          'backupRoundTrip': roundTrip.valid,
          'vaultFormatVersion': status.formatVersion,
          'vaultReadOnly': status.readOnly,
          'pendingVaultChanges': status.pendingChangeCount,
          'pendingConflicts': report.pendingConflictCount,
          'attachmentIntegrityIssues': attachmentIntegrity?.issues.length ?? 0,
          'validAutomaticBackups': report.automaticBackupCount,
        },
        notify: false,
      );
      return report;
    } on Object catch (caught) {
      releaseReadinessError = caught.toString();
      rethrow;
    } finally {
      releaseReadinessBusy = false;
      _notifyListeners();
    }
  }

  void _refreshState() {
    events = _reliabilityService.events;
    lastAutomaticBackupAt = _reliabilityService.lastAutomaticBackupAt;
    lastAutomaticBackupPath = _reliabilityService.lastAutomaticBackupPath;
  }
}
