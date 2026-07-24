import '../../data/repositories/app_repository.dart';
import '../../models/app_models.dart';
import '../../reliability/reliability_models.dart';
import '../../sync/lan_sync_models.dart';
import '../../sync/lan_sync_resilience.dart';
import '../../sync/lan_sync_service.dart';
import '../../sync/lan_sync_transport.dart';
import '../../sync/sync_models.dart';

typedef SyncReliabilityRecorder =
    Future<void> Function({
      required ReliabilityStage stage,
      required ReliabilityLevel level,
      required String message,
      String? peerDeviceId,
      Map<String, Object?> details,
    });

final class SyncCoordinator {
  SyncCoordinator({
    required AppRepository repository,
    required AppData Function() currentData,
    required void Function(AppData data) replaceData,
    required Future<void> Function() rebuildAllNoteLinks,
    required void Function() scheduleVaultMirror,
    required void Function() onAttachmentRefresh,
    required SyncReliabilityRecorder recordReliability,
    required void Function() notifyListeners,
    LanSyncService? lanSyncService,
  }) : _repository = repository,
       _currentData = currentData,
       _replaceData = replaceData,
       _rebuildAllNoteLinks = rebuildAllNoteLinks,
       _scheduleVaultMirror = scheduleVaultMirror,
       _onAttachmentRefresh = onAttachmentRefresh,
       _recordReliability = recordReliability,
       _notifyListeners = notifyListeners,
       _lanSyncService = lanSyncService;

  final AppRepository _repository;
  final AppData Function() _currentData;
  final void Function(AppData data) _replaceData;
  final Future<void> Function() _rebuildAllNoteLinks;
  final void Function() _scheduleVaultMirror;
  final void Function() _onAttachmentRefresh;
  final SyncReliabilityRecorder _recordReliability;
  final void Function() _notifyListeners;
  final LanSyncService? _lanSyncService;

  DeviceIdentity? deviceIdentity;
  List<TrustedDevice> trustedDevices = <TrustedDevice>[];
  List<ChangeRecord> recentChanges = <ChangeRecord>[];
  List<SyncCursor> syncCursors = <SyncCursor>[];
  SyncPreferences syncPreferences = const SyncPreferences();
  int journalEntryCount = 0;
  int journalPayloadBytes = 0;
  JournalCompactionResult? lastJournalCompaction;
  bool lanSyncBusy = false;
  String? lanSyncPeerDeviceId;
  LanSyncReport? lastLanSyncReport;

  Future<void> refreshFoundation({bool notify = true}) async {
    deviceIdentity = await _repository.ensureDeviceIdentity();
    trustedDevices = await _repository.loadTrustedDevices();
    syncPreferences = await _repository.loadSyncPreferences();
    final journalBootstrapped = await _repository.isSyncJournalBootstrapped();
    if (!journalBootstrapped) {
      await _bootstrapJournal();
      await _repository.markSyncJournalBootstrapped();
    }
    final compaction = await _repository.compactJournal();
    lastJournalCompaction = compaction;
    journalEntryCount = compaction.entryCountAfter;
    journalPayloadBytes = compaction.payloadBytesAfter;
    recentChanges = await _repository.loadRecentChanges(limit: 20);
    syncCursors = await _repository.loadSyncCursors();
    if (notify) {
      _notifyListeners();
    }
  }

  Future<SyncJournalBatch> buildOutgoingBatch({
    required String peerDeviceId,
    required int afterSequence,
    int limit = 200,
  }) {
    return _repository.loadOutgoingChanges(
      peerDeviceId: peerDeviceId,
      afterSequence: afterSequence,
      limit: limit,
    );
  }

  Future<JournalCompactionResult> compactJournal({
    int maxEntries = defaultMaxJournalEntries,
    int maxPayloadBytes = defaultMaxJournalPayloadBytes,
  }) async {
    final result = await _repository.compactJournal(
      maxEntries: maxEntries,
      maxPayloadBytes: maxPayloadBytes,
    );
    lastJournalCompaction = result;
    journalEntryCount = result.entryCountAfter;
    journalPayloadBytes = result.payloadBytesAfter;
    recentChanges = await _repository.loadRecentChanges(limit: 20);
    _notifyListeners();
    return result;
  }

  Future<SyncApplyResult> applyIncomingChanges(
    List<ChangeRecord> changes,
  ) async {
    final result = await _repository.applyRemoteChanges(changes);
    if (result.insertedCount == 0) {
      return result;
    }
    _replaceData(await _repository.load());
    await _rebuildAllNoteLinks();
    await refreshFoundation(notify: false);
    if (result.changedData) {
      _scheduleVaultMirror();
    }
    _notifyListeners();
    return result;
  }

  Future<LanSyncHostSession> startLanHost(String peerDeviceId) {
    final service = _requireLanService();
    return service.startHost(
      peerDeviceId: peerDeviceId,
      onRemoteApplied: (_) => refreshAfterLanSync(),
    );
  }

