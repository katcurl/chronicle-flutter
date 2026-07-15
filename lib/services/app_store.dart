import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/migration/legacy_preferences_importer.dart';
import '../data/repositories/app_repository.dart';
import '../data/repositories/drift_app_repository.dart';
import '../features/notes/note_document.dart';
import '../models/app_models.dart';
import '../sync/sync_models.dart';
import '../vault/vault_models.dart';
import '../vault/vault_service.dart';

class AppStore extends ChangeNotifier {
  AppStore({
    required AppRepository repository,
    LegacyPreferencesImporter? legacyImporter,
    VaultService? vaultService,
  }) : _repository = repository,
       _legacyImporter = legacyImporter,
       _vaultService = vaultService ?? VaultService();

  factory AppStore.production() => AppStore(
    repository: DriftAppRepository(),
    legacyImporter: LegacyPreferencesImporter(),
  );

  final AppRepository _repository;
  final LegacyPreferencesImporter? _legacyImporter;
  final VaultService _vaultService;
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

  VaultStatus vaultStatus = const VaultStatus.unavailable();
  VaultScanResult? pendingVaultScan;
  bool vaultBusy = false;
  String? lastEmergencyBackupPath;

  DateTime? activeStartedAt;
  String activeDescription = '';
  String? activeProjectId;
  String? activeTaskId;
  String? activeNoteId;

  Timer? _ticker;
  Timer? _syncRefreshDebounce;
  Timer? _vaultMirrorDebounce;
  int nowTick = 0;

  Future<void> load() async {
    ready = false;
    loadError = null;
    notifyListeners();

    try {
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
    } catch (error) {
      loadError = error;
    } finally {
      ready = true;
      notifyListeners();
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

  Future<void> rebuildAllNoteLinks() async {
    for (final note in data.notes) {
      await _syncNoteLinks(note, notify: false);
    }
    notifyListeners();
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
    syncPreferences = preferences;
    await _repository.saveSyncPreferences(preferences);
    notifyListeners();
  }

  Future<void> revokeTrustedDevice(String deviceId) async {
    await _repository.revokeTrustedDevice(deviceId, DateTime.now());
    await refreshSyncFoundation();
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

    try {
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
        restoredFileCount: scan.missingFiles.length,
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

  Future<BackupExportResult?> exportBackupFile() async {
    if (vaultBusy) {
      return null;
    }
    vaultBusy = true;
    notifyListeners();
    try {
      vaultStatus = await _vaultService.writeMirror(data);
      return _vaultService.exportBackup(data: data, identity: deviceIdentity);
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
    notifyListeners();
    try {
      lastEmergencyBackupPath = await _vaultService.createEmergencyBackup(
        data: data,
        identity: deviceIdentity,
      );
      await _replaceDataFromBackup(payload.databaseJson);
      await _vaultService.restoreAttachments(payload);
      vaultStatus = await _vaultService.writeMirror(data, force: true);
      pendingVaultScan = await _vaultService.scan(data);
      _mergeVaultScanIntoStatus();
      await refreshSyncFoundation(notify: false);
    } finally {
      vaultBusy = false;
      notifyListeners();
    }
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
    unawaited(_repository.close());
    super.dispose();
  }
}
