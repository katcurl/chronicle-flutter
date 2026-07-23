import 'package:chronicle/features/notes/note_version_diff.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('line diff reports additions, removals and stable line numbers', () {
    final diff = NoteVersionDiff.compare(
      'alpha\nbeta\ngamma',
      'alpha\nbeta changed\ngamma\ndelta',
    );

    expect(diff.isApproximate, isFalse);
    expect(diff.addedLineCount, 2);
    expect(diff.removedLineCount, 1);
    expect(diff.unchangedLineCount, 2);
    expect(diff.lines.map((line) => line.kind), <NoteVersionDiffKind>[
      NoteVersionDiffKind.unchanged,
      NoteVersionDiffKind.removed,
      NoteVersionDiffKind.added,
      NoteVersionDiffKind.unchanged,
      NoteVersionDiffKind.added,
    ]);
    expect(diff.lines.first.oldLineNumber, 1);
    expect(diff.lines.first.newLineNumber, 1);
    expect(diff.lines.last.newLineNumber, 4);
  });

  test('identical documents contain only unchanged lines', () {
    final diff = NoteVersionDiff.compare('one\ntwo', 'one\ntwo');

    expect(diff.hasChanges, isFalse);
    expect(diff.addedLineCount, 0);
    expect(diff.removedLineCount, 0);
    expect(diff.unchangedLineCount, 2);
  });

  test('large documents keep the common prefix and suffix', () {
    final oldText = <String>[
      'start',
      ...List<String>.generate(40, (index) => 'old $index'),
      'end',
    ].join('\n');
    final newText = <String>[
      'start',
      ...List<String>.generate(40, (index) => 'new $index'),
      'end',
    ].join('\n');

    final diff = NoteVersionDiff.compare(oldText, newText, maxMatrixCells: 10);

    expect(diff.isApproximate, isTrue);
    expect(diff.unchangedLineCount, 2);
    expect(diff.removedLineCount, 40);
    expect(diff.addedLineCount, 40);
    expect(diff.lines.first.text, 'start');
    expect(diff.lines.last.text, 'end');
  });
}
