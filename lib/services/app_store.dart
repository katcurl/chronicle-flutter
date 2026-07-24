import 'dart:async';

import 'package:flutter/foundation.dart';

import '../application/backup/restore_coordinator.dart';
import '../application/notes/note_commands.dart';
import '../application/notes/note_template_commands.dart';
import '../application/notes/wiki_link_commands.dart';
import '../application/sync/lan_discovery_coordinator.dart';
import '../application/sync/sync_coordinator.dart';
import '../application/tasks/task_commands.dart';
import '../application/timer/timer_service.dart';
import '../application/vault/vault_coordinator.dart';
import '../data/migration/legacy_preferences_importer.dart';
import '../data/backup/staged_restore.dart';
import '../data/repositories/app_repository.dart';
import '../data/repositories/drift_app_repository.dart';
import '../data/repositories/mutation_queue.dart';
import '../features/notes/custom_note_template_store.dart';
import '../features/notes/note_templates.dart';
import '../features/notes/note_wiki_rename.dart';
import '../models/app_models.dart';
import '../reliability/release_readiness.dart';
import '../reliability/reliability_models.dart';
import '../reliability/reliability_service.dart';
import '../reliability/undo_journal.dart';
import '../security/device_key_store.dart';
import '../security/device_key_store_secure.dart';
import '../sync/lan_auto_sync_service.dart';
import '../sync/lan_sync_models.dart';
import '../sync/lan_sync_resilience.dart';
import '../sync/lan_sync_service.dart';
import '../sync/lan_sync_transport.dart';
import '../sync/pairing_service.dart';
import '../sync/sync_models.dart';
import '../vault/vault_models.dart';
import '../vault/vault_service.dart';

