import 'package:chronicle/features/notes/note_wiki_link_syntax.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('qualified wiki links keep a readable preview label', () {
    const markdown =
        'См. [[Research :: RMSD]] и [[TM-score|сравнение методов]].';
    final links = NoteWikiLinkSyntax.all(markdown).toList();

    expect(links, hasLength(2));
    expect(links.first.target, 'Research :: RMSD');
    expect(links.first.visibleLabel, 'RMSD');
    expect(links.last.visibleLabel, 'сравнение методов');
    expect(
      NoteWikiLinkSyntax.convertToMarkdown(markdown),
      contains('[RMSD](chronicle://note/Research%20%3A%3A%20RMSD)'),
    );
  });

  test('autocomplete replaces only the unfinished wiki target', () {
    const text = 'Результаты описаны в [[tm';
    final query = NoteWikiLinkSyntax.autocompleteAt(text, text.length);

    expect(query, isNotNull);
    final activeQuery = query!;
    expect(activeQuery.query, 'tm');
    final completion = NoteWikiLinkSyntax.complete(
      text,
      activeQuery,
      'Research :: TM-score',
    );
    expect(
      completion.text,
      'Результаты описаны в [[Research :: TM-score]]',
    );
    expect(completion.cursor, completion.text.length);
    expect(
      NoteWikiLinkSyntax.autocompleteAt(completion.text, completion.cursor),
      isNull,
    );
  });

  test('backlink snippet shows surrounding text and readable link label', () {
    const markdown =
        'В начале описан эксперимент. Затем см. [[Research :: RMSD]] '
        'для подробного анализа траектории и переходов.';

    final snippet = NoteWikiLinkSyntax.snippetForTarget(
      markdown,
      'Research :: RMSD',
      radius: 28,
    );

    expect(snippet, contains('RMSD'));
    expect(snippet, isNot(contains('[[')));
    expect(snippet, contains('анализа'));
  });

  // Exact-ID targets keep links stable after note renaming.
  test('exact ID links and heading anchors stay readable', () {
    const markdown = 'См. [[id:note-42#results|Результаты]].';
    final link = NoteWikiLinkSyntax.all(markdown).single;

    expect(link.target, 'id:note-42');
    expect(link.anchor, '#results');
    expect(link.visibleLabel, 'Результаты');
    expect(NoteWikiTarget.parse('id:note-42#results').noteId, 'note-42');
    expect(
      NoteWikiLinkSyntax.convertToMarkdown(markdown),
      contains('chronicle://note/id%3Anote-42%23results'),
    );
  });
  test('autocomplete can insert an exact target with a readable label', () {
    const text = 'См. [[';
    final query = NoteWikiLinkSyntax.autocompleteAt(text, text.length)!;

    final completion = NoteWikiLinkSyntax.complete(
      text,
      query,
      'id:note-42',
      label: 'RMSD',
    );

    expect(completion.text, 'См. [[id:note-42|RMSD]]');
  });

}
