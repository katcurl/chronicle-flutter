import 'dart:async' as async;

import 'package:uuid/uuid.dart';

import '../../data/repositories/app_repository.dart';
import '../../data/repositories/mutation_queue.dart';
import '../../features/timer/timer_duration.dart';
import '../../models/app_models.dart';

typedef TimerEntries = List<TimeEntry> Function();
typedef TimerClock = DateTime Function();

final class TimerService {
  TimerService({
    required AppRepository repository,
    required MutationQueue mutationQueue,
    required TimerEntries entries,
    required void Function() onStateChanged,
    required void Function() onEntrySaved,
    TimerClock? now,
    Uuid uuid = const Uuid(),
  }) : _repository = repository,
       _mutationQueue = mutationQueue,
       _entries = entries,
       _onStateChanged = onStateChanged,
       _onEntrySaved = onEntrySaved,
       _now = now ?? DateTime.now,
       _uuid = uuid;

  final AppRepository _repository;
  final MutationQueue _mutationQueue;
  final TimerEntries _entries;
  final void Function() _onStateChanged;
  final void Function() _onEntrySaved;
  final TimerClock _now;
  final Uuid _uuid;
  async.Timer? _ticker;

  DateTime? activeStartedAt;
  String activeDescription = '';
  String? activeProjectId;
  String? activeTaskId;
  String? activeNoteId;

  int get activeSeconds {
    final startedAt = activeStartedAt;
    return startedAt == null
        ? 0
        : elapsedTimerSeconds(startedAt: startedAt, endedAt: _now());
  }

  int get todaySeconds {
    final now = _now();
    final saved = _entries().fold<int>(
      0,
      (sum, entry) =>
          sum +
          secondsWithinDay(
            startedAt: entry.startedAt,
            durationSeconds: entry.durationSeconds,
            day: now,
          ),
    );
    final active = activeStartedAt;
    return saved +
        (active == null
            ? 0
            : secondsWithinDay(
              startedAt: active,
              durationSeconds: activeSeconds,
              day: now,
            ));
  }

  void hydrate(ActiveTimerState? timer) {
    _ticker?.cancel();
    activeStartedAt = timer?.startedAt;
    activeDescription = timer?.description ?? '';
    activeProjectId = timer?.projectId;
    activeTaskId = timer?.taskId;
    activeNoteId = timer?.noteId;
    if (timer != null) {
      _startTicker();
    }
  }

  Future<void> start({
    required String description,
    required String projectId,
    String? taskId,
    String? noteId,
  }) {
    return _mutationQueue.run(
      () => _startMutation(
        description: description,
        projectId: projectId,
        taskId: taskId,
        noteId: noteId,
      ),
    );
  }

  Future<void> stop() => _mutationQueue.run(_stopMutation);

  Future<void> _startMutation({
    required String description,
    required String projectId,
    String? taskId,
    String? noteId,
  }) async {
    if (activeStartedAt != null) {
      await _stopMutation();
    }
    final startedAt = _now();
    await _repository.saveActiveTimer(
      ActiveTimerState(
        startedAt: startedAt,
        description: description,
        projectId: projectId,
        taskId: taskId,
        noteId: noteId,
      ),
    );
    activeStartedAt = startedAt;
    activeDescription = description;
    activeProjectId = projectId;
    activeTaskId = taskId;
    activeNoteId = noteId;
    _startTicker();
    _onStateChanged();
  }

  Future<void> _stopMutation() async {
    final startedAt = activeStartedAt;
    final projectId = activeProjectId;
    if (startedAt == null || projectId == null) return;

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
      durationSeconds: elapsedTimerSeconds(
        startedAt: startedAt,
        endedAt: _now(),
      ),
    );
    await _repository.appendTimeEntryAndClearTimer(entry);

    _entries().insert(0, entry);
    activeStartedAt = null;
    activeDescription = '';
    activeProjectId = null;
    activeTaskId = null;
    activeNoteId = null;
    _ticker?.cancel();
    _onEntrySaved();
    _onStateChanged();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = async.Timer.periodic(
      const Duration(seconds: 1),
      (_) => _onStateChanged(),
    );
  }

  void dispose() {
    _ticker?.cancel();
  }
}