class AppStore extends ChangeNotifier {
  AppStore({
    required AppRepository repository,
    LegacyPreferencesImporter? legacyImporter,
    VaultService? vaultService,
    PairingService? pairingService,
    LanSyncService? lanSyncService,
    DeviceKeyStore? deviceKeyStore,
    bool migrateDeviceKeyOnStartup = false,
    ReliabilityService? reliabilityService,
    CustomNoteTemplateStore? customNoteTemplateStore,
    bool enableAutomaticLanSync = false,
    bool enableReliabilityFeatures = false,
    RestoreCutPointCallback? restoreCutPoint,
  }) : _repository = repository,
       _legacyImporter = legacyImporter,
       _vaultService = vaultService ?? VaultService(),
       _reliabilityService = reliabilityService ?? ReliabilityService(),
       _migrateDeviceKeyOnStartup = migrateDeviceKeyOnStartup,
       _automaticLanSyncEnabled = enableAutomaticLanSync,
       _reliabilityFeaturesEnabled = enableReliabilityFeatures {
    final effectiveDeviceKeyStore = deviceKeyStore ?? SecureDeviceKeyStore();
    this.pairingService =
        pairingService ??
        PairingService(
          repository: repository,
          deviceKeyStore: effectiveDeviceKeyStore,
        );
    this.lanSyncService =
        lanSyncService ??
        LanSyncService(
          repository: repository,
          deviceKeyStore: effectiveDeviceKeyStore,
          buildAttachmentManifest: _vaultService.buildAttachmentSyncManifest,
          readAttachment: _vaultService.readAttachmentForSync,
          storeAttachment: _vaultService.storeAttachmentFromSync,
          applyAttachmentRecord: _vaultService.applyAttachmentRecordFromSync,
          applyAttachmentTombstone:
              _vaultService.applyAttachmentTombstoneFromSync,
        );
    autoSyncService = LanAutoSyncService(
      repository: repository,
      lanSyncService: this.lanSyncService,
    );
    _timerService = TimerService(
      repository: repository,
      mutationQueue: _mutationQueue,
      entries: () => data.entries,
      onStateChanged: notifyListeners,
      onEntrySaved: _scheduleSyncOverviewRefresh,
    );
    _noteCommands = NoteCommands(
      repository: repository,
      mutationQueue: _mutationQueue,
      currentData: () => data,
      resolveWikiTarget: resolveWikiTarget,
      registerUndo: _registerUndo,
      recordLinkIndexWarning:
          (error) => _recordReliability(
            stage: ReliabilityStage.system,
            level: ReliabilityLevel.warning,
            message: 'Индекс связей заметок требует перестроения.',
            details: <String, Object?>{'error': error.toString()},
            notify: false,
          ),
      scheduleSync: _scheduleSyncOverviewRefresh,
      scheduleVaultMirror: _scheduleVaultMirror,
      notifyListeners: notifyListeners,
    );
    _wikiLinkCommands = WikiLinkCommands(
      repository: repository,
      currentData: () => data,
      syncNoteLinks: _noteCommands.syncLinks,
      scheduleSync: _scheduleSyncOverviewRefresh,
      scheduleVaultMirror: _scheduleVaultMirror,
      notifyListeners: notifyListeners,
    );
    _taskCommands = TaskCommands(
      repository: repository,
      mutationQueue: _mutationQueue,
      currentData: () => data,
      registerUndo: _registerUndo,
      scheduleSync: _scheduleSyncOverviewRefresh,
      notifyListeners: notifyListeners,
    );
    _noteTemplateCommands = NoteTemplateCommands(
      store: customNoteTemplateStore,
      notifyListeners: notifyListeners,
    );
    _restoreCoordinator = RestoreCoordinator(
      repository: repository,
      vaultService: _vaultService,
      currentData: () => data,
      currentIdentity: () => deviceIdentity,
      isBusy: () => vaultBusy,
      setBusy: (value) => vaultBusy = value,
      reloadAfterRestore: _reloadAfterRestore,
      refreshBackupCatalog: () => refreshBackupCatalog(notify: false),
      recordReliability:
          ({
            required stage,
            required level,
            required message,
            details = const <String, Object?>{},
          }) => _recordReliability(
            stage: stage,
            level: level,
            message: message,
            details: details,
            notify: false,
          ),
      notifyListeners: notifyListeners,
      restoreCutPoint: restoreCutPoint,
    );
    _vaultCoordinator = VaultCoordinator(
      repository: repository,
      vaultService: _vaultService,
      currentData: () => data,
      currentIdentity: () => deviceIdentity,
      isBusy: () => vaultBusy,
      setBusy: (value) => vaultBusy = value,
      rebuildAllNoteLinks: () => rebuildAllNoteLinks(),
      refreshSyncFoundation: () => refreshSyncFoundation(notify: false),
      onEmergencyBackupCreated: (path) => lastEmergencyBackupPath = path,
      onAttachmentRefresh: _notifyAttachmentRefresh,
      notifyListeners: notifyListeners,
    );
    _syncCoordinator = SyncCoordinator(
      repository: repository,
      lanSyncService: this.lanSyncService,
      currentData: () => data,
      replaceData: (replacement) => data = replacement,
      rebuildAllNoteLinks: () => rebuildAllNoteLinks(notify: false),
      scheduleVaultMirror: _scheduleVaultMirror,
      onAttachmentRefresh: _notifyAttachmentRefresh,
      recordReliability:
          ({
            required stage,
            required level,
            required message,
            peerDeviceId,
            details = const <String, Object?>{},
          }) => _recordReliability(
            stage: stage,
            level: level,
            message: message,
            peerDeviceId: peerDeviceId,
            details: details,
            notify: false,
          ),
      notifyListeners: notifyListeners,
    );
    _lanDiscoveryCoordinator = LanDiscoveryCoordinator(
      autoSyncService: autoSyncService,
      syncCoordinator: _syncCoordinator,
      enabled: _automaticLanSyncEnabled,
      appReady: () => ready,
      loadError: () => loadError,
      recordReliability:
          ({
            required stage,
            required level,
            required message,
            peerDeviceId,
            details = const <String, Object?>{},
          }) => _recordReliability(
            stage: stage,
            level: level,
            message: message,
            peerDeviceId: peerDeviceId,
            details: details,
            notify: false,
          ),
      notifyListeners: notifyListeners,
    );
  }

  factory AppStore.production() => AppStore(
    repository: DriftAppRepository(),
    legacyImporter: LegacyPreferencesImporter(),
    customNoteTemplateStore: CustomNoteTemplateStore(),
    migrateDeviceKeyOnStartup: true,
    enableAutomaticLanSync: true,
    enableReliabilityFeatures: true,
  );

