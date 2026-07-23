import 'package:chronicle/features/notes/note_graph_layout.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('knowledge graph layout is deterministic and keeps nodes separate', () {
    final notes = [
      for (var index = 0; index < 9; index += 1)
        Note(
          id: 'note-$index',
          title: 'Note $index',
          projectId: index < 5 ? 'project-a' : 'project-b',
          body: '',
        ),
    ];

    final first = NoteGraphLayoutEngine.build(
      allNotes: notes,
      visibleNotes: notes,
      links: const [],
      projectOrder: const ['project-a', 'project-b'],
    );
    final second = NoteGraphLayoutEngine.build(
      allNotes: notes,
      visibleNotes: notes,
      links: const [],
      projectOrder: const ['project-a', 'project-b'],
    );

    expect(first.canvasSize, second.canvasSize);
    expect(first.nodeBounds, second.nodeBounds);
    expect(first.nodeBounds.length, notes.length);

    final bounds = first.nodeBounds.values.toList();
    for (var left = 0; left < bounds.length; left += 1) {
      final canvas = Offset.zero & first.canvasSize;
      expect(canvas.contains(bounds[left].topLeft), isTrue);
      expect(
        canvas.contains(bounds[left].bottomRight - const Offset(0.01, 0.01)),
        isTrue,
      );
      for (var right = left + 1; right < bounds.length; right += 1) {
        expect(bounds[left].overlaps(bounds[right]), isFalse);
      }
    }
  });

  test(
    'knowledge graph resolves links and reports hidden and missing targets',
    () {
      final source = Note(
        id: 'source',
        title: 'Source',
        projectId: 'project-a',
        body: '',
      );
      final visibleTarget = Note(
        id: 'visible-target',
        title: 'Visible target',
        projectId: 'project-a',
        body: '',
      );
      final hiddenTarget = Note(
        id: 'hidden-target',
        title: 'Hidden target',
        projectId: 'project-b',
        body: '',
      );
      final allNotes = [source, visibleTarget, hiddenTarget];
      final links = [
        NoteLink(
          id: 'link-visible',
          sourceNoteId: source.id,
          targetTitle: visibleTarget.title,
          targetNoteId: visibleTarget.id,
        ),
        NoteLink(
          id: 'link-hidden',
          sourceNoteId: source.id,
          targetTitle: hiddenTarget.title,
          targetNoteId: hiddenTarget.id,
        ),
        NoteLink(
          id: 'link-missing',
          sourceNoteId: source.id,
          targetTitle: 'Missing',
        ),
      ];

      final layout = NoteGraphLayoutEngine.build(
        allNotes: allNotes,
        visibleNotes: [source, visibleTarget],
        links: links,
        projectOrder: const ['project-a', 'project-b'],
      );

      expect(layout.edges, hasLength(1));
      expect(layout.edges.single.sourceNoteId, source.id);
      expect(layout.edges.single.targetNoteId, visibleTarget.id);
      expect(layout.hiddenLinkCount, 1);
      expect(layout.unresolvedLinkCount, 1);
    },
  );

  test('self-links and duplicate edges are not drawn twice', () {
    final source = Note(
      id: 'source',
      title: 'Source',
      projectId: 'project-a',
      body: '',
    );
    final target = Note(
      id: 'target',
      title: 'Target',
      projectId: 'project-a',
      body: '',
    );
    final links = [
      NoteLink(
        id: 'link-1',
        sourceNoteId: source.id,
        targetTitle: target.title,
        targetNoteId: target.id,
      ),
      NoteLink(
        id: 'link-2',
        sourceNoteId: source.id,
        targetTitle: target.title,
        targetNoteId: target.id,
      ),
      NoteLink(
        id: 'link-self',
        sourceNoteId: source.id,
        targetTitle: source.title,
        targetNoteId: source.id,
      ),
    ];

    final layout = NoteGraphLayoutEngine.build(
      allNotes: [source, target],
      visibleNotes: [source, target],
      links: links,
      projectOrder: const ['project-a'],
    );

    expect(layout.edges, hasLength(1));
  });

  test('unresolved duplicate-title links are not connected arbitrarily', () {
    final source = Note(
      id: 'source',
      title: 'Source',
      projectId: 'project-a',
      body: '',
    );
    final first = Note(
      id: 'first',
      title: 'Shared',
      projectId: 'project-a',
      body: '',
    );
    final second = Note(
      id: 'second',
      title: 'Shared',
      projectId: 'project-b',
      body: '',
    );
    final link = NoteLink(
      id: 'ambiguous',
      sourceNoteId: source.id,
      targetTitle: 'Shared',
    );

    final layout = NoteGraphLayoutEngine.build(
      allNotes: [source, first, second],
      visibleNotes: [source, first, second],
      links: [link],
      projectOrder: const ['project-a', 'project-b'],
    );

    expect(layout.edges, isEmpty);
    expect(layout.unresolvedLinkCount, 1);
  });
}
