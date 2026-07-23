import 'package:chronicle/features/notes/note_graph_analysis.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Note note(String id) => Note(
        id: id,
        title: id.toUpperCase(),
        projectId: 'project',
        body: '',
      );

  NoteLink link(String source, String target) => NoteLink(
        id: '$source-$target',
        sourceNoteId: source,
        targetTitle: target.toUpperCase(),
        targetNoteId: target,
      );

  test('analysis counts directed degrees and undirected neighbors', () {
    final analysis = NoteGraphAnalysis.build(
      notes: [note('a'), note('b'), note('c')],
      links: [
        link('a', 'b'),
        link('a', 'c'),
        link('b', 'c'),
      ],
    );

    expect(analysis.resolvedEdgeCount, 3);
    expect(analysis.degrees['a']?.outgoing, 2);
    expect(analysis.degrees['a']?.incoming, 0);
    expect(analysis.degrees['c']?.incoming, 2);
    expect(analysis.neighbors['b'], {'a', 'c'});
    expect(analysis.isolatedNoteIds, isEmpty);
  });

  test('duplicate and self links do not inflate graph statistics', () {
    final analysis = NoteGraphAnalysis.build(
      notes: [note('a'), note('b')],
      links: [
        link('a', 'b'),
        NoteLink(
          id: 'duplicate',
          sourceNoteId: 'a',
          targetTitle: 'B',
          targetNoteId: 'b',
        ),
        link('a', 'a'),
      ],
    );

    expect(analysis.resolvedEdgeCount, 1);
    expect(analysis.degrees['a']?.total, 1);
    expect(analysis.degrees['b']?.total, 1);
  });

  test('components include isolated notes and are ordered by size', () {
    final analysis = NoteGraphAnalysis.build(
      notes: [note('a'), note('b'), note('c'), note('d'), note('e')],
      links: [
        link('a', 'b'),
        link('b', 'c'),
        link('d', 'e'),
      ],
    );

    expect(analysis.components, hasLength(2));
    expect(analysis.components.first, {'a', 'b', 'c'});
    expect(analysis.components.last, {'d', 'e'});
  });

  test('neighborhood is bounded by the requested number of steps', () {
    final analysis = NoteGraphAnalysis.build(
      notes: [note('a'), note('b'), note('c'), note('d')],
      links: [
        link('a', 'b'),
        link('b', 'c'),
        link('c', 'd'),
      ],
    );

    expect(analysis.neighborhood('a', depth: 0), {'a'});
    expect(analysis.neighborhood('a', depth: 1), {'a', 'b'});
    expect(analysis.neighborhood('a', depth: 2), {'a', 'b', 'c'});
  });

  test('shortest path follows links in either direction', () {
    final analysis = NoteGraphAnalysis.build(
      notes: [note('a'), note('b'), note('c'), note('d')],
      links: [
        link('a', 'b'),
        link('c', 'b'),
        link('c', 'd'),
      ],
    );

    expect(analysis.shortestPath('a', 'd'), ['a', 'b', 'c', 'd']);
    expect(analysis.shortestPath('d', 'a'), ['d', 'c', 'b', 'a']);
  });

  test('missing targets are reported without creating neighbors', () {
    final analysis = NoteGraphAnalysis.build(
      notes: [note('a'), note('b')],
      links: [
        NoteLink(
          id: 'missing',
          sourceNoteId: 'a',
          targetTitle: 'Missing',
        ),
      ],
    );

    expect(analysis.unresolvedLinkCount, 1);
    expect(analysis.resolvedEdgeCount, 0);
    expect(analysis.isolatedNoteIds, {'a', 'b'});
  });
}