  final AppRepository _repository;
  final LegacyPreferencesImporter? _legacyImporter;
  final VaultService _vaultService;
  final ReliabilityService _reliabilityService;
  final bool _migrateDeviceKeyOnStartup;
  late final PairingService pairingService;
  late final LanSyncService lanSyncService;
  final bool _automaticLanSyncEnabled;
  final bool _reliabilityFeaturesEnabled;
  late final LanAutoSyncService autoSyncService;
  final ChronicleUndoJournal _undoJournal = ChronicleUndoJournal();
  final MutationQueue _mutationQueue = MutationQueue();
  late final TimerService _timerService;
  late final NoteCommands _noteCommands;
  late final WikiLinkCommands _wikiLinkCommands;
  late final TaskCommands _taskCommands;
  late final NoteTemplateCommands _noteTemplateCommands;
  late final RestoreCoordinator _restoreCoordinator;
  late final VaultCoordinator _vaultCoordinator;
  late final SyncCoordinator _syncCoordinator;
  late final LanDiscoveryCoordinator _lanDiscoveryCoordinator;
  final ValueNotifier<int> _attachmentRefreshNotifier = ValueNotifier<int>(0);

  ValueListenable<int> get attachmentRefreshListenable =>
      _attachmentRefreshNotifier;

  AppData data = AppData.empty();
  List<NoteTemplate> get customNoteTemplates =>
      _noteTemplateCommands.customTemplates;
  bool ready = false;
  Object? loadError;

  DeviceIdentity? get deviceIdentity => _syncCoordinator.deviceIdentity;
  set deviceIdentity(DeviceIdentity? value) =>
      _syncCoordinator.deviceIdentity = value;
  List<TrustedDevice> get trustedDevices => _syncCoordinator.trustedDevices;
  List<ChangeRecord> get recentChanges => _syncCoordinator.recentChanges;
  List<SyncCursor> get syncCursors => _syncCoordinator.syncCursors;
  SyncPreferences get syncPreferences => _syncCoordinator.syncPreferences;
  set syncPreferences(SyncPreferences value) =>
      _syncCoordinator.syncPreferences = value;
  int get journalEntryCount => _syncCoordinator.journalEntryCount;
  int get journalPayloadBytes => _syncCoordinator.journalPayloadBytes;
  JournalCompactionResult? get lastJournalCompaction =>
      _syncCoordinator.lastJournalCompaction;
  bool get lanSyncBusy => _syncCoordinator.lanSyncBusy;
  set lanSyncBusy(bool value) => _syncCoordinator.lanSyncBusy = value;
  String? get lanSyncPeerDeviceId => _syncCoordinator.lanSyncPeerDeviceId;
  set lanSyncPeerDeviceId(String? value) =>
      _syncCoordinator.lanSyncPeerDeviceId = value;
  LanSyncReport? get lastLanSyncReport => _syncCoordinator.lastLanSyncReport;
  set lastLanSyncReport(LanSyncReport? value) =>
      _syncCoordinator.lastLanSyncReport = value;
  bool get lanDiscoveryActive => _lanDiscoveryCoordinator.discoveryActive;
  String get lanDiscoveryStatus => _lanDiscoveryCoordinator.discoveryStatus;
  String? get lanAutoSyncError => _lanDiscoveryCoordinator.autoSyncError;
  set lanAutoSyncError(String? value) =>
      _lanDiscoveryCoordinator.autoSyncError = value;

  VaultStatus get vaultStatus => _vaultCoordinator.status;
  set vaultStatus(VaultStatus value) => _vaultCoordinator.status = value;
  VaultScanResult? get pendingVaultScan => _vaultCoordinator.pendingScan;
  set pendingVaultScan(VaultScanResult? value) =>
      _vaultCoordinator.pendingScan = value;
  bool vaultBusy = false;
  String? get lastEmergencyBackupPath =>
      _restoreCoordinator.lastEmergencyBackupPath;
  set lastEmergencyBackupPath(String? value) =>
      _restoreCoordinator.lastEmergencyBackupPath = value;
  bool get lastRestoreRolledBack => _restoreCoordinator.lastRestoreRolledBack;
  List<BackupCatalogEntry> automaticBackups = const <BackupCatalogEntry>[];
  bool backupCatalogBusy = false;
  String? backupCatalogError;

  List<ReliabilityEvent> reliabilityEvents = const <ReliabilityEvent>[];
  DateTime? lastAutomaticBackupAt;
  String? lastAutomaticBackupPath;
  bool reliabilityBusy = false;
  String? reliabilityError;

  ReleaseReadinessReport? releaseReadinessReport;
  bool releaseReadinessBusy = false;
  String? releaseReadinessError;

  bool get canUndo => _undoJournal.canUndo;
  int get undoDepth => _undoJournal.length;
  String? get nextUndoLabel => _undoJournal.nextLabel;

