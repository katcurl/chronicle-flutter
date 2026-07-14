import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/migration/legacy_preferences_importer.dart';
import '../data/repositories/app_repository.dart';
import '../data/repositories/sqlite_app_repository.dart';
import '../models/app_models.dart';

class AppStore extends ChangeNotifier {
  AppStore({
    required AppRepository repository,
    LegacyPreferencesImporter? legacyImporter,
  })  : _repository = repository,
        _legacyImporter = legacyImporter;

  factory AppStore.production() => AppStore(
        repository: SqliteAppRepository(),
        legacyImporter: LegacyPreferencesImporter(),
      );

  final AppRepository _repository;
  final LegacyPreferencesImporter? _legacyImporter;
  final _uuid = const Uuid();

  AppData data = AppData.empty();
  bool ready = false;
  Object? loadError;

  DateTime? activeStartedAt;
  String activeDescription = '';
  String? activeProjectId;
  String? activeTaskId;
  String? activeNoteId;

  Timer? _ticker;
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
      body: '# Журнал исследования Orf9b\n\n'
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

  int get activeSeconds => activeStartedAt == null
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
      description: activeDescription.trim().isEmpty
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
    notifyListeners();
  }

  void updateTaskStatus(WorkTask task, String status) {
    task.status = status;
    task.updatedAt = DateTime.now();
    task.completedAt = status == 'done' ? DateTime.now() : null;
    unawaited(_repository.saveTask(task));
    notifyListeners();
  }

  void addProject(Project project) {
    data.projects.add(project);
    unawaited(_repository.saveProject(project));
    notifyListeners();
  }

  void addNote(Note note) {
    data.notes.insert(0, note);
    unawaited(_repository.saveNote(note));
    notifyListeners();
  }

  void updateNote(Note note) {
    note.updatedAt = DateTime.now();
    unawaited(_repository.saveNote(note));
    notifyListeners();
  }

  void deleteNote(String id) {
    final deletedAt = DateTime.now();
    final noteIndex = data.notes.indexWhere((note) => note.id == id);
    if (noteIndex < 0) return;

    data.notes.removeAt(noteIndex);
    for (final task in data.tasks.where((task) => task.noteId == id)) {
      task.noteId = null;
      task.updatedAt = deletedAt;
      unawaited(_repository.saveTask(task));
    }
    unawaited(_repository.softDeleteNote(id, deletedAt));
    notifyListeners();
  }

  Future<String> exportBackupJson() => _repository.exportJson();

  Future<void> importBackupJson(String raw) async {
    _ticker?.cancel();
    activeStartedAt = null;
    activeDescription = '';
    activeProjectId = null;
    activeTaskId = null;
    activeNoteId = null;
    await _repository.saveActiveTimer(null);
    await _repository.importJson(raw);
    data = await _repository.load();
    notifyListeners();
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
    unawaited(_repository.close());
    super.dispose();
  }
}
