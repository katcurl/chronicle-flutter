import '../../data/repositories/app_repository.dart';
import '../../data/repositories/mutation_queue.dart';
import '../../features/references/citation_syntax.dart';
import '../../models/app_models.dart';

typedef RegisterTaskUndo =
    void Function({
      required String label,
      required Future<void> Function() restore,
    });

final class TaskCommands {
  TaskCommands({
    required AppRepository repository,
    required MutationQueue mutationQueue,
    required AppData Function() currentData,
    required RegisterTaskUndo registerUndo,
    required void Function() scheduleSync,
    required void Function() notifyListeners,
  }) : _repository = repository,
       _mutationQueue = mutationQueue,
       _currentData = currentData,
       _registerUndo = registerUndo,
       _scheduleSync = scheduleSync,
       _notifyListeners = notifyListeners;

  final AppRepository _repository;
  final MutationQueue _mutationQueue;
  final AppData Function() _currentData;
  final RegisterTaskUndo _registerUndo;
  final void Function() _scheduleSync;
  final void Function() _notifyListeners;

  List<Project> get activeProjects => _currentData().projects
      .where((project) => !project.archived)
      .toList(growable: false);

  List<Project> get archivedProjects => _currentData().projects
      .where((project) => project.archived)
      .toList(growable: false);

  Future<void> addTask(WorkTask task) {
    final persisted = _cloneTask(task);
    return _mutationQueue.run(() async {
      await _repository.saveTask(persisted);
      _currentData().tasks.insert(0, persisted);
      _publishSyncMutation();
    });
  }

  Future<void> updateTask(WorkTask task) {
    final persisted = _cloneTask(task)..updatedAt = DateTime.now();
    return _mutationQueue.run(() async {
      await _repository.saveTask(persisted);
      final data = _currentData();
      final index = data.tasks.indexWhere((item) => item.id == persisted.id);
      if (index >= 0) {
        data.tasks[index] = persisted;
      }
      _publishSyncMutation();
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
    final data = _currentData();
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
        final current = _currentData();
        current.tasks.removeWhere((task) => task.id == restored.id);
        current.tasks.insert(
          index.clamp(0, current.tasks.length).toInt(),
          restored,
        );
        for (final snapshot in childSnapshots) {
          final restoredChild = _cloneTask(snapshot);
          final childIndex = current.tasks.indexWhere(
            (task) => task.id == restoredChild.id,
          );
          if (childIndex >= 0) {
            current.tasks[childIndex] = restoredChild;
          } else {
            current.tasks.add(restoredChild);
          }
          await _repository.saveTask(restoredChild);
        }
        _scheduleSync();
      },
    );
    _publishSyncMutation();
  }

  Future<void> addProject(Project project) {
    final persisted = _cloneProject(project);
    return _mutationQueue.run(() async {
      await _repository.saveProject(persisted);
      _currentData().projects.add(persisted);
      _publishSyncMutation();
    });
  }

  Future<void> updateProject(Project project) {
    final persisted = _cloneProject(project)..updatedAt = DateTime.now();
    return _mutationQueue.run(() async {
      await _repository.saveProject(persisted);
      final data = _currentData();
      final index = data.projects.indexWhere((item) => item.id == persisted.id);
      if (index >= 0) {
        data.projects[index] = persisted;
      }
      _publishSyncMutation();
    });
  }

  Future<void> setProjectArchived(Project project, bool archived) async {
    if (project.archived == archived) {
      return;
    }
    final previous = project.archived;
    final persisted =
        _cloneProject(project)
          ..archived = archived
          ..updatedAt = DateTime.now();
    await _repository.saveProject(persisted);
    _replaceProject(persisted);
    _registerUndo(
      label:
          archived
              ? 'Архивирование проекта «${persisted.title}»'
              : 'Возврат проекта «${persisted.title}» из архива',
      restore: () async {
        final current = projectById(persisted.id);
        if (current == null) {
          return;
        }
        final restored =
            _cloneProject(current)
              ..archived = previous
              ..updatedAt = DateTime.now();
        await _repository.saveProject(restored);
        _replaceProject(restored);
        _scheduleSync();
      },
    );
    _publishSyncMutation();
  }