  Timer? _syncRefreshDebounce;
  Future<void>? _shutdownFuture;
  DateTime? get activeStartedAt => _timerService.activeStartedAt;
  String get activeDescription => _timerService.activeDescription;
  String? get activeProjectId => _timerService.activeProjectId;
  String? get activeTaskId => _timerService.activeTaskId;
  String? get activeNoteId => _timerService.activeNoteId;

  Future<void> load() async {
    ready = false;
    loadError = null;
    _undoJournal.clear();
    releaseReadinessReport = null;
    releaseReadinessError = null;
    notifyListeners();

    try {
      await _initializeReliability();
      await _recordReliability(
        stage: ReliabilityStage.startup,
        level: ReliabilityLevel.info,
        message: 'Запуск Chronicle и открытие локальной базы.',
        notify: false,
      );
      final initialized = await _repository.isInitialized();
      StagedRestoreMarker? recoveredRestore;
      var protectExistingVault = false;
      if (!initialized) {
        final legacy = await _legacyImporter?.read();
        final vaultHasNotes = await _vaultService.hasExistingNoteContent();
        protectExistingVault = vaultHasNotes;
        data = legacy ?? AppData.empty();
        await _repository.replaceAll(data);
        await _repository.markInitialized();
        await _repository.ensureDataGeneration();
      } else {
        final currentGeneration = await _repository.ensureDataGeneration();
        recoveredRestore = await _vaultService.recoverStagedRestore(
          currentGeneration,
        );
        data = await _repository.load();
      }

      if (_migrateDeviceKeyOnStartup) {
        try {
          await pairingService.ensureLocalIdentity();
        } on Object catch (error) {
          lanAutoSyncError =
              'Ключ синхронизации не удалось перенести в защищённое хранилище.';
          await _recordReliability(
            stage: ReliabilityStage.startup,
            level: ReliabilityLevel.warning,
            message: 'Миграция ключа синхронизации не выполнена.',
            details: <String, Object?>{'error': error.toString()},
            notify: false,
          );
        }
      }

      await _loadCustomNoteTemplates();
      await _hydrateNoteMetadata();
      await rebuildAllNoteLinks();
      await refreshSyncFoundation(notify: false);
      await _initializeVaultFoundation(
        allowAutomaticWrite: !protectExistingVault,
      );
      await refreshBackupCatalog(notify: false);
      if (recoveredRestore != null) {
        final attachmentIntegrity =
            await _vaultService.inspectAttachmentIntegrity();
        if (!attachmentIntegrity.isHealthy) {
          throw StateError(
            'Восстановленная generation содержит расхождения вложений.',
          );
        }
        await _vaultService.finalizeStagedRestore(recoveredRestore);
      }

      final activeTimer = await _repository.loadActiveTimer();
      if (activeTimer != null &&
          data.projects.any((project) => project.id == activeTimer.projectId)) {
        _timerService.hydrate(activeTimer);
      } else if (activeTimer != null) {
        await _repository.saveActiveTimer(null);
        _timerService.hydrate(null);
      } else {
        _timerService.hydrate(null);
      }
      await _recordReliability(
        stage: ReliabilityStage.startup,
        level: ReliabilityLevel.success,
        message: 'Локальная база Chronicle успешно открыта.',
        details: <String, Object?>{
          'projects': data.projects.length,
          'tasks': data.tasks.length,
          'notes': data.notes.length,
          'citationSources': data.citationSources.length,
          'timeEntries': data.entries.length,
        },
        notify: false,
      );
    } catch (error) {
      loadError = error;
      await _recordReliability(
        stage: ReliabilityStage.startup,
        level: ReliabilityLevel.error,
        message: 'Не удалось открыть локальную базу Chronicle.',
        details: <String, Object?>{'error': error.toString()},
        notify: false,
      );
    } finally {
      ready = true;
      notifyListeners();
      if (loadError == null) {
        if (_automaticLanSyncEnabled) {
          unawaited(_restartAutomaticLanSync());
        }
        if (_reliabilityFeaturesEnabled) {
          unawaited(_createAutomaticBackupIfDue());
        }
      }
    }
  }

  NoteTemplate get blankNoteTemplate => _noteTemplateCommands.blankTemplate;

  List<NoteTemplate> get availableNoteTemplates =>
      _noteTemplateCommands.availableTemplates;

