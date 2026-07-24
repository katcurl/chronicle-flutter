import 'package:uuid/uuid.dart';

import '../../data/repositories/app_repository.dart';
import '../../features/notes/note_document.dart';
import '../../features/notes/note_wiki_link_syntax.dart';
import '../../features/notes/note_wiki_rename.dart';
import '../../models/app_models.dart';

typedef SyncNoteLinks = Future<void> Function(Note note, {bool notify});

final class WikiLinkCommands {
  WikiLinkCommands({
    required AppRepository repository,
    required AppData Function() currentData,
    required SyncNoteLinks syncNoteLinks,
    required void Function() scheduleSync,
    required void Function() scheduleVaultMirror,
    required void Function() notifyListeners,
    Uuid uuid = const Uuid(),
  }) : _repository = repository,
       _currentData = currentData,
       _syncNoteLinks = syncNoteLinks,
       _scheduleSync = scheduleSync,
       _scheduleVaultMirror = scheduleVaultMirror,
       _notifyListeners = notifyListeners,
       _uuid = uuid;

  final AppRepository _repository;
  final AppData Function() _currentData;
  final SyncNoteLinks _syncNoteLinks;
  final void Function() _scheduleSync;
  final void Function() _scheduleVaultMirror;
  final void Function() _notifyListeners;
  final Uuid _uuid;

  Project? projectById(String id) {
    for (final project in _currentData().projects) {
      if (project.id == id) {
        return project;
      }
    }
    return null;
  }

  Note? noteById(String id) {
    for (final note in _currentData().notes) {
      if (note.id == id) {
        return note;
      }
    }
    return null;
  }

  Note? noteByTitle(String title) {
    final matches = notesByTitle(title);
    return matches.isEmpty ? null : matches.first;
  }

  List<Note> notesByTitle(String title) {
    final normalized = title.trim().toLowerCase();
    return _currentData().notes
        .where((note) => note.title.trim().toLowerCase() == normalized)
        .toList(growable: false);
  }

  List<Note> notesForTarget(String rawTarget, {Note? source}) {
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
        if (source == null) {
          return 2;
        }
        if (note.projectId == source.projectId &&
            note.folderPath.trim() == source.folderPath.trim()) {
          return 0;
        }
        if (note.projectId == source.projectId) {
          return 1;
        }
        return 2;
      }

