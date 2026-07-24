import 'dart:async';

import 'package:flutter/foundation.dart';

import '../application/backup/restore_coordinator.dart';
import '../application/notes/note_commands.dart';
import '../application/notes/note_template_commands.dart';
import '../application/notes/wiki_link_commands.dart';
import '../application/reliability/reliability_coordinator.dart';
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

part 'app_store_sync_vault_api.dart';

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
       _migrateDeviceKeyOnStartup = migrateDeviceKeyOnStartup,
       _automaticLanSyncEnabled = enableAutomaticLanSync,
       _reliabilityFeaturesEnabled = enableReliabilityFeatures {
    final effectiveDeviceKeyStore = deviceKeyStore ?? SecureDeviceKeyStore();
    final effectiveReliabilityService =
        reliabilityService ?? ReliabilityService();
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
    _reliabilityCoordinator = ReliabilityCoordinator(
      repository: repository,
      vaultService: _vaultService,
      reliabilityService: effectiveReliabilityService,
      enabled: _reliabilityFeaturesEnabled,
      currentData: () => data,
      currentIdentity: () => deviceIdentity,
      diagnosticSnapshot: _buildDiagnosticSnapshot,
      isVaultBusy: () => vaultBusy,
      setVaultBusy: (value) => vaultBusy = value,
      setVaultStatus: (value) => vaultStatus = value,
      setPendingVaultScan: (value) => pendingVaultScan = value,
      undoDepth: () => undoDepth,
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
  late final ReliabilityCoordinator _reliabilityCoordinator;
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
  List<BackupCatalogEntry> get automaticBackups =>
      _reliabilityCoordinator.automaticBackups;
  bool get backupCatalogBusy => _reliabilityCoordinator.backupCatalogBusy;
  String? get backupCatalogError => _reliabilityCoordinator.backupCatalogError;

  List<ReliabilityEvent> get reliabilityEvents =>
      _reliabilityCoordinator.events;
  DateTime? get lastAutomaticBackupAt =>
      _reliabilityCoordinator.lastAutomaticBackupAt;
  String? get lastAutomaticBackupPath =>
      _reliabilityCoordinator.lastAutomaticBackupPath;
  bool get reliabilityBusy => _reliabilityCoordinator.busy;
  String? get reliabilityError => _reliabilityCoordinator.error;

  ReleaseReadinessReport? get releaseReadinessReport =>
      _reliabilityCoordinator.releaseReadinessReport;
  bool get releaseReadinessBusy => _reliabilityCoordinator.releaseReadinessBusy;
  String? get releaseReadinessError =>
      _reliabilityCoordinator.releaseReadinessError;

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
    _reliabilityCoordinator.resetReleaseReadiness();
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

  Future<void> _initializeReliability() => _reliabilityCoordinator.initialize();

  Future<void> refreshReliabilityStatus({bool notify = true}) =>
      _reliabilityCoordinator.refresh(notify: notify);

  Future<void> _recordReliability({
    required ReliabilityStage stage,
    required ReliabilityLevel level,
    required String message,
    String? peerDeviceId,
    Map<String, Object?> details = const <String, Object?>{},
    bool notify = true,
  }) => _reliabilityCoordinator.record(
    stage: stage,
    level: level,
    message: message,
    peerDeviceId: peerDeviceId,
    details: details,
    notify: notify,
  );

  Future<BackupExportResult?> createInternalSafetyBackup() =>
      _reliabilityCoordinator.createSafetyBackup();

  Future<void> _createAutomaticBackupIfDue() =>
      _reliabilityCoordinator.createAutomaticBackupIfDue();

  Future<String?> exportDiagnosticReport() =>
      _reliabilityCoordinator.exportDiagnosticReport();

  Future<void> clearDiagnosticLog() =>
      _reliabilityCoordinator.clearDiagnosticLog();

  Future<void> refreshBackupCatalog({bool notify = true}) =>
      _reliabilityCoordinator.refreshBackupCatalog(notify: notify);

  Future<BackupImportPayload> loadAutomaticBackup(BackupCatalogEntry entry) =>
      _reliabilityCoordinator.loadAutomaticBackup(entry);

  Future<BackupExportResult?> exportBackupFile() =>
      _reliabilityCoordinator.exportBackupFile();

  Future<BackupImportPayload?> pickBackupFile() =>
      _reliabilityCoordinator.pickBackupFile();

  Map<String, Object?> _buildDiagnosticSnapshot() => <String, Object?>{
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
  };

  Future<void> restoreBackupFile(BackupImportPayload payload) =>
      _restoreCoordinator.restore(payload);

  Future<void> _reloadAfterRestore() async {
    _undoJournal.clear();
    _reliabilityCoordinator.resetReleaseReadiness();
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

  Future<ReleaseReadinessReport> runReleaseReadinessAudit() =>
      _reliabilityCoordinator.runReleaseReadinessAudit();

  void _registerUndo({
    required String label,
    required Future<void> Function() restore,
  }) {
    _undoJournal.push(ChronicleUndoEntry(label: label, restore: restore));
  }

  void _notifyAttachmentRefresh() {
    _attachmentRefreshNotifier.value += 1;
  }

  void _notifyStoreListeners() => notifyListeners();

  @override
  void dispose() {
    unawaited(shutdown());
    _timerService.dispose();
    _vaultCoordinator.dispose();
    _attachmentRefreshNotifier.dispose();
    super.dispose();
  }
}