  List<NoteTemplate> get applicableNoteTemplates =>
      _noteTemplateCommands.applicableTemplates;

  Future<void> _loadCustomNoteTemplates() => _noteTemplateCommands.load();

  Future<NoteTemplate> createCustomNoteTemplate({
    required String title,
    required String icon,
    required String noteType,
    required String content,
    String category = '',
    List<String> defaultTags = const <String>[],
    Map<String, String> defaultProperties = const <String, String>{},
  }) => _noteTemplateCommands.create(
    title: title,
    icon: icon,
    noteType: noteType,
    content: content,
    category: category,
    defaultTags: defaultTags,
    defaultProperties: defaultProperties,
  );

  Future<NoteTemplate> updateCustomNoteTemplate({
    required String id,
    required String title,
    required String icon,
    required String noteType,
    required String content,
    String category = '',
    List<String> defaultTags = const <String>[],
    Map<String, String> defaultProperties = const <String, String>{},
  }) => _noteTemplateCommands.update(
    id: id,
    title: title,
    icon: icon,
    noteType: noteType,
    content: content,
    category: category,
    defaultTags: defaultTags,
    defaultProperties: defaultProperties,
  );

  Future<NoteTemplate> duplicateCustomNoteTemplate(String id) =>
      _noteTemplateCommands.duplicate(id);

  Future<List<NoteTemplate>> importCustomNoteTemplates(
    List<NoteTemplate> imported,
  ) => _noteTemplateCommands.importTemplates(imported);

  Future<void> deleteCustomNoteTemplate(String id) =>
      _noteTemplateCommands.delete(id);

  List<Project> get activeProjects => _taskCommands.activeProjects;

  List<Project> get archivedProjects => _taskCommands.archivedProjects;

  Project? projectById(String id) => _wikiLinkCommands.projectById(id);

  Note? noteById(String id) => _wikiLinkCommands.noteById(id);

  Note? noteByTitle(String title) => _wikiLinkCommands.noteByTitle(title);

  List<Note> notesByTitle(String title) =>
      _wikiLinkCommands.notesByTitle(title);

  List<Note> notesForWikiTarget(String rawTarget, {Note? source}) =>
      _wikiLinkCommands.notesForTarget(rawTarget, source: source);

  Note? resolveWikiTarget(String rawTarget, {Note? source}) =>
      _wikiLinkCommands.resolveTarget(rawTarget, source: source);

  String wikiTargetFor(Note note) => _wikiLinkCommands.targetFor(note);

  List<NoteLink> outgoingLinksFor(String noteId) =>
      _wikiLinkCommands.outgoingLinksFor(noteId);

  List<NoteLink> backlinksFor(Note note) =>
      _wikiLinkCommands.backlinksFor(note);

  NoteWikiRenamePlan buildWikiRenamePlan(Note note, String newTitle) =>
      _wikiLinkCommands.buildRenamePlan(note, newTitle);

  List<NoteWikiLinkIssue> wikiLinkIssues() => _wikiLinkCommands.linkIssues();

  Future<NoteWikiRenameUndo> applyWikiRenamePlan(NoteWikiRenamePlan plan) =>
      _wikiLinkCommands.applyRenamePlan(plan);

  Future<void> undoWikiRename(NoteWikiRenameUndo undo) =>
      _wikiLinkCommands.undoRename(undo);

  Future<void> repairWikiLink({
    required Note source,
    required String rawTarget,
    required Note target,
  }) => _wikiLinkCommands.repairLink(
    source: source,
    rawTarget: rawTarget,
    target: target,
  );

  List<NoteVersion> versionsFor(String noteId) =>
      _noteCommands.versionsFor(noteId);

  int get activeSeconds => _timerService.activeSeconds;

  int get todaySeconds => _timerService.todaySeconds;

  Future<void> startTimer({
    required String description,
    required String projectId,
    String? taskId,
    String? noteId,
  }) => _timerService.start(
    description: description,
    projectId: projectId,
    taskId: taskId,
    noteId: noteId,
  );

  Future<void> stopTimer() => _timerService.stop();

  Future<void> addTask(WorkTask task) => _taskCommands.addTask(task);

  Future<void> updateTask(WorkTask task) => _taskCommands.updateTask(task);

  Future<void> updateTaskStatus(WorkTask task, String status) =>
      _taskCommands.updateTaskStatus(task, status);

  Future<void> deleteTask(String id) => _taskCommands.deleteTask(id);

