import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/app_models.dart';

class AppStore extends ChangeNotifier {
  static const _key = 'chronicle_data_v5';
  final _uuid = const Uuid();

  late AppData data;
  bool ready = false;
  DateTime? activeStartedAt;
  String activeDescription = '';
  String? activeProjectId;
  String? activeTaskId;
  String? activeNoteId;
  Timer? _ticker;
  int nowTick = 0;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    data = raw == null ? _seed() : AppData.decode(raw);
    ready = true;
    notifyListeners();
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

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, data.encode());
  }

  void changed() {
    unawaited(save());
    notifyListeners();
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
    if (activeStartedAt != null) {
      stopTimer();
    }
    activeStartedAt = DateTime.now();
    activeDescription = description;
    activeProjectId = projectId;
    activeTaskId = taskId;
    activeNoteId = noteId;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      nowTick++;
      notifyListeners();
    });
    notifyListeners();
  }

  void stopTimer() {
    final startedAt = activeStartedAt;
    final projectId = activeProjectId;
    if (startedAt == null || projectId == null) return;

    final duration = DateTime.now().difference(startedAt).inSeconds;
    data.entries.insert(
      0,
      TimeEntry(
        id: _uuid.v4(),
        description: activeDescription.trim().isEmpty
            ? 'Рабочая сессия'
            : activeDescription.trim(),
        projectId: projectId,
        taskId: activeTaskId,
        noteId: activeNoteId,
        startedAt: startedAt,
        durationSeconds: duration,
      ),
    );

    activeStartedAt = null;
    activeDescription = '';
    activeProjectId = null;
    activeTaskId = null;
    activeNoteId = null;
    _ticker?.cancel();
    changed();
  }

  void addTask(WorkTask task) {
    data.tasks.insert(0, task);
    changed();
  }

  void addProject(Project project) {
    data.projects.add(project);
    changed();
  }

  void addNote(Note note) {
    data.notes.insert(0, note);
    changed();
  }

  void deleteNote(String id) {
    data.notes.removeWhere((note) => note.id == id);
    data.tasks.removeWhere((task) => task.noteId == id);
    changed();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
