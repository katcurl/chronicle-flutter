import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/migration/legacy_preferences_importer.dart';
import '../data/repositories/app_repository.dart';
import '../data/repositories/drift_app_repository.dart';
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
import '../sync/lan_auto_sync_models.dart';
import '../sync/lan_auto_sync_service.dart';
import '../sync/lan_auto_sync_transport.dart';
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
    ReliabilityService? reliabilityService,
    CustomNoteTemplateStore? customNoteTemplateStore,
    bool enableAutomaticLanSync = false,
    bool enableReliabilityFeatures = false,
  }) : _repository = repository,
       _legacyImporter = legacyImporter,
       _vaultService = vaultService ?? VaultService(),
       _reliabilityService = reliabilityService ?? ReliabilityService(),
       _customNoteTemplateStore = customNoteTemplateStore,
       pairingService =
           pairingService ?? PairingService(repository: repository),
       _automaticLanSyncEnabled = enableAutomaticLanSync,
       _reliabilityFeaturesEnabled = enableReliabilityFeatures {
    this.lanSyncService =
        lanSyncService ??
        LanSyncService(
          repository: repository,
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
  }

  factory AppStore.production() => AppStore(
    repository: DriftAppRepository(),
    legacyImporter: LegacyPreferencesImporter(),
    customNoteTemplateStore: CustomNoteTemplateStore(),
    enableAutomaticLanSync: true,
    enableReliabilityFeatures: true,
  );

  final AppRepository _repository;
  final LegacyPreferencesImporter? _legacyImporter;
  final VaultService _vaultService;
  final ReliabilityService _reliabilityService;
  final CustomNoteTemplateStore? _customNoteTemplateStore;
  final PairingService pairingService;
  late final LanSyncService lanSyncService;
  final bool _automaticLanSyncEnabled;
  final bool _reliabilityFeaturesEnabled;
  late final LanAutoSyncService autoSyncService;
  final _uuid = const Uuid();
  final ChronicleUndoJournal _undoJournal = ChronicleUndoJournal();
  final ValueNotifier<int> _attachmentRefreshNotifier =
      ValueNotifier<int>(0);

  ValueListenable<int> get attachmentRefreshListenable =>
      _attachmentRefreshNotifier;

  AppData data = AppData.empty();
  List<NoteTemplate> customNoteTemplates = const <NoteTemplate>[];
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

  ReleaseReadinessReport? releaseReadinessReport;
  bool releaseReadinessBusy = false;
  String? releaseReadinessError;

  bool get canUndo => _undoJournal.canUndo;
  int get undoDepth => _undoJournal.length;
  String? get nextUndoLabel => _undoJournal.nextLabel;

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
      var protectExistingVault = false;
      if (!initialized) {
        final legacy = await _legacyImporter?.read();
        final vaultHasNotes = await _vaultService.hasExistingNoteContent();
        protectExistingVault = vaultHasNotes;
        data = legacy ?? AppData.empty();
        await _repository.replaceAll(data);
        await _repository.markInitialized();
      } else {
        data = await _repository.load();
      }

      await _loadCustomNoteTemplates();
      await _hydrateNoteMetadata();
      await rebuildAllNoteLinks();
      await refreshSyncFoundation(notify: false);
      await _initializeVaultFoundation(
        allowAutomaticWrite: !protectExistingVault,
      );
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
    if (customNoteTemplates.length >= CustomNoteTemplateStore.maxTemplateCount) {
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
    final index = customNoteTemplates.indexWhere((template) => template.id == id);
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
    final index = customNoteTemplates.indexWhere((template) => template.id == id);
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
    final remaining = CustomNoteTemplateStore.maxTemplateCount -
        customNoteTemplates.length;
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
      final source = normalized.length <= maxSourceLength
          ? normalized
          : normalized.substring(0, maxSourceLength).trimRight();
      final candidate = '$prefix$source';
      final exists = customNoteTemplates.any(
        (template) => template.title.trim().toLowerCase() ==
            candidate.toLowerCase(),
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
      candidates = candidates.where((note) {
        final project = projectById(note.projectId);
        return project?.title.trim().toLowerCase() == projectName;
      }).toList(growable: false);
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
    return data.noteLinks.where((link) {
      if (link.targetNoteId != null) {
        return link.targetNoteId == note.id;
      }
      final source = noteById(link.sourceNoteId);
      return resolveWikiTarget(link.targetTitle, source: source)?.id == note.id;
    }).toList(growable: false);
  }

  NoteWikiRenamePlan buildWikiRenamePlan(Note note, String newTitle) {
    return NoteWikiRenamePlanner.build(
      target: note,
      newTitle: newTitle,
      notes: data.notes,
      resolveTarget:
          (source, rawTarget) =>
              resolveWikiTarget(rawTarget, source: source),
      targetCandidates:
          (source, rawTarget) =>
              notesForWikiTarget(rawTarget, source: source),
    );
  }

  List<NoteWikiLinkIssue> wikiLinkIssues() {
    return NoteWikiRenamePlanner.findIssues(
      notes: data.notes,
      resolveTarget:
          (source, rawTarget) =>
              resolveWikiTarget(rawTarget, source: source),
      targetCandidates:
          (source, rawTarget) =>
              notesForWikiTarget(rawTarget, source: source),
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
    for (final reference in NoteWikiLinkSyntax.all(parsed.content).toList().reversed) {
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

    data.tasks.removeAt(index);
    for (final child in data.tasks.where((task) => task.parentTaskId == id)) {
      child.parentTaskId = null;
      child.updatedAt = deletedAt;
      await _repository.saveTask(child);
    }
    await _repository.softDeleteTask(id, deletedAt);
    _registerUndo(
      label: 'Удаление задачи «${removed.title}»',
      restore: () async {
        final restored = _cloneTask(removed)..deletedAt = null;
        await _repository.restoreTask(restored.id);
        await _repository.saveTask(restored);
        data.tasks.removeWhere((task) => task.id == restored.id);
        data.tasks.insert(
          index.clamp(0, data.tasks.length).toInt(),
          restored,
        );
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
      label: archived
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
    final index = data.citationSources.indexWhere((item) => item.id == source.id);
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
    final keys = data.citationSources
        .map((source) => source.normalizedCitationKey)
        .toSet();
    final dois = data.citationSources
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

    data.notes.removeAt(noteIndex);
    data.noteLinks.removeWhere(
      (link) => link.sourceNoteId == id || link.targetNoteId == id,
    );
    for (final task in data.tasks.where((task) => task.noteId == id)) {
      task.noteId = null;
      task.updatedAt = deletedAt;
      await _repository.saveTask(task);
    }
    await _repository.replaceNoteLinks(id, const []);
    await _repository.softDeleteNote(id, deletedAt);
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
            message: 'Заметка восстановлена, но индекс связей требует перестроения.',
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
    LanSyncProgressCallback? onProgress,
    LanSyncCancellationToken? cancellationToken,
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
        onProgress: onProgress,
        cancellationToken: cancellationToken,
      );
      await refreshAfterLanSync(report: report);
      await _recordSyncSuccess(
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
        message: cancelled
            ? 'Ручная LAN-синхронизация отменена пользователем.'
            : 'Ручная LAN-синхронизация не выполнена.',
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
    _notifyAttachmentRefresh();
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

  Future<void> _initializeVaultFoundation({
    required bool allowAutomaticWrite,
  }) async {
    try {
      vaultStatus = await _vaultService.inspect();
      if (vaultStatus.supported) {
        pendingVaultScan = await _vaultService.scan(data);
        if (allowAutomaticWrite && !pendingVaultScan!.hasChanges) {
          vaultStatus = await _vaultService.writeMirror(data);
          pendingVaultScan = await _vaultService.scan(data);
        }
        _mergeVaultScanIntoStatus(
          messageOverride:
              !allowAutomaticWrite
                  ? pendingVaultScan!.hasChanges
                      ? 'Найдены данные Vault. Автоматическая запись отключена '
                          'до просмотра изменений.'
                      : 'Новая локальная база создана. Автоматическая запись '
                          'в Vault пропущена для защиты существующих файлов.'
                  : null,
        );
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

  void _mergeVaultScanIntoStatus({String? messageOverride}) {
    final scan = pendingVaultScan;
    if (scan == null) {
      return;
    }
    vaultStatus = vaultStatus.copyWith(
      pendingChangeCount: scan.pendingCount,
      conflictCount: scan.conflicts.length,
      missingFileCount: scan.missingFiles.length,
      message:
          messageOverride ??
          (scan.hasChanges
              ? 'Найдены внешние изменения. Просмотри их перед импортом.'
              : 'Chronicle и Markdown Vault синхронизированы.'),
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

  Future<Uint8List?> readManagedAttachment(String relativePath) {
    return _vaultService.readManagedAttachment(relativePath);
  }

  Future<AttachmentImportResult?> pickAttachmentForNote(Note note) async {
    final result = await _vaultService.pickAndStoreAttachment(note);
    if (result != null) {
      _notifyAttachmentRefresh();
    }
    return result;
  }

  Future<AttachmentImportResult> storeAttachmentBytesForNote(
    Note note, {
    required String fileName,
    required Uint8List bytes,
  }) async {
    final result = await _vaultService.storeAttachmentBytes(
      note: note,
      originalName: fileName,
      bytes: bytes,
    );
    _notifyAttachmentRefresh();
    return result;
  }

  Future<List<AttachmentImportResult>> storeAttachmentBatchForNote(
    Note note, {
    required List<String> fileNames,
    required List<Uint8List> fileBytes,
  }) async {
    if (fileNames.length != fileBytes.length) {
      throw ArgumentError('Количество имён и файлов должно совпадать.');
    }
    final results = <AttachmentImportResult>[];
    for (var index = 0; index < fileNames.length; index += 1) {
      results.add(
        await _vaultService.storeAttachmentBytes(
          note: note,
          originalName: fileNames[index],
          bytes: fileBytes[index],
        ),
      );
    }
    if (results.isNotEmpty) {
      _notifyAttachmentRefresh();
    }
    return List<AttachmentImportResult>.unmodifiable(results);
  }

  Future<VaultApplyResult> applyVaultChanges(
    VaultScanResult scan, {
    required VaultConflictResolution conflictResolution,
    Map<String, VaultConflictResolution> conflictResolutions = const {},
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
      final needsSafetyBackup =
          scan.conflicts.isNotEmpty ||
          (missingFileResolution == VaultMissingFileResolution.deleteNotes &&
              scan.missingFiles.isNotEmpty);
      if (needsSafetyBackup) {
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
        final resolution =
            conflictResolutions[conflict.decisionKey] ?? conflictResolution;
        switch (resolution) {
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
              titleSuffix: ' (конфликтная версия Vault)',
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
      _notifyAttachmentRefresh();

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
          'appVersion': chronicleStableVersion,
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
    _notifyAttachmentRefresh();
  }

  Future<String> exportBackupJson() => _repository.exportJson();

  Future<void> importBackupJson(String raw) async {
    await _replaceDataFromBackup(raw);
    _scheduleVaultMirror();
    notifyListeners();
  }

  Future<void> _replaceDataFromBackup(String raw) async {
    _undoJournal.clear();
    releaseReadinessReport = null;
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
      if (inspectedVault.supported &&
          inspectedVault.rootPath.isNotEmpty &&
          !inspectedVault.readOnly) {
        readinessScan = await _vaultService.scan(data);
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
        automaticBackupCount: automaticBackups
            .where((entry) => entry.isValid)
            .length,
        pendingConflictCount:
            readinessScan?.conflicts.length ?? vaultStatus.conflictCount,
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
        message: report.ready
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
    _undoJournal.push(
      ChronicleUndoEntry(label: label, restore: restore),
    );
  }

  Note _cloneNote(Note note) =>
      Note.fromJson(Map<String, dynamic>.from(note.toJson()));

  WorkTask _cloneTask(WorkTask task) =>
      WorkTask.fromJson(Map<String, dynamic>.from(task.toJson()));

  NoteLink _cloneNoteLink(NoteLink link) =>
      NoteLink.fromJson(Map<String, dynamic>.from(link.toJson()));

  CitationSource _cloneCitationSource(CitationSource source) =>
      CitationSource.fromJson(Map<String, dynamic>.from(source.toJson()));

  void _notifyAttachmentRefresh() {
    _attachmentRefreshNotifier.value += 1;
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
    _attachmentRefreshNotifier.dispose();
    super.dispose();
  }
}