  Future<void> addProject(Project project) => _taskCommands.addProject(project);

  Future<void> updateProject(Project project) =>
      _taskCommands.updateProject(project);

  Future<void> setProjectArchived(Project project, bool archived) =>
      _taskCommands.setProjectArchived(project, archived);

  int citationUsageCount(String citationKey) =>
      _taskCommands.citationUsageCount(citationKey);

  Future<void> addCitationSource(CitationSource source) =>
      _taskCommands.addCitationSource(source);

  Future<void> updateCitationSource(CitationSource source) =>
      _taskCommands.updateCitationSource(source);

  Future<void> deleteCitationSource(String id) =>
      _taskCommands.deleteCitationSource(id);

  Future<int> importCitationSources(Iterable<CitationSource> sources) =>
      _taskCommands.importCitationSources(sources);

  Future<void> addNote(Note note) {
    return _noteCommands.add(note);
  }

  Future<void> updateNote(Note note) {
    return _noteCommands.update(note);
  }

  Future<void> flushPendingWrites() => _mutationQueue.drain();

  Future<void> shutdown() {
    return _shutdownFuture ??= _shutdown();
  }

  Future<void> _shutdown() async {
    _timerService.dispose();
    _syncRefreshDebounce?.cancel();
    _vaultCoordinator.dispose();
    await _mutationQueue.drain();
    await _lanDiscoveryCoordinator.dispose();
    await _repository.close();
  }

  Future<void> addNoteVersion(NoteVersion version) {
    return _noteCommands.addVersion(version);
  }

  void restoreNoteVersion(Note note, NoteVersion version) {
    _noteCommands.restoreVersion(note, version);
  }

  Future<void> deleteNote(String id) async {
    await _noteCommands.delete(id);
  }

  Future<void> rebuildAllNoteLinks({bool notify = true}) async {
    await _noteCommands.rebuildAllLinks(notify: notify);
  }

