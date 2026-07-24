part of 'app_store.dart';

extension AppStoreSyncVaultApi on AppStore {
  Future<void> refreshSyncFoundation({bool notify = true}) async {
    await _syncCoordinator.refreshFoundation(notify: false);
    if (_automaticLanSyncEnabled &&
        ready &&
        !_lanDiscoveryCoordinator.running &&
        syncPreferences.discoverOnLocalNetwork &&
        trustedDevices.isNotEmpty) {
      unawaited(_restartAutomaticLanSync());
    }
    if (notify) {
      _notifyStoreListeners();
    }
  }

  Future<SyncJournalBatch> buildOutgoingSyncBatch({
    required String peerDeviceId,
    required int afterSequence,
    int limit = 200,
  }) => _syncCoordinator.buildOutgoingBatch(
    peerDeviceId: peerDeviceId,
    afterSequence: afterSequence,
    limit: limit,
  );

  Future<JournalCompactionResult> compactSyncJournal({
    int maxEntries = defaultMaxJournalEntries,
    int maxPayloadBytes = defaultMaxJournalPayloadBytes,
  }) => _syncCoordinator.compactJournal(
    maxEntries: maxEntries,
    maxPayloadBytes: maxPayloadBytes,
  );

  Future<SyncApplyResult> applyIncomingSyncChanges(
    List<ChangeRecord> changes,
  ) => _syncCoordinator.applyIncomingChanges(changes);

  Future<LanSyncHostSession> startLanSyncHost(String peerDeviceId) =>
      _syncCoordinator.startLanHost(peerDeviceId);

  Future<LanSyncReport> syncFromLanOffer(
    String rawOffer, {
    required String expectedPeerDeviceId,
    LanSyncProgressCallback? onProgress,
    LanSyncCancellationToken? cancellationToken,
  }) => _syncCoordinator.syncFromLanOffer(
    rawOffer,
    expectedPeerDeviceId: expectedPeerDeviceId,
    onProgress: onProgress,
    cancellationToken: cancellationToken,
  );

  Future<void> refreshAfterLanSync({LanSyncReport? report}) =>
      _syncCoordinator.refreshAfterLanSync(report: report);

  bool isLanPeerOnline(String deviceId) =>
      _lanDiscoveryCoordinator.isPeerOnline(deviceId);

  String? lanPeerEndpoint(String deviceId) =>
      _lanDiscoveryCoordinator.peerEndpoint(deviceId);

  String? lanPeerError(String deviceId) =>
      _lanDiscoveryCoordinator.peerError(deviceId);

  Future<void> handleAppResumed() =>
      _lanDiscoveryCoordinator.handleAppResumed();

  Future<void> refreshLanDiscovery() =>
      _lanDiscoveryCoordinator.refreshDiscovery();

  Future<LanSyncReport> syncWithTrustedDevice(String peerDeviceId) =>
      _lanDiscoveryCoordinator.syncWithTrustedDevice(peerDeviceId);

  Future<void> _restartAutomaticLanSync() => _lanDiscoveryCoordinator.restart();

  Future<void> renameLocalDevice(String displayName) =>
      _syncCoordinator.renameLocalDevice(displayName);

  Future<void> updateSyncPreferences(SyncPreferences preferences) async {
    final discoveryChanged =
        syncPreferences.discoverOnLocalNetwork !=
            preferences.discoverOnLocalNetwork ||
        syncPreferences.localNetworkOnly != preferences.localNetworkOnly;
    await _syncCoordinator.savePreferences(preferences);
    if (discoveryChanged && _automaticLanSyncEnabled) {
      unawaited(_restartAutomaticLanSync());
    } else if (preferences.autoSyncEnabled) {
      unawaited(_lanDiscoveryCoordinator.announceIfEnabled());
    }
  }

  Future<void> revokeTrustedDevice(String deviceId) async {
    _lanDiscoveryCoordinator.removePeer(deviceId);
    await _syncCoordinator.revokeTrustedDevice(deviceId);
    if (_automaticLanSyncEnabled) {
      unawaited(_restartAutomaticLanSync());
    }
  }

  void _scheduleSyncOverviewRefresh() {
    _syncRefreshDebounce?.cancel();
    _syncRefreshDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(refreshSyncFoundation());
    });
  }

  Future<void> _initializeVaultFoundation({
    required bool allowAutomaticWrite,
  }) => _vaultCoordinator.initialize(allowAutomaticWrite: allowAutomaticWrite);

  Future<void> refreshVaultStatus({bool notify = true}) =>
      _vaultCoordinator.refreshStatus(notify: notify);

  Future<VaultScanResult> scanVaultChanges({bool notify = true}) =>
      _vaultCoordinator.scanChanges(notify: notify);

  void _mergeVaultScanIntoStatus({String? messageOverride}) =>
      _vaultCoordinator.mergePendingScan(messageOverride: messageOverride);

  Future<void> writeVaultMirror() => _vaultCoordinator.writeMirror();

  Future<bool> chooseVaultFolder() => _vaultCoordinator.chooseFolder();

  Future<Uint8List?> readManagedAttachment(String relativePath) =>
      _vaultCoordinator.readManagedAttachment(relativePath);

  Future<AttachmentImportResult?> pickAttachmentForNote(Note note) =>
      _vaultCoordinator.pickAttachmentForNote(note);

  Future<AttachmentImportResult> storeAttachmentBytesForNote(
    Note note, {
    required String fileName,
    required Uint8List bytes,
  }) => _vaultCoordinator.storeAttachmentBytesForNote(
    note,
    fileName: fileName,
    bytes: bytes,
  );

  Future<List<AttachmentImportResult>> storeAttachmentBatchForNote(
    Note note, {
    required List<String> fileNames,
    required List<Uint8List> fileBytes,
  }) => _vaultCoordinator.storeAttachmentBatchForNote(
    note,
    fileNames: fileNames,
    fileBytes: fileBytes,
  );

  Future<VaultApplyResult> applyVaultChanges(
    VaultScanResult scan, {
    required VaultConflictResolution conflictResolution,
    Map<String, VaultConflictResolution> conflictResolutions = const {},
    VaultMissingFileResolution missingFileResolution =
        VaultMissingFileResolution.restoreFiles,
  }) => _vaultCoordinator.applyChanges(
    scan,
    conflictResolution: conflictResolution,
    conflictResolutions: conflictResolutions,
    missingFileResolution: missingFileResolution,
  );

  void _scheduleVaultMirror() => _vaultCoordinator.scheduleMirror();
}
