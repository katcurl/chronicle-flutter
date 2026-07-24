import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../application/backup/restore_coordinator.dart';
import '../application/sync/lan_discovery_coordinator.dart';
import '../application/sync/sync_coordinator.dart';
import '../application/timer/timer_service.dart';
import '../application/vault/vault_coordinator.dart';
import '../data/migration/legacy_preferences_importer.dart';
import '../data/backup/staged_restore.dart';
import '../data/repositories/app_repository.dart';
import '../data/repositories/drift_app_repository.dart';
import '../data/repositories/mutation_queue.dart';
import '../features/notes/custom_note_template_library.dart';
import '../features/notes/custom_note_template_store.dart';
import '../features/notes/note_document.dart';
import '../features/notes/note_templates.dart';
import '../features/notes/note_wiki_link_syntax.dart';
import '../features/notes/note_wiki_rename.dart';
import '../features/references/citation_syntax.dart';
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
       _customNoteTemplateStore = customNoteTemplateStore,
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
  final CustomNoteTemplateStore? _customNoteTemplateStore;
  final bool _migrateDeviceKeyOnStartup;
  late final PairingService pairingService;
  late final LanSyncService lanSyncService;
  final bool _automaticLanSyncEnabled;
  final bool _reliabilityFeaturesEnabled;
  late final LanAutoSyncService autoSyncService;
  final _uuid = const Uuid();
  final ChronicleUndoJournal _undoJournal = ChronicleUndoJournal();
  final MutationQueue _mutationQueue = MutationQueue();
  late final TimerService _timerService;
  late final RestoreCoordinator _restoreCoordinator;
  late final VaultCoordinator _vaultCoordinator;
  late final SyncCoordinator _syncCoordinator;
  late final LanDiscoveryCoordinator _lanDiscoveryCoordinator;
  final ValueNotifier<int> _attachmentRefreshNotifier = ValueNotifier<int>(0);

  ValueListenable<int> get attachmentRefreshListenable =>
      _attachmentRefreshNotifier;

  AppData data = AppData.empty();
  List<NoteTemplate> customNoteTemplates = const <NoteTemplate>[];
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

  NoteTemplate get blankNoteTemplate =>
      noteTemplates.firstWhere((template) => template.id == 'blank');

  List<NoteTemplate> get availableNoteTemplates =>
      List<NoteTemplate>.unmodifiable(<NoteTemplate>[
        blankNoteTemplate,
        ...customNoteTemplates,
      ]);

  List<NoteTemplate> get applicableNoteTemplates =>
      List<NoteTemplate>.unmodifiable(customNoteTemplates);

  Future<void> _loadCustomNoteTemplates() async {
    final store = _customNoteTemplateStore;
    if (store == null) {
      customNoteTemplates = const <NoteTemplate>[];
      return;
    }
    customNoteTemplates = await store.load();
  }

  Future<NoteTemplate> createCustomNoteTemplate({
    required String title,
    required String icon,
    required String noteType,
    required String content,
    String category = '',
    List<String> defaultTags = const <String>[],
    Map<String, String> defaultProperties = const <String, String>{},
  }) async {
    if (customNoteTemplates.length >=
        CustomNoteTemplateStore.maxTemplateCount) {
      throw StateError('Достигнут лимит пользовательских шаблонов.');
    }
    final template = _normalizeCustomNoteTemplate(
      id: 'custom_${_uuid.v4()}',
      title: title,
      icon: icon,
      noteType: noteType,
      content: content,
      category: category,
      defaultTags: defaultTags,
      defaultProperties: defaultProperties,
    );
    await _replaceCustomTemplates(<NoteTemplate>[
      ...customNoteTemplates,
      template,
    ]);
    return template;
  }

  Future<NoteTemplate> updateCustomNoteTemplate({
    required String id,
    required String title,
    required String icon,
    required String noteType,
    required String content,
    String category = '',
    List<String> defaultTags = const <String>[],
    Map<String, String> defaultProperties = const <String, String>{},
  }) async {
    final index = customNoteTemplates.indexWhere(
      (template) => template.id == id,
    );
    if (index < 0) {
      throw StateError('Пользовательский шаблон не найден.');
    }
    final template = _normalizeCustomNoteTemplate(
      id: id,
      title: title,
      icon: icon,
      noteType: noteType,
      content: content,
      category: category,
      defaultTags: defaultTags,
      defaultProperties: defaultProperties,
    );
    final next = List<NoteTemplate>.from(customNoteTemplates);
    next[index] = template;
    await _replaceCustomTemplates(next);
    return template;
  }

  Future<NoteTemplate> duplicateCustomNoteTemplate(String id) async {
    final index = customNoteTemplates.indexWhere(
      (template) => template.id == id,
    );
    if (index < 0) {
      throw StateError('Пользовательский шаблон не найден.');
    }
    final source = customNoteTemplates[index];
    return createCustomNoteTemplate(
      title: _copyTemplateTitle(source.title),
      icon: source.icon,
      noteType: source.noteType,
      content: source.content,
      category: source.category,
      defaultTags: source.defaultTags,
      defaultProperties: source.defaultProperties,
    );
  }

  Future<List<NoteTemplate>> importCustomNoteTemplates(
    List<NoteTemplate> imported,
  ) async {
    if (imported.isEmpty) return const <NoteTemplate>[];
    final remaining =
        CustomNoteTemplateStore.maxTemplateCount - customNoteTemplates.length;
    if (remaining <= 0) {
      throw StateError('Достигнут лимит пользовательских шаблонов.');
    }

    final next = List<NoteTemplate>.from(customNoteTemplates);
    final added = <NoteTemplate>[];
    for (final source in imported) {
      if (added.length >= remaining) break;
      if (next.any(
        (template) => CustomNoteTemplateLibrary.equivalent(template, source),
      )) {
        continue;
      }
      final importedTemplate = _normalizeCustomNoteTemplate(
        id: 'custom_${_uuid.v4()}',
        title: source.title,
        icon: source.icon,
        noteType: source.noteType,
        content: source.content,
        category: source.category,
        defaultTags: source.defaultTags,
        defaultProperties: source.defaultProperties,
      );
      next.add(importedTemplate);
      added.add(importedTemplate);
    }
    if (added.isNotEmpty) {
      await _replaceCustomTemplates(next);
    }
    return List<NoteTemplate>.unmodifiable(added);
  }

  Future<void> deleteCustomNoteTemplate(String id) async {
    final next = customNoteTemplates
        .where((template) => template.id != id)
        .toList(growable: false);
    if (next.length == customNoteTemplates.length) {
      return;
    }
    await _replaceCustomTemplates(next);
  }

  String _copyTemplateTitle(String title) {
    final normalized = title.trim();
    var index = 1;
    while (true) {
      final prefix = index == 1 ? 'Копия — ' : 'Копия $index — ';
      final maxSourceLength = 120 - prefix.length;
      final source =
          normalized.length <= maxSourceLength
              ? normalized
              : normalized.substring(0, maxSourceLength).trimRight();
      final candidate = '$prefix$source';
      final exists = customNoteTemplates.any(
        (template) =>
            template.title.trim().toLowerCase() == candidate.toLowerCase(),
      );
      if (!exists) return candidate;
      index += 1;
    }
  }

  NoteTemplate _normalizeCustomNoteTemplate({
    required String id,
    required String title,
    required String icon,
    required String noteType,
    required String content,
    required String category,
    required List<String> defaultTags,
    required Map<String, String> defaultProperties,
  }) {
    final normalizedTags = <String>[];
    final seenTags = <String>{};
    for (final rawTag in defaultTags) {
      final tag = rawTag.trim();
      if (tag.isNotEmpty && seenTags.add(tag.toLowerCase())) {
        normalizedTags.add(tag);
      }
    }
    final normalizedProperties = <String, String>{};
    for (final entry in defaultProperties.entries) {
      final key = entry.key.trim();
      if (key.isNotEmpty) {
        normalizedProperties[key] = entry.value.trim();
      }
    }
    final template = NoteTemplate(
      id: id,
      title: title.trim(),
      icon: icon.trim().isEmpty ? '📝' : icon.trim(),
      noteType: noteType.trim().isEmpty ? 'note' : noteType.trim(),
      content: '${content.trimRight()}\n',
      category: category.trim(),
      defaultTags: List<String>.unmodifiable(normalizedTags),
      defaultProperties: Map<String, String>.unmodifiable(normalizedProperties),
      isCustom: true,
    );
    if (!CustomNoteTemplateStore.isValid(template)) {
      throw ArgumentError(
        'Шаблон должен иметь название и непустое содержимое допустимого размера.',
      );
    }
    return template;
  }

  Future<void> _replaceCustomTemplates(List<NoteTemplate> next) async {
    final normalized = List<NoteTemplate>.unmodifiable(next);
    final store = _customNoteTemplateStore;
    if (store != null) {
      await store.save(normalized);
    }
    customNoteTemplates = normalized;
    notifyListeners();
  }

  List<Project> get activeProjects =>
      data.projects.where((project) => !project.archived).toList();

  List<Project> get archivedProjects =>
      data.projects.where((project) => project.archived).toList();

  Project? projectById(String id) {
    for (final project in data.projects) {
      if (project.id == id) return project;
    }
    return null;
  }

  Note? noteById(String id) {
    for (final note in data.notes) {
      if (note.id == id) return note;
    }
    return null;
  }

  Note? noteByTitle(String title) {
    final matches = notesByTitle(title);
    return matches.isEmpty ? null : matches.first;
  }

  List<Note> notesByTitle(String title) {
    final normalized = title.trim().toLowerCase();
    return data.notes
        .where((note) => note.title.trim().toLowerCase() == normalized)
        .toList(growable: false);
  }

  List<Note> notesForWikiTarget(String rawTarget, {Note? source}) {
    final reference = NoteWikiTarget.parse(rawTarget);
    if (reference.noteId != null) {
      final exact = noteById(reference.noteId!);
      return exact == null ? const <Note>[] : <Note>[exact];
    }
    var candidates = notesByTitle(reference.noteTitle);
    if (reference.projectTitle != null) {
      final projectName = reference.projectTitle!.trim().toLowerCase();
      candidates = candidates
          .where((note) {
            final project = projectById(note.projectId);
            return project?.title.trim().toLowerCase() == projectName;
          })
          .toList(growable: false);
    }

    final sorted = List<Note>.from(candidates);
    sorted.sort((left, right) {
      int rank(Note note) {
        if (source == null) return 2;
        if (note.projectId == source.projectId &&
            note.folderPath.trim() == source.folderPath.trim()) {
          return 0;
        }
        if (note.projectId == source.projectId) return 1;
        return 2;
      }

      final rankCompare = rank(left).compareTo(rank(right));
      if (rankCompare != 0) return rankCompare;
      final leftProject = projectById(left.projectId)?.title ?? '';
      final rightProject = projectById(right.projectId)?.title ?? '';
      final projectCompare = leftProject.toLowerCase().compareTo(
        rightProject.toLowerCase(),
      );
      if (projectCompare != 0) return projectCompare;
      final folderCompare = left.folderPath.toLowerCase().compareTo(
        right.folderPath.toLowerCase(),
      );
      if (folderCompare != 0) return folderCompare;
      return left.id.compareTo(right.id);
    });
    return List<Note>.unmodifiable(sorted);
  }

  Note? resolveWikiTarget(String rawTarget, {Note? source}) {
    final reference = NoteWikiTarget.parse(rawTarget);
    final candidates = notesForWikiTarget(rawTarget, source: source);
    if (candidates.length == 1) return candidates.single;
    if (reference.isQualified || source == null || candidates.isEmpty) {
      return null;
    }

    final sameFolder = candidates
        .where(
          (note) =>
              note.projectId == source.projectId &&
              note.folderPath.trim() == source.folderPath.trim(),
        )
        .toList(growable: false);
    if (sameFolder.length == 1) return sameFolder.single;

    final sameProject = candidates
        .where((note) => note.projectId == source.projectId)
        .toList(growable: false);
    return sameProject.length == 1 ? sameProject.single : null;
  }

  String wikiTargetFor(Note note) {
    final duplicates = notesByTitle(note.title);
    if (duplicates.length <= 1) return note.title;
    return NoteWikiTarget.exactId(note.id);
  }

  List<NoteLink> outgoingLinksFor(String noteId) => data.noteLinks
      .where((link) => link.sourceNoteId == noteId)
      .toList(growable: false);

  List<NoteLink> backlinksFor(Note note) {
    return data.noteLinks
        .where((link) {
          if (link.targetNoteId != null) {
            return link.targetNoteId == note.id;
          }
          final source = noteById(link.sourceNoteId);
          return resolveWikiTarget(link.targetTitle, source: source)?.id ==
              note.id;
        })
        .toList(growable: false);
  }

  NoteWikiRenamePlan buildWikiRenamePlan(Note note, String newTitle) {
    return NoteWikiRenamePlanner.build(
      target: note,
      newTitle: newTitle,
      notes: data.notes,
      resolveTarget:
          (source, rawTarget) => resolveWikiTarget(rawTarget, source: source),
      targetCandidates:
          (source, rawTarget) => notesForWikiTarget(rawTarget, source: source),
    );
  }

  List<NoteWikiLinkIssue> wikiLinkIssues() {
    return NoteWikiRenamePlanner.findIssues(
      notes: data.notes,
      resolveTarget:
          (source, rawTarget) => resolveWikiTarget(rawTarget, source: source),
      targetCandidates:
          (source, rawTarget) => notesForWikiTarget(rawTarget, source: source),
    );
  }

  Future<NoteWikiRenameUndo> applyWikiRenamePlan(
    NoteWikiRenamePlan plan,
  ) async {
    final target = noteById(plan.targetNoteId);
    if (target == null) {
      throw StateError('Переименовываемая заметка больше не существует.');
    }
    if (target.title != plan.oldTitle) {
      throw StateError(
        'Название заметки уже изменилось; открой предварительный просмотр снова.',
      );
    }

    if (plan.skippedAmbiguousOccurrences > 0) {
      throw StateError(
        'Сначала исправь неоднозначные ссылки через проверку связей.',
      );
    }

    final changedIds = <String>{
      target.id,
      ...plan.sourceChanges.map((change) => change.sourceNoteId),
    };
    final snapshots = <NoteWikiSnapshot>[];
    final now = DateTime.now();
    for (final noteId in changedIds) {
      final note = noteById(noteId);
      if (note == null) continue;
      snapshots.add(
        NoteWikiSnapshot(noteId: note.id, title: note.title, body: note.body),
      );
      final version = NoteVersion(
        id: _uuid.v4(),
        noteId: note.id,
        title: note.title,
        body: note.body,
        tags: List<String>.from(note.tags),
        status: note.status,
        folderPath: note.folderPath,
        noteType: note.noteType,
        properties: Map<String, String>.from(note.properties),
        reason: 'Перед безопасным переименованием «${plan.oldTitle}»',
        createdAt: now,
      );
      data.noteVersions.insert(0, version);
      await _repository.saveNoteVersion(version);
    }

    try {
      for (final change in plan.sourceChanges) {
        final source = noteById(change.sourceNoteId);
        if (source == null) continue;
        source.body = change.updatedBody;
      }
      target.title = plan.newTitle;

      for (final noteId in changedIds) {
        final note = noteById(noteId);
        if (note == null) continue;
        note.updatedAt = DateTime.now();
        note.revision += 1;
        await _repository.saveNote(note);
      }
      for (final noteId in changedIds) {
        final note = noteById(noteId);
        if (note != null) {
          await _syncNoteLinks(note, notify: false);
        }
      }
    } on Object {
      await _restoreWikiSnapshots(snapshots);
      rethrow;
    }
    _scheduleSyncOverviewRefresh();
    _scheduleVaultMirror();
    notifyListeners();
    final appliedSnapshots = changedIds
        .map(noteById)
        .whereType<Note>()
        .map(
          (note) => NoteWikiSnapshot(
            noteId: note.id,
            title: note.title,
            body: note.body,
          ),
        )
        .toList(growable: false);
    return NoteWikiRenameUndo(
      snapshots: List<NoteWikiSnapshot>.unmodifiable(snapshots),
      appliedSnapshots: List<NoteWikiSnapshot>.unmodifiable(appliedSnapshots),
    );
  }

  Future<void> undoWikiRename(NoteWikiRenameUndo undo) async {
    for (final expected in undo.appliedSnapshots) {
      final note = noteById(expected.noteId);
      if (note == null ||
          note.title != expected.title ||
          note.body != expected.body) {
        throw StateError(
          'После переименования одна из заметок уже изменилась; '
          'автоматическая отмена остановлена.',
        );
      }
    }
    final restoredIds = <String>{};
    for (final snapshot in undo.snapshots) {
      final note = noteById(snapshot.noteId);
      if (note == null) continue;
      final version = NoteVersion(
        id: _uuid.v4(),
        noteId: note.id,
        title: note.title,
        body: note.body,
        tags: List<String>.from(note.tags),
        status: note.status,
        folderPath: note.folderPath,
        noteType: note.noteType,
        properties: Map<String, String>.from(note.properties),
        reason: 'Перед отменой безопасного переименования',
      );
      data.noteVersions.insert(0, version);
      await _repository.saveNoteVersion(version);
      note.title = snapshot.title;
      note.body = snapshot.body;
      note.updatedAt = DateTime.now();
      note.revision += 1;
      restoredIds.add(note.id);
      await _repository.saveNote(note);
    }
    for (final noteId in restoredIds) {
      final note = noteById(noteId);
      if (note != null) {
        await _syncNoteLinks(note, notify: false);
      }
    }
    _scheduleSyncOverviewRefresh();
    _scheduleVaultMirror();
    notifyListeners();
  }

  Future<void> _restoreWikiSnapshots(
    Iterable<NoteWikiSnapshot> snapshots,
  ) async {
    final restoredIds = <String>{};
    for (final snapshot in snapshots) {
      final note = noteById(snapshot.noteId);
      if (note == null) continue;
      note.title = snapshot.title;
      note.body = snapshot.body;
      note.updatedAt = DateTime.now();
      note.revision += 1;
      restoredIds.add(note.id);
      await _repository.saveNote(note);
    }
    for (final noteId in restoredIds) {
      final note = noteById(noteId);
      if (note != null) {
        await _syncNoteLinks(note, notify: false);
      }
    }
    notifyListeners();
  }

  Future<void> repairWikiLink({
    required Note source,
    required String rawTarget,
    required Note target,
  }) async {
    final parsed = NoteDocument.parse(source.body);
    var content = parsed.content;
    var changed = false;
    final normalized = rawTarget.trim().toLowerCase();
    for (final reference
        in NoteWikiLinkSyntax.all(parsed.content).toList().reversed) {
      if (reference.target.trim().toLowerCase() != normalized) {
        continue;
      }
      final explicitLabel = reference.label?.trim();
      final label =
          explicitLabel != null && explicitLabel.isNotEmpty
              ? explicitLabel
              : target.title;
      content = NoteWikiLinkSyntax.replaceTarget(
        content,
        reference,
        target: NoteWikiTarget.exactId(target.id),
        label: label,
      );
      changed = true;
    }
    if (!changed) return;

    final version = NoteVersion(
      id: _uuid.v4(),
      noteId: source.id,
      title: source.title,
      body: source.body,
      tags: List<String>.from(source.tags),
      status: source.status,
      folderPath: source.folderPath,
      noteType: source.noteType,
      properties: Map<String, String>.from(source.properties),
      reason: 'Перед исправлением вики-ссылки',
    );
    data.noteVersions.insert(0, version);
    await _repository.saveNoteVersion(version);
    source.body = NoteDocument.replaceContent(source.body, content);
    source.updatedAt = DateTime.now();
    source.revision += 1;
    await _repository.saveNote(source);
    await _syncNoteLinks(source, notify: false);
    _scheduleSyncOverviewRefresh();
    _scheduleVaultMirror();
    notifyListeners();
  }

  List<NoteVersion> versionsFor(String noteId) {
    final versions =
        data.noteVersions.where((version) => version.noteId == noteId).toList();
    versions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return versions;
  }

  int get activeSeconds => _timerService.activeSeconds;

  int get todaySeconds => _timerService.todaySeconds;

  Future<void> startTimer({
    required String description,
    required String projectId,
    String? taskId,
    String? noteId,
  }) {
    return _timerService.start(
      description: description,
      projectId: projectId,
      taskId: taskId,
      noteId: noteId,
    );
  }

  Future<void> stopTimer() => _timerService.stop();

  Future<void> addTask(WorkTask task) {
    final persisted = _cloneTask(task);
    return _mutationQueue.run(() async {
      await _repository.saveTask(persisted);
      data.tasks.insert(0, persisted);
      _scheduleSyncOverviewRefresh();
      notifyListeners();
    });
  }

  Future<void> updateTask(WorkTask task) {
    final persisted = _cloneTask(task)..updatedAt = DateTime.now();
    return _mutationQueue.run(() async {
      await _repository.saveTask(persisted);
      final index = data.tasks.indexWhere((item) => item.id == persisted.id);
      if (index >= 0) {
        data.tasks[index] = persisted;
      }
      _scheduleSyncOverviewRefresh();
      notifyListeners();
    });
  }

  Future<void> updateTaskStatus(WorkTask task, String status) {
    final updated = _cloneTask(task);
    updated.status = status;
    updated.updatedAt = DateTime.now();
    updated.completedAt = status == 'done' ? DateTime.now() : null;
    return updateTask(updated);
  }

  Future<void> deleteTask(String id) async {
    final index = data.tasks.indexWhere((task) => task.id == id);
    if (index < 0) {
      return;
    }
    final removed = _cloneTask(data.tasks[index]);
    final childSnapshots = data.tasks
        .where((task) => task.parentTaskId == id)
        .map(_cloneTask)
        .toList(growable: false);
    final deletedAt = DateTime.now();

    await _repository.deleteTaskGraph(id, deletedAt);
    data.tasks.removeAt(index);
    for (final child in data.tasks.where((task) => task.parentTaskId == id)) {
      child.parentTaskId = null;
      child.updatedAt = deletedAt;
    }
    _registerUndo(
      label: 'Удаление задачи «${removed.title}»',
      restore: () async {
        final restored = _cloneTask(removed)..deletedAt = null;
        await _repository.restoreTask(restored.id);
        await _repository.saveTask(restored);
        data.tasks.removeWhere((task) => task.id == restored.id);
        data.tasks.insert(index.clamp(0, data.tasks.length).toInt(), restored);
        for (final snapshot in childSnapshots) {
          final restoredChild = _cloneTask(snapshot);
          final childIndex = data.tasks.indexWhere(
            (task) => task.id == restoredChild.id,
          );
          if (childIndex >= 0) {
            data.tasks[childIndex] = restoredChild;
          } else {
            data.tasks.add(restoredChild);
          }
          await _repository.saveTask(restoredChild);
        }
        _scheduleSyncOverviewRefresh();
      },
    );
    _scheduleSyncOverviewRefresh();
    notifyListeners();
  }

  Future<void> addProject(Project project) {
    final persisted = _cloneProject(project);
    return _mutationQueue.run(() async {
      await _repository.saveProject(persisted);
      data.projects.add(persisted);
      _scheduleSyncOverviewRefresh();
      notifyListeners();
    });
  }

  Future<void> updateProject(Project project) {
    final persisted = _cloneProject(project)..updatedAt = DateTime.now();
    return _mutationQueue.run(() async {
      await _repository.saveProject(persisted);
      final index = data.projects.indexWhere((item) => item.id == persisted.id);
      if (index >= 0) {
        data.projects[index] = persisted;
      }
      _scheduleSyncOverviewRefresh();
      notifyListeners();
    });
  }

  Future<void> setProjectArchived(Project project, bool archived) async {
    if (project.archived == archived) {
      return;
    }
    final previous = project.archived;
    final projectId = project.id;
    final projectTitle = project.title;
    project.archived = archived;
    project.updatedAt = DateTime.now();
    await _repository.saveProject(project);
    _registerUndo(
      label:
          archived
              ? 'Архивирование проекта «$projectTitle»'
              : 'Возврат проекта «$projectTitle» из архива',
      restore: () async {
        final current = projectById(projectId);
        if (current == null) {
          return;
        }
        current.archived = previous;
        current.updatedAt = DateTime.now();
        await _repository.saveProject(current);
        _scheduleSyncOverviewRefresh();
      },
    );
    _scheduleSyncOverviewRefresh();
    notifyListeners();
  }

  int citationUsageCount(String citationKey) {
    return data.notes.fold<int>(
      0,
      (sum, note) => sum + CitationSyntax.countKey(note.body, citationKey),
    );
  }

  void addCitationSource(CitationSource source) {
    data.citationSources.insert(0, source);
    unawaited(_repository.saveCitationSources(data.citationSources));
    notifyListeners();
  }

  void updateCitationSource(CitationSource source) {
    source.updatedAt = DateTime.now();
    final index = data.citationSources.indexWhere(
      (item) => item.id == source.id,
    );
    if (index < 0) {
      data.citationSources.insert(0, source);
    } else {
      data.citationSources[index] = source;
    }
    unawaited(_repository.saveCitationSources(data.citationSources));
    notifyListeners();
  }

  Future<void> deleteCitationSource(String id) async {
    final index = data.citationSources.indexWhere((source) => source.id == id);
    if (index < 0) {
      return;
    }
    final removed = _cloneCitationSource(data.citationSources[index]);
    data.citationSources.removeAt(index);
    await _repository.saveCitationSources(data.citationSources);
    _registerUndo(
      label: 'Удаление источника «${removed.title}»',
      restore: () async {
        data.citationSources.removeWhere((source) => source.id == removed.id);
        data.citationSources.insert(
          index.clamp(0, data.citationSources.length).toInt(),
          removed,
        );
        await _repository.saveCitationSources(data.citationSources);
      },
    );
    notifyListeners();
  }

  int importCitationSources(Iterable<CitationSource> sources) {
    final keys =
        data.citationSources
            .map((source) => source.normalizedCitationKey)
            .toSet();
    final dois =
        data.citationSources
            .map((source) => source.normalizedDoi)
            .where((doi) => doi.isNotEmpty)
            .toSet();
    var imported = 0;
    for (final source in sources) {
      final key = source.normalizedCitationKey;
      final doi = source.normalizedDoi;
      if (key.isEmpty || keys.contains(key)) continue;
      if (doi.isNotEmpty && dois.contains(doi)) continue;
      data.citationSources.add(source);
      keys.add(key);
      if (doi.isNotEmpty) dois.add(doi);
      imported += 1;
    }
    if (imported > 0) {
      data.citationSources.sort(
        (left, right) => right.updatedAt.compareTo(left.updatedAt),
      );
      unawaited(_repository.saveCitationSources(data.citationSources));
      notifyListeners();
    }
    return imported;
  }

  Future<void> addNote(Note note) {
    final persisted = _cloneNote(note);
    return _mutationQueue.run(() async {
      await _repository.saveNote(persisted);
      data.notes.insert(0, persisted);
      await _syncNoteLinks(persisted);
      _scheduleSyncOverviewRefresh();
      _scheduleVaultMirror();
      notifyListeners();
    });
  }

  Future<void> updateNote(Note note) {
    final persisted =
        _cloneNote(note)
          ..updatedAt = DateTime.now()
          ..revision += 1;
    return _mutationQueue.run(() async {
      await _repository.saveNote(persisted);
      final index = data.notes.indexWhere((item) => item.id == persisted.id);
      if (index >= 0) {
        data.notes[index] = persisted;
      }
      await _syncNoteLinks(persisted);
      _scheduleSyncOverviewRefresh();
      _scheduleVaultMirror();
      notifyListeners();
    });
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
    final persisted = NoteVersion.fromJson(
      Map<String, dynamic>.from(version.toJson()),
    );
    return _mutationQueue.run(() async {
      await _repository.saveNoteVersion(persisted);
      data.noteVersions.insert(0, persisted);
      _scheduleSyncOverviewRefresh();
      notifyListeners();
    });
  }

  void restoreNoteVersion(Note note, NoteVersion version) {
    note.title = version.title;
    note.body = version.body;
    note.tags = List<String>.from(version.tags);
    note.status = version.status;
    note.folderPath = version.folderPath;
    note.noteType = version.noteType;
    note.properties = Map<String, String>.from(version.properties);
    updateNote(note);
  }

  Future<void> deleteNote(String id) async {
    final deletedAt = DateTime.now();
    final noteIndex = data.notes.indexWhere((note) => note.id == id);
    if (noteIndex < 0) {
      return;
    }

    final removed = _cloneNote(data.notes[noteIndex]);
    final taskSnapshots = data.tasks
        .where((task) => task.noteId == id)
        .map(_cloneTask)
        .toList(growable: false);
    final linkSnapshots = data.noteLinks
        .where((link) => link.sourceNoteId == id || link.targetNoteId == id)
        .map(_cloneNoteLink)
        .toList(growable: false);

    await _repository.deleteNoteGraph(id, deletedAt);
    data.notes.removeAt(noteIndex);
    data.noteLinks.removeWhere(
      (link) => link.sourceNoteId == id || link.targetNoteId == id,
    );
    for (final task in data.tasks.where((task) => task.noteId == id)) {
      task.noteId = null;
      task.updatedAt = deletedAt;
    }
    _registerUndo(
      label: 'Удаление заметки «${removed.title}»',
      restore: () async {
        final restored = _cloneNote(removed)..deletedAt = null;
        await _repository.restoreNote(restored.id);
        await _repository.saveNote(restored);
        data.notes.removeWhere((note) => note.id == restored.id);
        data.notes.insert(
          noteIndex.clamp(0, data.notes.length).toInt(),
          restored,
        );
        for (final snapshot in taskSnapshots) {
          final restoredTask = _cloneTask(snapshot);
          final taskIndex = data.tasks.indexWhere(
            (task) => task.id == restoredTask.id,
          );
          if (taskIndex >= 0) {
            data.tasks[taskIndex] = restoredTask;
          } else {
            data.tasks.add(restoredTask);
          }
          await _repository.saveTask(restoredTask);
        }
        data.noteLinks.removeWhere(
          (link) =>
              link.sourceNoteId == restored.id ||
              link.targetNoteId == restored.id,
        );
        data.noteLinks.addAll(linkSnapshots.map(_cloneNoteLink));
        try {
          await rebuildAllNoteLinks(notify: false);
        } on Object catch (error) {
          await _recordReliability(
            stage: ReliabilityStage.system,
            level: ReliabilityLevel.warning,
            message:
                'Заметка восстановлена, но индекс связей требует перестроения.',
            details: <String, Object?>{'error': error.toString()},
            notify: false,
          );
        }
        _scheduleSyncOverviewRefresh();
        _scheduleVaultMirror();
      },
    );
    try {
      await rebuildAllNoteLinks(notify: false);
    } on Object catch (error) {
      await _recordReliability(
        stage: ReliabilityStage.system,
        level: ReliabilityLevel.warning,
        message: 'Заметка удалена, но индекс связей требует перестроения.',
        details: <String, Object?>{'error': error.toString()},
        notify: false,
      );
    }
    _scheduleSyncOverviewRefresh();
    _scheduleVaultMirror();
    notifyListeners();
  }

  Future<void> rebuildAllNoteLinks({bool notify = true}) async {
    for (final note in data.notes) {
      await _syncNoteLinks(note, notify: false);
    }
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _syncNoteLinks(Note note, {bool notify = true}) async {
    final targets = NoteDocument.extractWikiTargets(note.body);
    final now = DateTime.now();
    final links =
        targets.map((title) {
          final target = resolveWikiTarget(title, source: note);
          return NoteLink(
            id: _uuid.v4(),
            sourceNoteId: note.id,
            targetTitle: title,
            targetNoteId: target?.id,
            createdAt: now,
          );
        }).toList();

    data.noteLinks.removeWhere((link) => link.sourceNoteId == note.id);
    data.noteLinks.addAll(links);
    await _repository.replaceNoteLinks(note.id, links);
    if (notify) notifyListeners();
  }

  Future<void> _hydrateNoteMetadata() async {
    for (final note in data.notes) {
      final document = NoteDocument.parse(note.body);
      if (document.frontMatter.isEmpty) continue;
      var changed = false;
      final frontMatter = Map<String, String>.from(document.frontMatter);

      final type = frontMatter.remove('type');
      if (type != null && type.isNotEmpty && note.noteType == 'note') {
        note.noteType = type;
        changed = true;
      }
      final status = frontMatter.remove('status');
      if (status != null && status.isNotEmpty && note.status == 'draft') {
        note.status = status;
        changed = true;
      }
      final folder = frontMatter.remove('folder');
      if (folder != null && folder.isNotEmpty && note.folderPath.isEmpty) {
        note.folderPath = folder;
        changed = true;
      }
      final tags = NoteDocument.parseTags(frontMatter.remove('tags'));
      if (tags.isNotEmpty && note.tags.isEmpty) {
        note.tags = tags;
        changed = true;
      }
      if (frontMatter.isNotEmpty && note.properties.isEmpty) {
        note.properties = frontMatter;
        changed = true;
      }
      if (changed) await _repository.saveNote(note);
    }
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

  Note _cloneNote(Note note) =>
      Note.fromJson(Map<String, dynamic>.from(note.toJson()));

  Project _cloneProject(Project project) =>
      Project.fromJson(Map<String, dynamic>.from(project.toJson()));

  WorkTask _cloneTask(WorkTask task) =>
      WorkTask.fromJson(Map<String, dynamic>.from(task.toJson()));

  NoteLink _cloneNoteLink(NoteLink link) =>
      NoteLink.fromJson(Map<String, dynamic>.from(link.toJson()));

  CitationSource _cloneCitationSource(CitationSource source) =>
      CitationSource.fromJson(Map<String, dynamic>.from(source.toJson()));

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