  Future<void> _hydrateNoteMetadata() async {
    await _noteCommands.hydrateMetadata();
  }

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
      notifyListeners();
    }
  }

  Future<SyncJournalBatch> buildOutgoingSyncBatch({
    required String peerDeviceId,
    required int afterSequence,
    int limit = 200,
  }) {
    return _syncCoordinator.buildOutgoingBatch(
      peerDeviceId: peerDeviceId,
      afterSequence: afterSequence,
      limit: limit,
    );
  }

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

  Future<LanSyncHostSession> startLanSyncHost(String peerDeviceId) {
    return _syncCoordinator.startLanHost(peerDeviceId);
  }

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

  Future<Uint8List?> readManagedAttachment(String relativePath) {
    return _vaultCoordinator.readManagedAttachment(relativePath);
  }

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

  Future<void> _initializeReliability() async {
    if (!_reliabilityFeaturesEnabled) {
      return;
    }
    try {
      await _reliabilityService.load();
      _refreshReliabilityState();
    } on Object catch (error) {
      reliabilityError = error.toString();
    }
  }

  Future<void> refreshReliabilityStatus({bool notify = true}) async {
    if (!_reliabilityFeaturesEnabled) {
      return;
    }
    try {
      await _reliabilityService.load();
      reliabilityError = null;
      _refreshReliabilityState();
    } on Object catch (error) {
      reliabilityError = error.toString();
    }
    if (notify) {
      notifyListeners();
    }
  }

  void _refreshReliabilityState() {
    reliabilityEvents = _reliabilityService.events;
    lastAutomaticBackupAt = _reliabilityService.lastAutomaticBackupAt;
    lastAutomaticBackupPath = _reliabilityService.lastAutomaticBackupPath;
  }

  Future<void> _recordReliability({
    required ReliabilityStage stage,
    required ReliabilityLevel level,
    required String message,
    String? peerDeviceId,
    Map<String, Object?> details = const <String, Object?>{},
    bool notify = true,
  }) async {
    if (!_reliabilityFeaturesEnabled) {
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
      reliabilityError = null;
      _refreshReliabilityState();
    } on Object catch (error) {
      reliabilityError = error.toString();
    }
    if (notify) {
      notifyListeners();
    }
  }

  Future<BackupExportResult?> createInternalSafetyBackup() async {
    if (reliabilityBusy || vaultBusy) {
      return null;
    }
    reliabilityBusy = true;
    reliabilityError = null;
    notifyListeners();
    try {
      final result = await _vaultService.createAutomaticBackup(
        data: data,
        identity: deviceIdentity,
        maxFiles: 5,
      );
      await _reliabilityService.markAutomaticBackup(
        createdAt: result.preview.exportedAt,
        path: result.path,
      );
      _refreshReliabilityState();
      await _recordReliability(
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
    } on Object catch (error) {
      await _recordReliability(
        stage: ReliabilityStage.backup,
        level: ReliabilityLevel.error,
        message: 'Не удалось создать локальную страховочную копию.',
        details: <String, Object?>{'error': error.toString()},
        notify: false,
      );
      reliabilityError = error.toString();
      rethrow;
    } finally {
      reliabilityBusy = false;
      notifyListeners();
    }
  }

  Future<void> _createAutomaticBackupIfDue() async {
    if (!_reliabilityFeaturesEnabled ||
        !_reliabilityService.automaticBackupDue()) {
      return;
    }
    try {
      await createInternalSafetyBackup();
    } on Object {
      // Ошибка уже записана в диагностический журнал. Запуск приложения
      // не должен блокироваться из-за недоступной папки резервных копий.
    }
  }

  Future<String?> exportDiagnosticReport() async {
    if (!_reliabilityFeaturesEnabled || reliabilityBusy) {
      return null;
    }
    reliabilityBusy = true;
    reliabilityError = null;
    notifyListeners();
    try {
      return await _reliabilityService.exportDiagnosticReport(
        snapshot: <String, Object?>{
          'appVersion': chronicleStableVersion,
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
          'deviceId': deviceIdentity?.deviceId,
          'deviceName': deviceIdentity?.displayName,
          'trustedDeviceCount': trustedDevices.length,
          'journalEntryCount': journalEntryCount,
          'journalPayloadBytes': journalPayloadBytes,
          'journalCompactionGeneration': lastJournalCompaction?.generation ?? 0,
          'journalLastCompactedSequence':
              lastJournalCompaction?.lastCompactedSequence ?? 0,
          'journalMinimumPeerCursor': lastJournalCompaction?.minimumPeerCursor,
          'syncCursorCount': syncCursors.length,
          'discoveryActive': lanDiscoveryActive,
          'discoveryStatus': lanDiscoveryStatus,
          'autoSyncEnabled': syncPreferences.autoSyncEnabled,
          'discoverOnLocalNetwork': syncPreferences.discoverOnLocalNetwork,
          'lastAutomaticBackupAt': lastAutomaticBackupAt,
          'projectCount': data.projects.length,
          'taskCount': data.tasks.length,
          'noteCount': data.notes.length,
          'timeEntryCount': data.entries.length,
        },
      );
    } on Object catch (error) {
      reliabilityError = error.toString();
      rethrow;
    } finally {
      reliabilityBusy = false;
      notifyListeners();
    }
  }

  Future<void> clearDiagnosticLog() async {
    if (!_reliabilityFeaturesEnabled || reliabilityBusy) {
      return;
    }
    reliabilityBusy = true;
    notifyListeners();
    try {
      await _reliabilityService.clearEvents();
      _refreshReliabilityState();
      reliabilityError = null;
    } finally {
      reliabilityBusy = false;
      notifyListeners();
    }
  }

  Future<void> refreshBackupCatalog({bool notify = true}) async {
    if (backupCatalogBusy) {
      return;
    }
    backupCatalogBusy = true;
    backupCatalogError = null;
    if (notify) {
      notifyListeners();
    }
    try {
      automaticBackups = await _vaultService.listAutomaticBackups();
    } on Object catch (error) {
      automaticBackups = const <BackupCatalogEntry>[];
      backupCatalogError = error.toString();
    } finally {
      backupCatalogBusy = false;
      if (notify) {
        notifyListeners();
      }
    }
  }

  Future<BackupImportPayload> loadAutomaticBackup(BackupCatalogEntry entry) {
    return _vaultService.loadAutomaticBackup(entry);
  }

  Future<BackupExportResult?> exportBackupFile() async {
    if (vaultBusy) {
      return null;
    }
    vaultBusy = true;
    notifyListeners();
    try {
      vaultStatus = await _vaultService.writeMirror(data);
      final result = await _vaultService.exportBackup(
        data: data,
        identity: deviceIdentity,
      );
      if (result != null) {
        await _recordReliability(
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
    } on Object catch (error) {
      await _recordReliability(
        stage: ReliabilityStage.backup,
        level: ReliabilityLevel.error,
        message: 'Экспорт переносимой копии не выполнен.',
        details: <String, Object?>{'error': error.toString()},
        notify: false,
      );
      rethrow;
    } finally {
      vaultBusy = false;
      notifyListeners();
    }
  }

  Future<BackupImportPayload?> pickBackupFile() {
    return _vaultService.pickBackup();
  }

  Future<void> restoreBackupFile(BackupImportPayload payload) =>
      _restoreCoordinator.restore(payload);

  Future<void> _reloadAfterRestore() async {
    _undoJournal.clear();
    releaseReadinessReport = null;
    _timerService.hydrate(null);
    data = await _repository.load();
    await _hydrateNoteMetadata();
    await rebuildAllNoteLinks();
    vaultStatus = await _vaultService.writeMirror(data, force: true);
    pendingVaultScan = await _vaultService.scan(data);
    _mergeVaultScanIntoStatus();
    await refreshSyncFoundation(notify: false);
    _notifyAttachmentRefresh();
  }

  Future<String> exportBackupJson() => _repository.exportJson();

  Future<String?> undoLastAction() async {
    final label = await _undoJournal.undoLast();
    if (label == null) {
      return null;
    }
    try {
      await refreshSyncFoundation(notify: false);
    } on Object catch (error) {
      await _recordReliability(
        stage: ReliabilityStage.system,
        level: ReliabilityLevel.warning,
        message: 'Действие отменено, но обзор синхронизации не обновился.',
        details: <String, Object?>{'error': error.toString()},
        notify: false,
      );
    }
    notifyListeners();
    return label;
  }

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
    notifyListeners();
    try {
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
      pendingVaultScan = readinessScan;
      automaticBackups = await _vaultService.listAutomaticBackups();
      vaultStatus = inspectedVault.copyWith(
        pendingChangeCount: readinessScan?.pendingCount ?? 0,
        conflictCount: readinessScan?.conflicts.length ?? 0,
        missingFileCount: readinessScan?.missingFiles.length ?? 0,
      );
      final report = ReleaseReadinessReport(
        checkedAt: DateTime.now(),
        integrity: integrity,
        backupRoundTrip: roundTrip,
        vaultStatus: vaultStatus,
        undoDepth: undoDepth,
        automaticBackupCount:
            automaticBackups.where((entry) => entry.isValid).length,
        pendingConflictCount:
            readinessScan?.conflicts.length ?? vaultStatus.conflictCount,
        attachmentIntegrity: attachmentIntegrity,
      );
      releaseReadinessReport = report;
      var reliabilityLevel = ReliabilityLevel.warning;
      if (report.ready) {
        reliabilityLevel = ReliabilityLevel.success;
      } else if (integrity.errorCount > 0 || !roundTrip.valid) {
        reliabilityLevel = ReliabilityLevel.error;
      }
      await _recordReliability(
        stage: ReliabilityStage.system,
        level: reliabilityLevel,
        message:
            report.ready
                ? 'Проверка готовности Chronicle 1.0 завершена успешно.'
                : 'Проверка готовности Chronicle 1.0 требует внимания.',
        details: <String, Object?>{
          'integrityErrors': integrity.errorCount,
          'integrityWarnings': integrity.warningCount,
          'backupRoundTrip': roundTrip.valid,
          'vaultFormatVersion': vaultStatus.formatVersion,
          'vaultReadOnly': vaultStatus.readOnly,
          'pendingVaultChanges': vaultStatus.pendingChangeCount,
          'pendingConflicts': report.pendingConflictCount,
          'attachmentIntegrityIssues': attachmentIntegrity?.issues.length ?? 0,
          'validAutomaticBackups': report.automaticBackupCount,
        },
        notify: false,
      );
      return report;
    } on Object catch (error) {
      releaseReadinessError = error.toString();
      rethrow;
    } finally {
      releaseReadinessBusy = false;
      notifyListeners();
    }
  }

  void _registerUndo({
    required String label,
    required Future<void> Function() restore,
  }) {
    _undoJournal.push(ChronicleUndoEntry(label: label, restore: restore));
  }

  void _notifyAttachmentRefresh() {
    _attachmentRefreshNotifier.value += 1;
  }

  @override
  void dispose() {
    unawaited(shutdown());
    _timerService.dispose();
    _vaultCoordinator.dispose();
    _attachmentRefreshNotifier.dispose();
    super.dispose();
  }
}