  Future<LanSyncReport> syncFromLanOffer(
    String rawOffer, {
    required String expectedPeerDeviceId,
    LanSyncProgressCallback? onProgress,
    LanSyncCancellationToken? cancellationToken,
  }) async {
    if (lanSyncBusy) {
      throw StateError('Синхронизация уже выполняется.');
    }
    lanSyncBusy = true;
    lanSyncPeerDeviceId = expectedPeerDeviceId;
    _notifyListeners();
    await _recordReliability(
      stage: ReliabilityStage.connection,
      level: ReliabilityLevel.info,
      message: 'Запущена ручная LAN-синхронизация по одноразовому коду.',
      peerDeviceId: expectedPeerDeviceId,
    );
    try {
      final report = await _requireLanService().syncFromOffer(
        rawOffer,
        expectedPeerDeviceId: expectedPeerDeviceId,
        onRemoteApplied: (_) => refreshAfterLanSync(),
        onProgress: onProgress,
        cancellationToken: cancellationToken,
      );
      await refreshAfterLanSync(report: report);
      await recordSyncSuccess(
        report,
        peerDeviceId: expectedPeerDeviceId,
        automatic: false,
      );
      return report;
    } on Object catch (error) {
      final cancelled = error is LanSyncCancelledException;
      await _recordReliability(
        stage: ReliabilityStage.connection,
        level: cancelled ? ReliabilityLevel.info : ReliabilityLevel.error,
        message:
            cancelled
                ? 'Ручная LAN-синхронизация отменена пользователем.'
                : 'Ручная LAN-синхронизация не выполнена.',
        peerDeviceId: expectedPeerDeviceId,
        details: <String, Object?>{'error': friendlyLanError(error)},
      );
      rethrow;
    } finally {
      lanSyncBusy = false;
      lanSyncPeerDeviceId = null;
      _notifyListeners();
    }
  }

  Future<void> refreshAfterLanSync({LanSyncReport? report}) async {
    if (report != null) {
      lastLanSyncReport = report;
    }
    _replaceData(await _repository.load());
    await _rebuildAllNoteLinks();
    await refreshFoundation(notify: false);
    if (report?.changedData ?? false) {
      _scheduleVaultMirror();
    }
    _onAttachmentRefresh();
    _notifyListeners();
  }

  Future<void> recordSyncSuccess(
    LanSyncReport report, {
    required String peerDeviceId,
    required bool automatic,
  }) {
    return _recordReliability(
      stage: ReliabilityStage.transfer,
      level: ReliabilityLevel.success,
      message:
          automatic
              ? 'Автоматическая LAN-синхронизация завершена.'
              : 'LAN-синхронизация завершена.',
      peerDeviceId: peerDeviceId,
      details: <String, Object?>{
        'rounds': report.roundCount,
        'sent': report.sentCount,
        'received': report.receivedCount,
        'applied': report.appliedCount,
        'duplicates': report.duplicateCount,
        'stale': report.staleCount,
        'unsupported': report.unsupportedCount,
        'attachmentFilesFromPeer': report.attachmentPlanFromPeer.fileCount,
        'attachmentFilesByPeer': report.attachmentPlanByPeer.fileCount,
        'attachmentTombstonesFromPeer':
            report.attachmentPlanFromPeer.tombstoneCount,
        'attachmentTombstonesByPeer':
            report.attachmentPlanByPeer.tombstoneCount,
        'attachmentFilesReceived': report.attachmentFilesReceived,
        'attachmentFilesSent': report.attachmentFilesSent,
        'attachmentBytesReceived': report.attachmentBytesReceived,
        'attachmentBytesSent': report.attachmentBytesSent,
        'attachmentRecordsApplied': report.attachmentRecordsApplied,
        'attachmentTombstonesApplied': report.attachmentTombstonesApplied,
        'attachmentConflicts': report.attachmentConflictCount,
        'durationMs':
            report.completedAt.difference(report.startedAt).inMilliseconds,
      },
    );
  }

  Future<void> renameLocalDevice(String displayName) async {
    final identity = deviceIdentity ?? await _repository.ensureDeviceIdentity();
    final trimmed = displayName.trim();
    if (trimmed.isEmpty || trimmed == identity.displayName) {
      return;
    }
    identity.displayName = trimmed;
    await _repository.saveDeviceIdentity(identity);
    deviceIdentity = identity;
    _notifyListeners();
  }

  Future<void> savePreferences(SyncPreferences preferences) async {
    syncPreferences = preferences;
    await _repository.saveSyncPreferences(preferences);
    _notifyListeners();
  }

  Future<void> revokeTrustedDevice(String deviceId) async {
    await _repository.revokeTrustedDevice(deviceId, DateTime.now());
    await refreshFoundation();
  }

  Future<void> _bootstrapJournal() async {
    final data = _currentData();
    for (final project in data.projects) {
      await _repository.recordLocalChange(
        entityType: 'project',
        entityId: project.id,
        operation: 'snapshot',
        payload: project.toJson(),
      );
    }
    for (final task in data.tasks) {
      await _repository.recordLocalChange(
        entityType: 'task',
        entityId: task.id,
        operation: 'snapshot',
        payload: task.toJson(),
      );
    }
    for (final note in data.notes) {
      await _repository.recordLocalChange(
        entityType: 'note',
        entityId: note.id,
        operation: 'snapshot',
        payload: note.toJson(),
      );
    }
    for (final entry in data.entries) {
      await _repository.recordLocalChange(
        entityType: 'time_entry',
        entityId: entry.id,
        operation: 'snapshot',
        payload: entry.toJson(),
      );
    }
  }

  LanSyncService _requireLanService() {
    return _lanSyncService ??
        (throw StateError('LAN sync service is not configured.'));
  }

  static String friendlyLanError(Object error) {
    final raw = error.toString().replaceFirst('Bad state: ', '');
    if (raw.contains('Address already in use')) {
      return 'Порт локального обнаружения уже занят. Полностью закрой вторую '
          'копию Chronicle и запусти приложение снова.';
    }
    if (raw.contains('Permission denied')) {
      return 'Система запретила доступ к локальной сети. Проверь разрешения '
          'Chronicle и правила брандмауэра.';
    }
    return raw;
  }
}