      final rankCompare = rank(left).compareTo(rank(right));
      if (rankCompare != 0) {
        return rankCompare;
      }
      final leftProject = projectById(left.projectId)?.title ?? '';
      final rightProject = projectById(right.projectId)?.title ?? '';
      final projectCompare = leftProject.toLowerCase().compareTo(
        rightProject.toLowerCase(),
      );
      if (projectCompare != 0) {
        return projectCompare;
      }
      final folderCompare = left.folderPath.toLowerCase().compareTo(
        right.folderPath.toLowerCase(),
      );
      if (folderCompare != 0) {
        return folderCompare;
      }
      return left.id.compareTo(right.id);
    });
    return List<Note>.unmodifiable(sorted);
  }

  Note? resolveTarget(String rawTarget, {Note? source}) {
    final reference = NoteWikiTarget.parse(rawTarget);
    final candidates = notesForTarget(rawTarget, source: source);
    if (candidates.length == 1) {
      return candidates.single;
    }
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
    if (sameFolder.length == 1) {
      return sameFolder.single;
    }

    final sameProject = candidates
        .where((note) => note.projectId == source.projectId)
        .toList(growable: false);
    return sameProject.length == 1 ? sameProject.single : null;
  }

  String targetFor(Note note) {
    final duplicates = notesByTitle(note.title);
    if (duplicates.length <= 1) {
      return note.title;
    }
    return NoteWikiTarget.exactId(note.id);
  }

  List<NoteLink> outgoingLinksFor(String noteId) => _currentData().noteLinks
      .where((link) => link.sourceNoteId == noteId)
      .toList(growable: false);

  List<NoteLink> backlinksFor(Note note) {
    return _currentData().noteLinks
        .where((link) {
          if (link.targetNoteId != null) {
            return link.targetNoteId == note.id;
          }
          final source = noteById(link.sourceNoteId);
          return resolveTarget(link.targetTitle, source: source)?.id == note.id;
        })
        .toList(growable: false);
  }

  NoteWikiRenamePlan buildRenamePlan(Note note, String newTitle) {
    return NoteWikiRenamePlanner.build(
      target: note,
      newTitle: newTitle,
      notes: _currentData().notes,
      resolveTarget:
          (source, rawTarget) => resolveTarget(rawTarget, source: source),
      targetCandidates:
          (source, rawTarget) => notesForTarget(rawTarget, source: source),
    );
  }

  List<NoteWikiLinkIssue> linkIssues() {
    return NoteWikiRenamePlanner.findIssues(
      notes: _currentData().notes,
      resolveTarget:
          (source, rawTarget) => resolveTarget(rawTarget, source: source),
      targetCandidates:
          (source, rawTarget) => notesForTarget(rawTarget, source: source),
    );
  }

  Future<NoteWikiRenameUndo> applyRenamePlan(NoteWikiRenamePlan plan) async {
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
      if (note == null) {
        continue;
      }
      snapshots.add(
        NoteWikiSnapshot(noteId: note.id, title: note.title, body: note.body),
      );
      final version = _version(
        note,
        reason: 'Перед безопасным переименованием «${plan.oldTitle}»',
        createdAt: now,
      );
      await _repository.saveNoteVersion(version);
      _currentData().noteVersions.insert(0, version);
    }

    try {
      for (final change in plan.sourceChanges) {
        final source = noteById(change.sourceNoteId);
        if (source != null) {
          source.body = change.updatedBody;
        }
      }
      target.title = plan.newTitle;

      for (final noteId in changedIds) {
        final note = noteById(noteId);
        if (note == null) {
          continue;
        }
        note.updatedAt = DateTime.now();
        note.revision += 1;
        await _repository.saveNote(note);
      }
      await _syncChangedLinks(changedIds);
    } on Object {
      await _restoreSnapshots(snapshots);
      rethrow;
    }
    _publishMutation();
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

  Future<void> undoRename(NoteWikiRenameUndo undo) async {
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
      if (note == null) {
        continue;
      }
      final version = _version(
        note,
        reason: 'Перед отменой безопасного переименования',
      );
      await _repository.saveNoteVersion(version);
      _currentData().noteVersions.insert(0, version);
      note.title = snapshot.title;
      note.body = snapshot.body;
      note.updatedAt = DateTime.now();
      note.revision += 1;
      restoredIds.add(note.id);
      await _repository.saveNote(note);
    }
    await _syncChangedLinks(restoredIds);
    _publishMutation();
  }

  Future<void> repairLink({
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
    if (!changed) {
      return;
    }

    final version = _version(source, reason: 'Перед исправлением вики-ссылки');
    await _repository.saveNoteVersion(version);
    _currentData().noteVersions.insert(0, version);
    source.body = NoteDocument.replaceContent(source.body, content);
    source.updatedAt = DateTime.now();
    source.revision += 1;
    await _repository.saveNote(source);
    await _syncNoteLinks(source, notify: false);
    _publishMutation();
  }

  Future<void> _restoreSnapshots(Iterable<NoteWikiSnapshot> snapshots) async {
    final restoredIds = <String>{};
    for (final snapshot in snapshots) {
      final note = noteById(snapshot.noteId);
      if (note == null) {
        continue;
      }
      note.title = snapshot.title;
      note.body = snapshot.body;
      note.updatedAt = DateTime.now();
      note.revision += 1;
      restoredIds.add(note.id);
      await _repository.saveNote(note);
    }
    await _syncChangedLinks(restoredIds);
    _notifyListeners();
  }

  Future<void> _syncChangedLinks(Iterable<String> noteIds) async {
    for (final noteId in noteIds) {
      final note = noteById(noteId);
      if (note != null) {
        await _syncNoteLinks(note, notify: false);
      }
    }
  }

  NoteVersion _version(
    Note note, {
    required String reason,
    DateTime? createdAt,
  }) {
    return NoteVersion(
      id: _uuid.v4(),
      noteId: note.id,
      title: note.title,
      body: note.body,
      tags: List<String>.from(note.tags),
      status: note.status,
      folderPath: note.folderPath,
      noteType: note.noteType,
      properties: Map<String, String>.from(note.properties),
      reason: reason,
      createdAt: createdAt,
    );
  }

  void _publishMutation() {
    _scheduleSync();
    _scheduleVaultMirror();
    _notifyListeners();
  }
}
