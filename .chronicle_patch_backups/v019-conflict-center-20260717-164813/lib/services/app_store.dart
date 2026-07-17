import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/migration/legacy_preferences_importer.dart';
import '../data/repositories/app_repository.dart';
import '../data/repositories/drift_app_repository.dart';
import '../features/notes/note_document.dart';
import '../models/app_models.dart';
import '../reliability/reliability_models.dart';
import '../reliability/reliability_service.dart';
import '../sync/lan_auto_sync_models.dart';
import '../sync/lan_auto_sync_service.dart';
import '../sync/lan_auto_sync_transport.dart';
import '../sync/lan_sync_models.dart';
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
    ReliabilityService? reliabilityService,
    bool enableAutomaticLanSync = false,
    bool enableReliabilityFeatures = false,
  }) : _repository = repository,
       _legacyImporter = legacyImporter,
       _vaultService = vaultService ?? VaultService(),
       _reliabilityService = reliabilityService ?? ReliabilityService(),
       pairingService =
           pairingService ?? PairingService(repository: repository),
       lanSyncService =
           lanSyncService ?? LanSyncService(repository: repository),
       _automaticLanSyncEnabled = enableAutomaticLanSync,
       _reliabilityFeaturesEnabled = enableReliabilityFeatures {
    autoSyncService = LanAutoSyncService(
      repository: repository,
      lanSyncService: this.lanSyncService,
    );
  }

  factory AppStore.production() => AppStore(
    repository: DriftAppRepository(),
    legacyImporter: LegacyPreferencesImporter(),
    enableAutomaticLanSync: true,
    enableReliabilityFeatures: true,
  );

  final AppRepository _repository;
  final LegacyPreferencesImporter? _legacyImporter;
  final VaultService _vaultService;
  final ReliabilityService _reliabilityService;
  final PairingService pairingService;
  final LanSyncService lanSyncService;
  final bool _automaticLanSyncEnabled;
  final bool _reliabilityFeaturesEnabled;
  late final LanAutoSyncService autoSyncService;
  final _uuid = const Uuid();

  AppData data = AppData.empty();
  bool ready = false;
  Object? loadError;

  DeviceIdentity? deviceIdentity;
  List<TrustedDevice> trustedDevices = [];
  List<ChangeRecord> recentChanges = [];
  List<SyncCursor> syncCursors = [];
  SyncPreferences syncPreferences = const SyncPreferences();
  int journalEntryCount = 0;
  bool lanSyncBusy = false;
  String? lanSyncPeerDeviceId;
  LanSyncReport? lastLanSyncReport;
  bool lanDiscoveryActive = false;
  String lanDiscoveryStatus = 'Обнаружение ещё не запущено';
  String? lanAutoSyncError;
  final Map<String, LanDiscoveredPeer> _lanPeers = {};
  final Map<String, DateTime> _lastAutoSyncAttempt = {};
  final Map<String, String> _lanPeerErrors = {};

  VaultStatus vaultStatus = const VaultStatus.unavailable();
  VaultScanResult? pendingVaultScan;
  bool vaultBusy = false;
  String? lastEmergencyBackupPath;
  bool lastRestoreRolledBack = false;
  List<BackupCatalogEntry> automaticBackups = const <BackupCatalogEntry>[];
  bool backupCatalogBusy = false;
  String? backupCatalogError;

  List<ReliabilityEvent> reliabilityEvents = const <ReliabilityEvent>[];
  DateTime? lastAutomaticBackupAt;
  String? lastAutomaticBackupPath;
  bool reliabilityBusy = false;
  String? reliabilityError;

  DateTime? activeStartedAt;
  String activeDescription = '';
  String? activeProjectId;
  String? activeTaskId;
  String? activeNoteId;

  Timer? _ticker;
  Timer? _syncRefreshDebounce;
  Timer? _vaultMirrorDebounce;
  Timer? _lanPresenceTimer;
  LanAutoSyncNode? _autoSyncNode;
  StreamSubscription<LanDiscoveredPeer>? _autoSyncPeerSubscription;
  StreamSubscription<LanSyncReport>? _autoSyncHostReportSubscription;
  int nowTick = 0;

  Future<void> load() async {
    ready = false;
    loadError = null;
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
      if (!initialized) {
        final legacy = await _legacyImporter?.read();
        data = legacy ?? _seed();
        await _repository.replaceAll(data);
        await _repository.markInitialized();
      } else {
        data = await _repository.load();
      }

      await _hydrateNoteMetadata();
      await rebuildAllNoteLinks();
      await refreshSyncFoundation(notify: false);
      await _initializeVaultFoundation();
      await refreshBackupCatalog(notify: false);

      final activeTimer = await _repository.loadActiveTimer();
      if (activeTimer != null &&
          data.projects.any((project) => project.id == activeTimer.projectId)) {
        activeStartedAt = activeTimer.startedAt;
        activeDescription = activeTimer.description;
        activeProjectId = activeTimer.projectId;
        activeTaskId = activeTimer.taskId;
        activeNoteId = activeTimer.noteId;
        _startTicker();
      } else if (activeTimer != null) {
        await _repository.saveActiveTimer(null);
      }
      await _recordReliability(
        stage: ReliabilityStage.startup,
        level: ReliabilityLevel.success,
        message: 'Локальная база Chronicle успешно открыта.',
        details: <String, Object?>{
          'projects': data.projects.length,
          'tasks': data.tasks.length,
          'notes': data.notes.length,
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

  AppData _seed() {
    final p1 = Project(
      id: _uuid.v4(),
      title: 'Лекции школьникам',
      emoji: '🧪',
      description: 'Курс естественных наук',
    );
    final p2 = Project(
      id: _uuid.v4(),
      title: 'Научная работа',
      emoji: '🧬',
      description: 'Исследования и анализ данных',
    );

    final n1 = Note(
      id: _uuid.v4(),
      title: 'Лекция 1. Строение атома',
      projectId: p1.id,
      tags: const ['химия', 'лекция'],
      body: r'''---
type: lecture
status: draft
audience: 8 класс
---

# Строение атома

## Цели занятия

- понять устройство ядра;
- разобраться с электронными оболочками;
- научиться читать запись нуклида.

## Формулы

Энергия электрона в водородоподобном атоме:

\[
E_n = -\frac{13.6}{n^2}\,\text{эВ}
\]

> **Пример.** Для уровня $n=2$ энергия равна $-3.4$ эВ.

## Что осталось

- [ ] добавить схему орбиталей
- [ ] составить пять задач
- [ ] подготовить домашнее задание
''',
    );

    final n2 = Note(
      id: _uuid.v4(),
      title: 'Журнал исследования Orf9b',
      projectId: p2.id,
      tags: const ['orf9b', 'md'],
      body:
          '# Журнал исследования Orf9b\n\n'
          'Связано с [[Анализ TM-score]].\n\n'
          '## Следующий шаг\n\n'
          'Проверить метастабильные состояния по последней тысяче кадров.',
    );

    return AppData(
      projects: [p1, p2],
      tasks: [
        WorkTask(
          id: _uuid.v4(),
          title: 'Дополнить лекцию 1',
          projectId: p1.id,
          noteId: n1.id,
          estimateMinutes: 90,
        ),
        WorkTask(
          id: _uuid.v4(),
          title: 'Нарисовать схему орбиталей',
          projectId: p1.id,
          noteId: n1.id,
          status: 'blocked',
          estimateMinutes: 40,
        ),
        WorkTask(
          id: _uuid.v4(),
          title: 'Проанализировать TM-score',
          projectId: p2.id,
          noteId: n2.id,
          status: 'doing',
          estimateMinutes: 120,
        ),
      ],
      notes: [n1, n2],
      entries: [],
    );
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
    final normalized = title.trim().toLowerCase();
    for (final note in data.notes) {
      if (note.title.trim().toLowerCase() == normalized) return note;
    }
    return null;
  }

  List<NoteLink> outgoingLinksFor(String noteId) => data.noteLinks
      .where((link) => link.sourceNoteId == noteId)
      .toList(growable: false);

  List<NoteLink> backlinksFor(Note note) {
    final normalized = note.title.trim().toLowerCase();
    return data.noteLinks
        .where(
          (link) =>
              link.targetNoteId == note.id ||
              link.targetTitle.trim().toLowerCase() == normalized,
        )
        .toList(growable: false);
  }

  List<NoteVersion> versionsFor(String noteId) {
    final versions =
        data.noteVersions.where((version) => version.noteId == noteId).toList();
    versions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return versions;
  }

  int get activeSeconds =>
      activeStartedAt == null
          ? 0
          : DateTime.now().difference(activeStartedAt!).inSeconds;

  int get todaySeconds {
    final now = DateTime.now();
    final saved = data.entries
        .where(
          (entry) =>
              entry.startedAt.year == now.year &&
              entry.startedAt.month == now.month &&
              entry.startedAt.day == now.day,
        )
        .fold<int>(0, (sum, entry) => sum + entry.durationSeconds);
    return saved + activeSeconds;
  }

  void startTimer({
    required String description,
    required String projectId,
    String? taskId,
    String? noteId,
  }) {
    unawaited(
      _startTimer(
        description: description,
        projectId: projectId,
        taskId: taskId,
        noteId: noteId,
      ),
    );
  }

  Future<void> _startTimer({
    required String description,
    required String projectId,
    String? taskId,
    String? noteId,
  }) async {
    if (activeStartedAt != null) {
      await _stopTimer();
    }

    activeStartedAt = DateTime.now();
    activeDescription = description;
    activeProjectId = projectId;
    activeTaskId = taskId;
    activeNoteId = noteId;

    await _repository.saveActiveTimer(
      ActiveTimerState(
        startedAt: activeStartedAt!,
        description: description,
        projectId: projectId,
        taskId: taskId,
        noteId: noteId,
      ),
    );

    _startTicker();
    notifyListeners();
  }

  void stopTimer() {
    unawaited(_stopTimer());
  }

  Future<void> _stopTimer() async {
    final startedAt = activeStartedAt;
    final projectId = activeProjectId;
    if (startedAt == null || projectId == null) return;

    final duration = DateTime.now().difference(startedAt).inSeconds;
    final entry = TimeEntry(
      id: _uuid.v4(),
      description:
          activeDescription.trim().isEmpty
              ? 'Рабочая сессия'
              : activeDescription.trim(),
      projectId: projectId,
      taskId: activeTaskId,
      noteId: activeNoteId,
      startedAt: startedAt,
      durationSeconds: duration,
    );

    data.entries.insert(0, entry);
    await _repository.saveTimeEntry(entry);
    await _repository.saveActiveTimer(null);
    _scheduleSyncOverviewRefresh();

    activeStartedAt = null;
    activeDescription = '';
    activeProjectId = null;
    activeTaskId = null;
    activeNoteId = null;
    _ticker?.cancel();
    notifyListeners();
  }

  void addTask(WorkTask task) {
    data.tasks.insert(0, task);
    unawaited(_repository.saveTask(task));
    _scheduleSyncOverviewRefresh();
    notifyListeners();
  }

  void updateTask(WorkTask task) {
    task.updatedAt = DateTime.now();
    final index = data.tasks.indexWhere((item) => item.id == task.id);
    if (index >= 0) data.tasks[index] = task;
    unawaited(_repository.saveTask(task));
    _scheduleSyncOverviewRefresh();
    notifyListeners();
  }

  void updateTaskStatus(WorkTask task, String status) {
    task.status = status;
    task.updatedAt = DateTime.now();
    task.completedAt = status == 'done' ? DateTime.now() : null;
    unawaited(_repository.saveTask(task));
    _scheduleSyncOverviewRefresh();
    notifyListeners();
  }

  void deleteTask(String id) {
    final deletedAt = DateTime.now();
    data.tasks.removeWhere((task) => task.id == id);
    for (final child in data.tasks.where((task) => task.parentTaskId == id)) {
      child.parentTaskId = null;
      child.updatedAt = deletedAt;
      unawaited(_repository.saveTask(child));
    }
    unawaited(_repository.softDeleteTask(id, deletedAt));
    _scheduleSyncOverviewRefresh();
    notifyListeners();
  }

  void addProject(Project project) {
    data.projects.add(project);
    unawaited(_repository.saveProject(project));
    _scheduleSyncOverviewRefresh();
    notifyListeners();
  }

  void updateProject(Project project) {
    project.updatedAt = DateTime.now();
    final index = data.projects.indexWhere((item) => item.id == project.id);
    if (index >= 0) data.projects[index] = project;
    unawaited(_repository.saveProject(project));
    _scheduleSyncOverviewRefresh();
    notifyListeners();
  }

  void setProjectArchived(Project project, bool archived) {
    project.archived = archived;
    project.updatedAt = DateTime.now();
    unawaited(_repository.saveProject(project));
    _scheduleSyncOverviewRefresh();
    notifyListeners();
  }

  void addNote(Note note) {
    data.notes.insert(0, note);
    unawaited(_repository.saveNote(note));
    unawaited(_syncNoteLinks(note));
    _scheduleSyncOverviewRefresh();
    _scheduleVaultMirror();
    notifyListeners();
  }

  void updateNote(Note note) {
    note.updatedAt = DateTime.now();
    note.revision += 1;
    final index = data.notes.indexWhere((item) => item.id == note.id);
    if (index >= 0) data.notes[index] = note;
    unawaited(_repository.saveNote(note));
    unawaited(_syncNoteLinks(note));
    _scheduleSyncOverviewRefresh();
    _scheduleVaultMirror();
    notifyListeners();
  }

  void addNoteVersion(NoteVersion version) {
    data.noteVersions.insert(0, version);
    unawaited(_repository.saveNoteVersion(version));
    _scheduleSyncOverviewRefresh();
    notifyListeners();
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

  void deleteNote(String id) {
    final deletedAt = DateTime.now();
    final noteIndex = data.notes.indexWhere((note) => note.id == id);
    if (noteIndex < 0) return;

    data.notes.removeAt(noteIndex);
    data.noteLinks.removeWhere(
      (link) => link.sourceNoteId == id || link.targetNoteId == id,
    );
    for (final task in data.tasks.where((task) => task.noteId == id)) {
      task.noteId = null;
      task.updatedAt = deletedAt;
      unawaited(_repository.saveTask(task));
    }
    unawaited(_repository.replaceNoteLinks(id, const []));
    unawaited(_repository.softDeleteNote(id, deletedAt));
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
          final target = noteByTitle(title);
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
    deviceIdentity = await _repository.ensureDeviceIdentity();
    trustedDevices = await _repository.loadTrustedDevices();
    syncPreferences = await _repository.loadSyncPreferences();
    final journalBootstrapped = await _repository.isSyncJournalBootstrapped();
    if (!journalBootstrapped) {
      await _bootstrapSyncJournal();
      await _repository.markSyncJournalBootstrapped();
    }
    journalEntryCount = await _repository.countJournalEntries();
    recentChanges = await _repository.loadRecentChanges(limit: 20);
    syncCursors = await _repository.loadSyncCursors();
    if (_automaticLanSyncEnabled &&
        ready &&
        _autoSyncNode == null &&
        syncPreferences.discoverOnLocalNetwork &&
        trustedDevices.isNotEmpty) {
      unawaited(_restartAutomaticLanSync());
    }
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _bootstrapSyncJournal() async {
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

  Future<SyncJournalBatch> buildOutgoingSyncBatch({
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

  Future<SyncApplyResult> applyIncomingSyncChanges(
    List<ChangeRecord> changes,
  ) async {
    final result = await _repository.applyRemoteChanges(changes);
    if (result.insertedCount == 0) {
      return result;
    }

    data = await _repository.load();
    await rebuildAllNoteLinks(notify: false);
    await refreshSyncFoundation(notify: false);
    if (result.changedData) {
      _scheduleVaultMirror();
    }
    notifyListeners();
    return result;
  }

  Future<LanSyncHostSession> startLanSyncHost(String peerDeviceId) {
    return lanSyncService.startHost(
      peerDeviceId: peerDeviceId,
      onRemoteApplied: (_) => refreshAfterLanSync(),
    );
  }

  Future<LanSyncReport> syncFromLanOffer(
    String rawOffer, {
    required String expectedPeerDeviceId,
  }) async {
    if (lanSyncBusy) {
      throw StateError('Синхронизация уже выполняется.');
    }
    lanSyncBusy = true;
    lanSyncPeerDeviceId = expectedPeerDeviceId;
    notifyListeners();
    await _recordReliability(
      stage: ReliabilityStage.connection,
      level: ReliabilityLevel.info,
      message: 'Запущена ручная LAN-синхронизация по одноразовому коду.',
      peerDeviceId: expectedPeerDeviceId,
      notify: false,
    );
    try {
      final report = await lanSyncService.syncFromOffer(
        rawOffer,
        expectedPeerDeviceId: expectedPeerDeviceId,
        onRemoteApplied: (_) => refreshAfterLanSync(),
      );
      await refreshAfterLanSync(report: report);
      await _recordSyncSuccess(
        report,
        peerDeviceId: expectedPeerDeviceId,
        automatic: false,
      );
      return report;
    } on Object catch (error) {
      await _recordReliability(
        stage: ReliabilityStage.connection,
        level: ReliabilityLevel.error,
        message: 'Ручная LAN-синхронизация не выполнена.',
        peerDeviceId: expectedPeerDeviceId,
        details: <String, Object?>{'error': _friendlyLanError(error)},
        notify: false,
      );
      rethrow;
    } finally {
      lanSyncBusy = false;
      lanSyncPeerDeviceId = null;
      notifyListeners();
    }
  }

  Future<void> refreshAfterLanSync({LanSyncReport? report}) async {
    if (report != null) {
      lastLanSyncReport = report;
    }
    data = await _repository.load();
    await rebuildAllNoteLinks(notify: false);
    await refreshSyncFoundation(notify: false);
    if (report?.changedData ?? false) {
      _scheduleVaultMirror();
    }
    notifyListeners();
  }

  bool isLanPeerOnline(String deviceId) {
    final peer = _lanPeers[deviceId];
    return peer != null && peer.isOnlineAt(DateTime.now());
  }

  String? lanPeerEndpoint(String deviceId) => _lanPeers[deviceId]?.endpoint;

  String? lanPeerError(String deviceId) => _lanPeerErrors[deviceId];

  Future<void> handleAppResumed() async {
    if (!_automaticLanSyncEnabled || loadError != null || !ready) {
      return;
    }
    final node = _autoSyncNode;
    if (node == null) {
      await _restartAutomaticLanSync();
      return;
    }
    await node.announceNow();
  }

  Future<void> refreshLanDiscovery() async {
    final node = _autoSyncNode;
    if (node == null) {
      await _restartAutomaticLanSync();
      return;
    }
    lanDiscoveryStatus = 'Ищем доверенные устройства…';
    lanAutoSyncError = null;
    notifyListeners();
    await node.announceNow();
  }

  Future<LanSyncReport> syncWithTrustedDevice(String peerDeviceId) async {
    final discovered = _lanPeers[peerDeviceId];
    if (discovered == null || !discovered.isOnlineAt(DateTime.now())) {
      throw StateError(
        'Устройство не найдено в локальной сети. Открой Chronicle на обоих '
        'устройствах, проверь общий Wi-Fi и доступ VPN к локальной сети.',
      );
    }
    return _syncDiscoveredPeer(discovered, automatic: false);
  }

  Future<void> _restartAutomaticLanSync() async {
    await _stopAutomaticLanSync(notify: false);
    if (!_automaticLanSyncEnabled ||
        kIsWeb ||
        loadError != null ||
        !ready ||
        !syncPreferences.discoverOnLocalNetwork ||
        trustedDevices.isEmpty) {
      lanDiscoveryActive = false;
      lanDiscoveryStatus =
          trustedDevices.isEmpty
              ? 'Сначала подключи доверенное устройство'
              : 'Обнаружение в локальной сети выключено';
      notifyListeners();
      return;
    }

    await _recordReliability(
      stage: ReliabilityStage.discovery,
      level: ReliabilityLevel.info,
      message: 'Запуск обнаружения доверенных устройств в локальной сети.',
      notify: false,
    );
    try {
      final node = await autoSyncService.start(
        onRemoteApplied: (_) => refreshAfterLanSync(),
      );
      _autoSyncNode = node;
      _autoSyncPeerSubscription = node.peers.listen(
        _rememberDiscoveredPeer,
        onError: (Object error) {
          lanAutoSyncError = error.toString();
          lanDiscoveryStatus = 'Ошибка обнаружения';
          unawaited(
            _recordReliability(
              stage: ReliabilityStage.discovery,
              level: ReliabilityLevel.error,
              message: 'Ошибка потока локального обнаружения.',
              details: <String, Object?>{'error': _friendlyLanError(error)},
              notify: false,
            ),
          );
          notifyListeners();
        },
      );
      _autoSyncHostReportSubscription = node.reports.listen((report) {
        unawaited(refreshAfterLanSync(report: report));
      });
      _lanPresenceTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _expireLanPeers(),
      );
      lanDiscoveryActive = true;
      lanDiscoveryStatus = 'Ищем доверенные устройства…';
      lanAutoSyncError = null;
      notifyListeners();
      await node.announceNow();
      await _recordReliability(
        stage: ReliabilityStage.discovery,
        level: ReliabilityLevel.success,
        message: 'Локальное обнаружение запущено.',
        details: <String, Object?>{'udpPort': 45891},
        notify: false,
      );
    } on Object catch (error) {
      lanDiscoveryActive = false;
      lanDiscoveryStatus = 'Не удалось запустить обнаружение';
      lanAutoSyncError = _friendlyLanError(error);
      await _recordReliability(
        stage: ReliabilityStage.discovery,
        level: ReliabilityLevel.error,
        message: 'Не удалось запустить локальное обнаружение.',
        details: <String, Object?>{'error': lanAutoSyncError},
        notify: false,
      );
      notifyListeners();
    }
  }

  void _rememberDiscoveredPeer(LanDiscoveredPeer peer) {
    final trusted = trustedDevices.where(
      (device) => device.deviceId == peer.peer.deviceId && device.isActive,
    );
    if (trusted.isEmpty) {
      return;
    }
    final previous = _lanPeers[peer.peer.deviceId];
    final now = DateTime.now();
    final wasOnline = previous?.isOnlineAt(now) ?? false;
    final endpointChanged = previous?.endpoint != peer.endpoint;
    _lanPeers[peer.peer.deviceId] = peer;
    _lanPeerErrors.remove(peer.peer.deviceId);
    lanDiscoveryStatus = 'Доверенное устройство найдено';
    if (!wasOnline || endpointChanged) {
      unawaited(
        _recordReliability(
          stage: ReliabilityStage.discovery,
          level: ReliabilityLevel.success,
          message: 'Доверенное устройство обнаружено в локальной сети.',
          peerDeviceId: peer.peer.deviceId,
          details: <String, Object?>{'endpoint': peer.endpoint},
          notify: false,
        ),
      );
      notifyListeners();
    }
    _maybeAutoSync(peer);
  }

  void _maybeAutoSync(LanDiscoveredPeer peer) {
    if (!syncPreferences.autoSyncEnabled || lanSyncBusy) {
      return;
    }
    final identity = deviceIdentity;
    if (identity == null ||
        identity.deviceId.compareTo(peer.peer.deviceId) >= 0) {
      return;
    }
    TrustedDevice? trusted;
    for (final device in trustedDevices) {
      if (device.deviceId == peer.peer.deviceId) {
        trusted = device;
        break;
      }
    }
    if (trusted == null || !trusted.autoSyncEnabled) {
      return;
    }
    final now = DateTime.now();
    final lastAttempt = _lastAutoSyncAttempt[peer.peer.deviceId];
    if (lastAttempt != null &&
        now.difference(lastAttempt) < const Duration(seconds: 20)) {
      return;
    }
    _lastAutoSyncAttempt[peer.peer.deviceId] = now;
    unawaited(_runAutomaticSync(peer));
  }

  Future<void> _runAutomaticSync(LanDiscoveredPeer peer) async {
    try {
      await _syncDiscoveredPeer(peer, automatic: true);
    } on Object {
      // The error is stored for the devices screen. Automatic retries are
      // driven by later discovery announcements.
    }
  }

  Future<LanSyncReport> _syncDiscoveredPeer(
    LanDiscoveredPeer peer, {
    required bool automatic,
  }) async {
    if (lanSyncBusy) {
      throw StateError('Синхронизация уже выполняется.');
    }
    final node = _autoSyncNode;
    if (node == null) {
      throw StateError('Обнаружение в локальной сети ещё не запущено.');
    }

    lanSyncBusy = true;
    lanSyncPeerDeviceId = peer.peer.deviceId;
    lanAutoSyncError = null;
    _lanPeerErrors.remove(peer.peer.deviceId);
    lanDiscoveryStatus =
        automatic ? 'Автоматическая синхронизация…' : 'Синхронизация…';
    notifyListeners();
    await _recordReliability(
      stage: ReliabilityStage.connection,
      level: ReliabilityLevel.info,
      message:
          automatic
              ? 'Запущена автоматическая LAN-синхронизация.'
              : 'Запущена LAN-синхронизация без QR-кода.',
      peerDeviceId: peer.peer.deviceId,
      details: <String, Object?>{'endpoint': peer.endpoint},
      notify: false,
    );
    try {
      final report = await autoSyncService.syncWithDiscoveredPeer(
        node: node,
        discoveredPeer: peer,
        onRemoteApplied: (_) => refreshAfterLanSync(),
      );
      await refreshAfterLanSync(report: report);
      lanDiscoveryStatus = 'Синхронизация завершена';
      await _recordSyncSuccess(
        report,
        peerDeviceId: peer.peer.deviceId,
        automatic: automatic,
      );
      return report;
    } on Object catch (error) {
      final message = _friendlyLanError(error);
      lanAutoSyncError = message;
      _lanPeerErrors[peer.peer.deviceId] = message;
      lanDiscoveryStatus = 'Синхронизация не выполнена';
      await _recordReliability(
        stage: ReliabilityStage.connection,
        level: ReliabilityLevel.error,
        message:
            automatic
                ? 'Автоматическая LAN-синхронизация не выполнена.'
                : 'LAN-синхронизация без QR-кода не выполнена.',
        peerDeviceId: peer.peer.deviceId,
        details: <String, Object?>{'endpoint': peer.endpoint, 'error': message},
        notify: false,
      );
      rethrow;
    } finally {
      lanSyncBusy = false;
      lanSyncPeerDeviceId = null;
      notifyListeners();
    }
  }

  void _expireLanPeers() {
    final now = DateTime.now();
    final before = _lanPeers.length;
    _lanPeers.removeWhere(
      (_, peer) =>
          now.difference(peer.lastSeenAt) > const Duration(seconds: 20),
    );
    if (_lanPeers.length != before) {
      lanDiscoveryStatus =
          _lanPeers.isEmpty
              ? 'Доверенные устройства не найдены'
              : 'Доверенное устройство найдено';
      notifyListeners();
    }
  }

  Future<void> _stopAutomaticLanSync({bool notify = true}) async {
    _lanPresenceTimer?.cancel();
    _lanPresenceTimer = null;
    await _autoSyncPeerSubscription?.cancel();
    _autoSyncPeerSubscription = null;
    await _autoSyncHostReportSubscription?.cancel();
    _autoSyncHostReportSubscription = null;
    final node = _autoSyncNode;
    _autoSyncNode = null;
    if (node != null) {
      await node.close();
    }
    _lanPeers.clear();
    lanDiscoveryActive = false;
    if (notify) {
      notifyListeners();
    }
  }

  String _friendlyLanError(Object error) {
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

  Future<void> renameLocalDevice(String displayName) async {
    final identity = deviceIdentity ?? await _repository.ensureDeviceIdentity();
    final trimmed = displayName.trim();
    if (trimmed.isEmpty || trimmed == identity.displayName) {
      return;
    }
    identity.displayName = trimmed;
    await _repository.saveDeviceIdentity(identity);
    deviceIdentity = identity;
    notifyListeners();
  }

  Future<void> updateSyncPreferences(SyncPreferences preferences) async {
    final discoveryChanged =
        syncPreferences.discoverOnLocalNetwork !=
        preferences.discoverOnLocalNetwork;
    syncPreferences = preferences;
    await _repository.saveSyncPreferences(preferences);
    notifyListeners();
    if (discoveryChanged && _automaticLanSyncEnabled) {
      unawaited(_restartAutomaticLanSync());
    } else if (preferences.autoSyncEnabled) {
      unawaited(_autoSyncNode?.announceNow());
    }
  }

  Future<void> revokeTrustedDevice(String deviceId) async {
    await _repository.revokeTrustedDevice(deviceId, DateTime.now());
    _lanPeers.remove(deviceId);
    _lanPeerErrors.remove(deviceId);
    await refreshSyncFoundation();
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

  Future<void> _initializeVaultFoundation() async {
    try {
      vaultStatus = await _vaultService.inspect();
      if (vaultStatus.supported) {
        vaultStatus = await _vaultService.writeMirror(data);
        pendingVaultScan = await _vaultService.scan(data);
        _mergeVaultScanIntoStatus();
      }
    } on Object catch (error) {
      vaultStatus = VaultStatus.unavailable(message: error.toString());
      pendingVaultScan = null;
    }
  }

  Future<void> refreshVaultStatus({bool notify = true}) async {
    try {
      vaultStatus = await _vaultService.inspect();
      if (vaultStatus.supported) {
        pendingVaultScan = await _vaultService.scan(data);
        _mergeVaultScanIntoStatus();
      }
    } on Object catch (error) {
      vaultStatus = VaultStatus.unavailable(message: error.toString());
      pendingVaultScan = null;
    }
    if (notify) {
      notifyListeners();
    }
  }

  Future<VaultScanResult> scanVaultChanges({bool notify = true}) async {
    final scan = await _vaultService.scan(data);
    pendingVaultScan = scan;
    _mergeVaultScanIntoStatus();
    if (notify) {
      notifyListeners();
    }
    return scan;
  }

  void _mergeVaultScanIntoStatus() {
    final scan = pendingVaultScan;
    if (scan == null) {
      return;
    }
    vaultStatus = vaultStatus.copyWith(
      pendingChangeCount: scan.pendingCount,
      conflictCount: scan.conflicts.length,
      missingFileCount: scan.missingFiles.length,
      message:
          scan.hasChanges
              ? 'Найдены внешние изменения. Просмотри их перед импортом.'
              : 'Chronicle и Markdown Vault синхронизированы.',
    );
  }

  Future<void> writeVaultMirror() async {
    if (vaultBusy) {
      return;
    }
    vaultBusy = true;
    notifyListeners();
    try {
      vaultStatus = await _vaultService.writeMirror(data);
      pendingVaultScan = await _vaultService.scan(data);
      _mergeVaultScanIntoStatus();
    } finally {
      vaultBusy = false;
      notifyListeners();
    }
  }

  Future<bool> chooseVaultFolder() async {
    if (vaultBusy) {
      return false;
    }
    vaultBusy = true;
    notifyListeners();
    try {
      final result = await _vaultService.chooseRootAndWrite(data);
      if (result == null) {
        return false;
      }
      vaultStatus = result;
      pendingVaultScan = await _vaultService.scan(data);
      _mergeVaultScanIntoStatus();
      return true;
    } finally {
      vaultBusy = false;
      notifyListeners();
    }
  }

  Future<AttachmentImportResult?> pickAttachmentForNote(Note note) {
    return _vaultService.pickAndStoreAttachment(note);
  }

  Future<VaultApplyResult> applyVaultChanges(
    VaultScanResult scan, {
    required VaultConflictResolution conflictResolution,
    VaultMissingFileResolution missingFileResolution =
        VaultMissingFileResolution.restoreFiles,
  }) async {
    if (vaultBusy) {
      throw StateError('Vault уже занят другой операцией.');
    }
    vaultBusy = true;
    notifyListeners();

    var createdCount = 0;
    var updatedCount = 0;
    var duplicatedCount = 0;
    var keptChronicleCount = 0;
    var deletedCount = 0;
    String? safetyBackupPath;

    try {
      if (missingFileResolution == VaultMissingFileResolution.deleteNotes &&
          scan.missingFiles.isNotEmpty) {
        final snapshot = await _vaultService.createEmergencyBackupSnapshot(
          data: data,
          identity: deviceIdentity,
        );
        safetyBackupPath = snapshot.path;
        lastEmergencyBackupPath = snapshot.path;
      }
      for (final change in scan.safeChanges) {
        if (change.isNew || noteById(change.currentNoteId ?? '') == null) {
          await _createNoteFromVault(change.proposedNote);
          createdCount++;
        } else {
          await _overwriteNoteFromVault(
            noteById(change.currentNoteId!)!,
            change.proposedNote,
          );
          updatedCount++;
        }
      }

      for (final conflict in scan.conflicts) {
        final current = noteById(conflict.currentNoteId ?? '');
        if (current == null) {
          await _createNoteFromVault(conflict.proposedNote);
          createdCount++;
          continue;
        }
        switch (conflictResolution) {
          case VaultConflictResolution.keepChronicle:
            keptChronicleCount++;
            break;
          case VaultConflictResolution.importFile:
            await _overwriteNoteFromVault(current, conflict.proposedNote);
            updatedCount++;
            break;
          case VaultConflictResolution.keepBoth:
            await _createNoteFromVault(
              conflict.proposedNote,
              forceNewId: true,
              titleSuffix: ' (версия Vault)',
            );
            duplicatedCount++;
            break;
        }
      }

      if (missingFileResolution == VaultMissingFileResolution.deleteNotes) {
        for (final missing in scan.missingFiles) {
          if (noteById(missing.noteId) == null) {
            continue;
          }
          await _deleteNoteFromVault(missing.noteId);
          deletedCount++;
        }
      }

      await rebuildAllNoteLinks();
      await refreshSyncFoundation(notify: false);
      vaultStatus = await _vaultService.rewriteAfterApply(data, scan);
      pendingVaultScan = await _vaultService.scan(data);
      _mergeVaultScanIntoStatus();

      return VaultApplyResult(
        createdCount: createdCount,
        updatedCount: updatedCount,
        duplicatedCount: duplicatedCount,
        keptChronicleCount: keptChronicleCount,
        restoredFileCount:
            missingFileResolution == VaultMissingFileResolution.restoreFiles
                ? scan.missingFiles.length
                : 0,
        deletedCount: deletedCount,
        safetyBackupPath: safetyBackupPath,
      );
    } finally {
      vaultBusy = false;
      notifyListeners();
    }
  }

  Future<void> _createNoteFromVault(
    Note source, {
    bool forceNewId = false,
    String titleSuffix = '',
  }) async {
    if (data.projects.isEmpty) {
      throw StateError('Сначала создай хотя бы один проект.');
    }
    final projectId =
        data.projects.any((project) => project.id == source.projectId)
            ? source.projectId
            : data.projects.first.id;
    final imported = Note(
      id: forceNewId || noteById(source.id) != null ? _uuid.v4() : source.id,
      title: '${source.title}$titleSuffix',
      projectId: projectId,
      body: '',
      tags: List<String>.from(source.tags),
      status: source.status,
      folderPath: source.folderPath,
      noteType: source.noteType,
      properties: Map<String, String>.from(source.properties),
      pinned: source.pinned,
      revision: source.revision < 1 ? 1 : source.revision,
      createdAt: source.createdAt,
      updatedAt: DateTime.now(),
    );
    imported.body = NoteDocument.serialize(
      imported,
      NoteDocument.parse(source.body).content,
    );
    data.notes.add(imported);
    await _repository.saveNote(imported);
  }

  Future<void> _deleteNoteFromVault(String noteId) async {
    final deletedAt = DateTime.now();
    final noteIndex = data.notes.indexWhere((note) => note.id == noteId);
    if (noteIndex < 0) {
      return;
    }

    data.notes.removeAt(noteIndex);
    data.noteLinks.removeWhere(
      (link) => link.sourceNoteId == noteId || link.targetNoteId == noteId,
    );
    for (final task in data.tasks.where((task) => task.noteId == noteId)) {
      task.noteId = null;
      task.updatedAt = deletedAt;
      await _repository.saveTask(task);
    }
    await _repository.replaceNoteLinks(noteId, const []);
    await _repository.softDeleteNote(noteId, deletedAt);
  }

  Future<void> _overwriteNoteFromVault(Note current, Note source) async {
    final version = NoteVersion(
      id: _uuid.v4(),
      noteId: current.id,
      title: current.title,
      body: current.body,
      tags: List<String>.from(current.tags),
      status: current.status,
      folderPath: current.folderPath,
      noteType: current.noteType,
      properties: Map<String, String>.from(current.properties),
      reason: 'Перед импортом из Markdown Vault',
    );
    data.noteVersions.insert(0, version);
    await _repository.saveNoteVersion(version);

    current.title = source.title;
    current.projectId =
        data.projects.any((project) => project.id == source.projectId)
            ? source.projectId
            : current.projectId;
    current.tags = List<String>.from(source.tags);
    current.status = source.status;
    current.folderPath = source.folderPath;
    current.noteType = source.noteType;
    current.properties = Map<String, String>.from(source.properties);
    current.pinned = source.pinned;
    current.revision += 1;
    current.updatedAt = DateTime.now();
    current.body = NoteDocument.serialize(
      current,
      NoteDocument.parse(source.body).content,
    );
    await _repository.saveNote(current);
  }

  void _scheduleVaultMirror() {
    _vaultMirrorDebounce?.cancel();
    _vaultMirrorDebounce = Timer(const Duration(milliseconds: 700), () {
      unawaited(writeVaultMirror());
    });
  }

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

  Future<void> _recordSyncSuccess(
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
        'durationMs':
            report.completedAt.difference(report.startedAt).inMilliseconds,
      },
      notify: false,
    );
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
          'appVersion': '0.18.1+26',
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
          'deviceId': deviceIdentity?.deviceId,
          'deviceName': deviceIdentity?.displayName,
          'trustedDeviceCount': trustedDevices.length,
          'journalEntryCount': journalEntryCount,
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

  Future<void> restoreBackupFile(BackupImportPayload payload) async {
    if (vaultBusy) {
      return;
    }
    vaultBusy = true;
    lastRestoreRolledBack = false;
    notifyListeners();
    EmergencyBackupSnapshot? emergencySnapshot;
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
        notify: false,
      );
      final snapshot = await _vaultService.createEmergencyBackupSnapshot(
        data: data,
        identity: deviceIdentity,
      );
      emergencySnapshot = snapshot;
      lastEmergencyBackupPath = snapshot.path;

      try {
        await _applyBackupPayload(payload);
      } on Object catch (restoreError, restoreStack) {
        try {
          await _applyBackupPayload(snapshot.payload);
          lastRestoreRolledBack = true;
          await _recordReliability(
            stage: ReliabilityStage.restore,
            level: ReliabilityLevel.warning,
            message:
                'Восстановление прервано; исходные данные автоматически возвращены.',
            details: <String, Object?>{
              'sourceName': payload.sourceName,
              'error': restoreError.toString(),
              'emergencyBackupPath': snapshot.path,
            },
            notify: false,
          );
        } on Object catch (rollbackError, rollbackStack) {
          await _recordReliability(
            stage: ReliabilityStage.restore,
            level: ReliabilityLevel.error,
            message:
                'Восстановление и автоматический откат завершились ошибкой.',
            details: <String, Object?>{
              'restoreError': restoreError.toString(),
              'rollbackError': rollbackError.toString(),
              'emergencyBackupPath': snapshot.path,
            },
            notify: false,
          );
          Error.throwWithStackTrace(
            StateError(
              'Не удалось восстановить копию и автоматически вернуть '
              'предыдущее состояние. Аварийная копия сохранена: '
              '${snapshot.path}',
            ),
            rollbackStack,
          );
        }
        Error.throwWithStackTrace(restoreError, restoreStack);
      }

      await refreshBackupCatalog(notify: false);
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
        notify: false,
      );
    } on Object catch (error) {
      await _recordReliability(
        stage: ReliabilityStage.restore,
        level: ReliabilityLevel.error,
        message: 'Восстановление резервной копии не выполнено.',
        details: <String, Object?>{
          'error': error.toString(),
          'rolledBack': lastRestoreRolledBack,
          'emergencyBackupPath': emergencySnapshot?.path,
        },
        notify: false,
      );
      rethrow;
    } finally {
      vaultBusy = false;
      notifyListeners();
    }
  }

  Future<void> _applyBackupPayload(BackupImportPayload payload) async {
    await _replaceDataFromBackup(payload.databaseJson);
    await _vaultService.replaceAttachments(payload);
    vaultStatus = await _vaultService.writeMirror(data, force: true);
    pendingVaultScan = await _vaultService.scan(data);
    _mergeVaultScanIntoStatus();
    await refreshSyncFoundation(notify: false);
  }

  Future<String> exportBackupJson() => _repository.exportJson();

  Future<void> importBackupJson(String raw) async {
    await _replaceDataFromBackup(raw);
    _scheduleVaultMirror();
    notifyListeners();
  }

  Future<void> _replaceDataFromBackup(String raw) async {
    _ticker?.cancel();
    activeStartedAt = null;
    activeDescription = '';
    activeProjectId = null;
    activeTaskId = null;
    activeNoteId = null;
    await _repository.saveActiveTimer(null);
    await _repository.importJson(raw);
    data = await _repository.load();
    await _hydrateNoteMetadata();
    await rebuildAllNoteLinks();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      nowTick++;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _syncRefreshDebounce?.cancel();
    _vaultMirrorDebounce?.cancel();
    _lanPresenceTimer?.cancel();
    unawaited(_autoSyncPeerSubscription?.cancel());
    unawaited(_autoSyncHostReportSubscription?.cancel());
    final node = _autoSyncNode;
    if (node != null) {
      unawaited(node.close());
    }
    unawaited(_repository.close());
    super.dispose();
  }
}
