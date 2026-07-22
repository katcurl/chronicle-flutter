import 'package:chronicle/features/notes/note_link_tools.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const rmsd = NoteLinkTarget(
    id: 'note-rmsd',
    title: 'RMSD analysis',
    projectTitle: 'ORF9b',
    folderPath: 'MD',
    noteType: 'experiment',
    tags: <String>['rmsd'],
  );
  const shortRmsd = NoteLinkTarget(
    id: 'note-rmsd-short',
    title: 'RMSD',
    projectTitle: 'ORF9b',
    folderPath: 'MD',
    noteType: 'note',
  );
  const buffer = NoteLinkTarget(
    id: 'note-buffer',
    title: 'NMR buffer',
    projectTitle: 'ORF9b',
    folderPath: 'Samples',
    noteType: 'sample',
  );

  test('stable links always use exact IDs and readable labels', () {
    expect(
      NoteLinkTools.stableMarkdown(rmsd),
      '[[id:note-rmsd|RMSD analysis]]',
    );
    expect(
      NoteLinkTools.stableMarkdown(rmsd, label: 'RMSD | result'),
      '[[id:note-rmsd|RMSD ¦ result]]',
    );
  });

  test('multiple stable links can be inserted inline or as a list', () {
    expect(
      NoteLinkTools.compose(
        const <NoteLinkTarget>[rmsd, buffer],
        style: NoteLinkInsertStyle.inline,
      ),
      '[[id:note-rmsd|RMSD analysis]], [[id:note-buffer|NMR buffer]]',
    );
    expect(
      NoteLinkTools.compose(
        const <NoteLinkTarget>[rmsd, buffer],
        style: NoteLinkInsertStyle.bulleted,
      ),
      '- [[id:note-rmsd|RMSD analysis]]\n'
      '- [[id:note-buffer|NMR buffer]]',
    );
  });

  test('mention search ignores existing links and code blocks', () {
    const markdown = '''
RMSD analysis showed a transition. RMSD was recalculated.
Already linked: [[id:note-buffer|NMR buffer]].
`RMSD analysis` must stay code.
```
NMR buffer
```
''';

    final mentions = NoteLinkTools.findUnlinkedMentions(
      markdown,
      const <NoteLinkTarget>[rmsd, shortRmsd, buffer],
    );

    expect(mentions, hasLength(2));
    expect(mentions.first.target.id, 'note-rmsd');
    expect(mentions.first.matchedText, 'RMSD analysis');
    expect(mentions.last.target.id, 'note-rmsd-short');
    expect(mentions.last.matchedText, 'RMSD');
  });

  test('ambiguous duplicate titles are not offered as mentions', () {
    const duplicate = NoteLinkTarget(
      id: 'note-buffer-2',
      title: 'NMR buffer',
      projectTitle: 'Other',
      folderPath: '',
      noteType: 'note',
    );

    final mentions = NoteLinkTools.findUnlinkedMentions(
      'Use NMR buffer for the sample.',
      const <NoteLinkTarget>[buffer, duplicate],
    );

    expect(mentions, isEmpty);
  });

  test('linking mentions preserves visible text and adjusts the cursor', () {
    const markdown = 'Compare RMSD analysis with NMR buffer.';
    final mentions = NoteLinkTools.findUnlinkedMentions(
      markdown,
      const <NoteLinkTarget>[rmsd, buffer],
    );

    final edit = NoteLinkTools.applyMentions(
      markdown,
      mentions,
      cursor: markdown.length,
    );

    expect(
      edit.text,
      'Compare [[id:note-rmsd|RMSD analysis]] with '
      '[[id:note-buffer|NMR buffer]].',
    );
    expect(edit.cursor, edit.text.length);
  });
}
