import 'package:chronicle/data/repositories/in_memory_app_repository.dart';
import 'package:chronicle/features/notes/note_document.dart';
import 'package:chronicle/features/notes/note_wiki_link_syntax.dart';
import 'package:chronicle/features/notes/note_wiki_rename.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:chronicle/services/app_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rename planner updates only links resolved to the target note', () {
    final projectA = Project(id: 'project-a', title: 'A', emoji: '🧪');
    final projectB = Project(id: 'project-b', title: 'B', emoji: '🧬');
    final projectC = Project(id: 'project-c', title: 'C', emoji: '📚');
    final target = Note(
      id: 'target-a',
      title: 'RMSD',
      projectId: projectA.id,
      body: '# RMSD',
    );
    final duplicate = Note(
      id: 'target-b',
      title: 'RMSD',
      projectId: projectB.id,
      body: '# RMSD B',
    );
    final exactSource = Note(
      id: 'source-a',
      title: 'Journal A',
      projectId: projectA.id,
      body: 'См. [[RMSD]] и [[RMSD#method|метод]].',
    );
    final ambiguousSource = Note(
      id: 'source-c',
      title: 'Journal C',
      projectId: projectC.id,
      body: 'См. [[RMSD]].',
    );
    final notes = [target, duplicate, exactSource, ambiguousSource];

    List<Note> candidates(Note source, String rawTarget) {
      final parsed = NoteWikiTarget.parse(rawTarget);
      if (parsed.noteId != null) {
        return notes.where((note) => note.id == parsed.noteId).toList();
      }
      var result = notes
          .where(
            (note) =>
                note.title.toLowerCase() == parsed.noteTitle.toLowerCase(),
          )
          .toList();
      if (parsed.projectTitle != null) {
        result = result.where((note) {
          final project = [projectA, projectB, projectC].singleWhere(
            (item) => item.id == note.projectId,
          );
          return project.title.toLowerCase() ==
              parsed.projectTitle!.toLowerCase();
        }).toList();
      }
      return result;
    }

    Note? resolve(Note source, String rawTarget) {
      final matches = candidates(source, rawTarget);
      if (matches.length == 1) return matches.single;
      final sameProject = matches
          .where((note) => note.projectId == source.projectId)
          .toList();
      return sameProject.length == 1 ? sameProject.single : null;
    }

    final plan = NoteWikiRenamePlanner.build(
      target: target,
      newTitle: 'RMSD analysis',
      notes: notes,
      resolveTarget: resolve,
      targetCandidates: candidates,
    );

    expect(plan.changedNoteCount, 1);
    expect(plan.occurrenceCount, 2);
    expect(plan.skippedAmbiguousOccurrences, 1);
    expect(plan.requiresReview, isTrue);
    final updated = plan.sourceChanges.single.updatedBody;
    expect(updated, contains('[[id:target-a|RMSD analysis]]'));
    expect(updated, contains('[[id:target-a#method|метод]]'));
    expect(ambiguousSource.body, 'См. [[RMSD]].');
  });

  test('store applies and undoes a linked rename with persistent versions', () async {
    final project = Project(id: 'project', title: 'Research', emoji: '🧬');
    final target = Note(
      id: 'target',
      title: 'Old title',
      projectId: project.id,
      body: '# Old title',
    );
    final source = Note(
      id: 'source',
      title: 'Journal',
      projectId: project.id,
      body: 'Before [[Old title]] after.',
    );
    final repository = InMemoryAppRepository(
      initialData: AppData(
        projects: [project],
        tasks: [],
        notes: [target, source],
        entries: [],
      ),
    );
    await repository.markInitialized();
    final store = AppStore(repository: repository);
    await store.load();
    await store.rebuildAllNoteLinks();

    final loadedTarget = store.noteById(target.id)!;
    final plan = store.buildWikiRenamePlan(loadedTarget, 'New title');
    final undo = await store.applyWikiRenamePlan(plan);

    expect(loadedTarget.title, 'New title');
    final loadedSource = store.noteById(source.id)!;
    expect(
      NoteDocument.parse(loadedSource.body).content,
      contains('[[id:target|New title]]'),
    );
    expect(store.resolveWikiTarget('id:target')?.id, target.id);
    expect(store.versionsFor(target.id), isNotEmpty);
    expect(store.versionsFor(source.id), isNotEmpty);

    final expectedSource = undo.appliedSnapshots.singleWhere(
      (snapshot) => snapshot.noteId == source.id,
    );
    loadedSource.body = '${loadedSource.body} changed';
    await expectLater(
      store.undoWikiRename(undo),
      throwsA(isA<StateError>()),
    );
    loadedSource.body = expectedSource.body;

    await store.undoWikiRename(undo);
    expect(loadedTarget.title, 'Old title');
    expect(
      NoteDocument.parse(loadedSource.body).content,
      'Before [[Old title]] after.',
    );

    await store.repairWikiLink(
      source: loadedSource,
      rawTarget: 'Old title',
      target: loadedTarget,
    );
    expect(
      NoteDocument.parse(loadedSource.body).content,
      'Before [[id:target|Old title]] after.',
    );
    store.dispose();
  });

  test('link health distinguishes missing and ambiguous targets', () async {
    final projectA = Project(id: 'a', title: 'A', emoji: '🧪');
    final projectB = Project(id: 'b', title: 'B', emoji: '🧬');
    final projectC = Project(id: 'c', title: 'C', emoji: '📚');
    final first = Note(
      id: 'first',
      title: 'RMSD',
      projectId: projectA.id,
      body: '',
    );
    final second = Note(
      id: 'second',
      title: 'RMSD',
      projectId: projectB.id,
      body: '',
    );
    final source = Note(
      id: 'source',
      title: 'Journal',
      projectId: projectC.id,
      body: '[[RMSD]] and [[Missing]].',
    );
    final repository = InMemoryAppRepository(
      initialData: AppData(
        projects: [projectA, projectB, projectC],
        tasks: [],
        notes: [first, second, source],
        entries: [],
      ),
    );
    await repository.markInitialized();
    final store = AppStore(repository: repository);
    await store.load();

    final issues = store.wikiLinkIssues();
    expect(issues, hasLength(2));
    expect(
      issues.singleWhere((issue) => issue.rawTarget == 'RMSD').kind,
      NoteWikiLinkIssueKind.ambiguous,
    );
    expect(
      issues.singleWhere((issue) => issue.rawTarget == 'Missing').kind,
      NoteWikiLinkIssueKind.missing,
    );
    store.dispose();
  });
}
