import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../data/repositories/app_repository.dart';
import '../../data/repositories/mutation_queue.dart';
import '../../features/notes/note_document.dart';
import '../../models/app_models.dart';

typedef ResolveWikiTarget = Note? Function(String rawTarget, {Note? source});
typedef RegisterNoteUndo =
    void Function({
      required String label,
      required Future<void> Function() restore,
    });

final class NoteCommands {
  NoteCommands({
    required AppRepository repository,
    required MutationQueue mutationQueue,
    required AppData Function() currentData,
    required ResolveWikiTarget resolveWikiTarget,
    required RegisterNoteUndo registerUndo,
    required Future<void> Function(Object error) recordLinkIndexWarning,
    required void Function() scheduleSync,
    required void Function() scheduleVaultMirror,
    required void Function() notifyListeners,
    Uuid uuid = const Uuid(),
  }) : _repository = repository,
       _mutationQueue = mutationQueue,
       _currentData = currentData,
       _resolveWikiTarget = resolveWikiTarget,
       _registerUndo = registerUndo,
       _recordLinkIndexWarning = recordLinkIndexWarning,
       _scheduleSync = scheduleSync,
       _scheduleVaultMirror = scheduleVaultMirror,
       _notifyListeners = notifyListeners,
       _uuid = uuid;

  final AppRepository _repository;
  final MutationQueue _mutationQueue;
  final AppData Function() _currentData;
  final ResolveWikiTarget _resolveWikiTarget;
  final RegisterNoteUndo _registerUndo;
  final Future<void> Function(Object error) _recordLinkIndexWarning;
  final void Function() _scheduleSync;
  final void Function() _scheduleVaultMirror;
  final void Function() _notifyListeners;
  final Uuid _uuid;

  Future<void> add(Note note) {
    final persisted = _cloneNote(note);
    return _mutationQueue.run(() async {
      await _repository.saveNote(persisted);
      _currentData().notes.insert(0, persisted);
      await syncLinks(persisted);
      _scheduleSync();
      _scheduleVaultMirror();
      _notifyListeners();
    });
  }

  Future<void> update(Note note) {
    final persisted =
        _cloneNote(note)
          ..updatedAt = DateTime.now()
          ..revision += 1;
    return _mutationQueue.run(() async {
      await _repository.saveNote(persisted);
      final data = _currentData();
      final index = data.notes.indexWhere((item) => item.id == persisted.id);
      if (index >= 0) {
        data.notes[index] = persisted;
      }
      await syncLinks(persisted);
      _scheduleSync();
      _scheduleVaultMirror();
      _notifyListeners();
    });
  }

  Future<void> addVersion(NoteVersion version) {
    final persisted = NoteVersion.fromJson(
      Map<String, dynamic>.from(version.toJson()),
    );
    return _mutationQueue.run(() async {
      await _repository.saveNoteVersion(persisted);
      _currentData().noteVersions.insert(0, persisted);
      _scheduleSync();
      _notifyListeners();
    });
  }

  void restoreVersion(Note note, NoteVersion version) {
    note.title = version.title;
    note.body = version.body;
    note.tags = List<String>.from(version.tags);
    note.status = version.status;
    note.folderPath = version.folderPath;
    note.noteType = version.noteType;
    note.properties = Map<String, String>.from(version.properties);
    unawaited(update(note));
  }

  List<NoteVersion> versionsFor(String noteId) {
    final versions =
        _currentData().noteVersions
            .where((version) => version.noteId == noteId)
            .toList();
    versions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return versions;
  }

  Future<void> delete(String id) async {
    final data = _currentData();
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
        final current = _currentData();
        current.notes.removeWhere((note) => note.id == restored.id);
        current.notes.insert(
          noteIndex.clamp(0, current.notes.length).toInt(),
          restored,
        );
        for (final snapshot in taskSnapshots) {
          final restoredTask = _cloneTask(snapshot);
          final taskIndex = current.tasks.indexWhere(
            (task) => task.id == restoredTask.id,
          );
          if (taskIndex >= 0) {
            current.tasks[taskIndex] = restoredTask;
          } else {
            current.tasks.add(restoredTask);
          }
          await _repository.saveTask(restoredTask);
        }
        current.noteLinks.removeWhere(
          (link) =>
              link.sourceNoteId == restored.id ||
              link.targetNoteId == restored.id,
        );
        current.noteLinks.addAll(linkSnapshots.map(_cloneNoteLink));
        await _rebuildLinksWithWarning();
        _scheduleSync();
        _scheduleVaultMirror();
      },
    );
    await _rebuildLinksWithWarning();
    _scheduleSync();
    _scheduleVaultMirror();
    _notifyListeners();
  }

  Future<void> rebuildAllLinks({bool notify = true}) async {
    for (final note in _currentData().notes) {
      await syncLinks(note, notify: false);
    }
    if (notify) {
      _notifyListeners();
    }
  }

  Future<void> syncLinks(Note note, {bool notify = true}) async {
    final targets = NoteDocument.extractWikiTargets(note.body);
    final now = DateTime.now();
    final links = targets
        .map((title) {
          final target = _resolveWikiTarget(title, source: note);
          return NoteLink(
            id: _uuid.v4(),
            sourceNoteId: note.id,
            targetTitle: title,
            targetNoteId: target?.id,
            createdAt: now,
          );
        })
        .toList(growable: false);

    await _repository.replaceNoteLinks(note.id, links);
    final data = _currentData();
    data.noteLinks.removeWhere((link) => link.sourceNoteId == note.id);
    data.noteLinks.addAll(links);
    if (notify) {
      _notifyListeners();
    }
  }

  Future<void> hydrateMetadata() async {
    for (final note in _currentData().notes) {
      final document = NoteDocument.parse(note.body);
      if (document.frontMatter.isEmpty) {
        continue;
      }
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
      if (changed) {
        await _repository.saveNote(note);
      }
    }
  }

  Future<void> _rebuildLinksWithWarning() async {
    try {
      await rebuildAllLinks(notify: false);
    } on Object catch (error) {
      await _recordLinkIndexWarning(error);
    }
  }

  Note _cloneNote(Note note) =>
      Note.fromJson(Map<String, dynamic>.from(note.toJson()));

  WorkTask _cloneTask(WorkTask task) =>
      WorkTask.fromJson(Map<String, dynamic>.from(task.toJson()));

  NoteLink _cloneNoteLink(NoteLink link) =>
      NoteLink.fromJson(Map<String, dynamic>.from(link.toJson()));
}