  Project? projectById(String id) {
    for (final project in _currentData().projects) {
      if (project.id == id) {
        return project;
      }
    }
    return null;
  }

  int citationUsageCount(String citationKey) {
    return _currentData().notes.fold<int>(
      0,
      (sum, note) => sum + CitationSyntax.countKey(note.body, citationKey),
    );
  }

  Future<void> addCitationSource(CitationSource source) async {
    final persisted = _cloneCitationSource(source);
    final next = <CitationSource>[
      persisted,
      ..._currentData().citationSources.map(_cloneCitationSource),
    ];
    await _repository.saveCitationSources(next);
    _replaceCitationSources(next);
  }

  Future<void> updateCitationSource(CitationSource source) async {
    final persisted = _cloneCitationSource(source)..updatedAt = DateTime.now();
    final next = _currentData().citationSources
        .map(_cloneCitationSource)
        .toList(growable: true);
    final index = next.indexWhere((item) => item.id == persisted.id);
    if (index < 0) {
      next.insert(0, persisted);
    } else {
      next[index] = persisted;
    }
    await _repository.saveCitationSources(next);
    _replaceCitationSources(next);
  }

  Future<void> deleteCitationSource(String id) async {
    final data = _currentData();
    final index = data.citationSources.indexWhere((source) => source.id == id);
    if (index < 0) {
      return;
    }
    final removed = _cloneCitationSource(data.citationSources[index]);
    final next = data.citationSources
        .where((source) => source.id != id)
        .map(_cloneCitationSource)
        .toList(growable: false);
    await _repository.saveCitationSources(next);
    _replaceCitationSources(next);
    _registerUndo(
      label: 'Удаление источника «${removed.title}»',
      restore: () async {
        final restored = _currentData().citationSources
            .map(_cloneCitationSource)
            .toList(growable: true);
        restored.removeWhere((source) => source.id == removed.id);
        restored.insert(
          index.clamp(0, restored.length).toInt(),
          _cloneCitationSource(removed),
        );
        await _repository.saveCitationSources(restored);
        _replaceCitationSources(restored);
      },
    );
  }

  Future<int> importCitationSources(Iterable<CitationSource> sources) async {
    final next = _currentData().citationSources
        .map(_cloneCitationSource)
        .toList(growable: true);
    final keys = next.map((source) => source.normalizedCitationKey).toSet();
    final dois =
        next
            .map((source) => source.normalizedDoi)
            .where((doi) => doi.isNotEmpty)
            .toSet();
    var imported = 0;
    for (final rawSource in sources) {
      final source = _cloneCitationSource(rawSource);
      final key = source.normalizedCitationKey;
      final doi = source.normalizedDoi;
      if (key.isEmpty || keys.contains(key)) {
        continue;
      }
      if (doi.isNotEmpty && dois.contains(doi)) {
        continue;
      }
      next.add(source);
      keys.add(key);
      if (doi.isNotEmpty) {
        dois.add(doi);
      }
      imported += 1;
    }
    if (imported == 0) {
      return 0;
    }
    next.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    await _repository.saveCitationSources(next);
    _replaceCitationSources(next);
    return imported;
  }

  void _replaceProject(Project project) {
    final data = _currentData();
    final index = data.projects.indexWhere((item) => item.id == project.id);
    if (index >= 0) {
      data.projects[index] = project;
    }
  }

  void _replaceCitationSources(List<CitationSource> sources) {
    final target = _currentData().citationSources;
    target
      ..clear()
      ..addAll(sources);
    _notifyListeners();
  }

  void _publishSyncMutation() {
    _scheduleSync();
    _notifyListeners();
  }

  Project _cloneProject(Project project) =>
      Project.fromJson(Map<String, dynamic>.from(project.toJson()));

  WorkTask _cloneTask(WorkTask task) =>
      WorkTask.fromJson(Map<String, dynamic>.from(task.toJson()));

  CitationSource _cloneCitationSource(CitationSource source) =>
      CitationSource.fromJson(Map<String, dynamic>.from(source.toJson()));
}
