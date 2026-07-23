import 'package:chronicle/features/notes/note_document.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('front matter is parsed and serialized with structured metadata', () {
    final note = Note(
      id: 'note-1',
      title: 'Лекция',
      projectId: 'project-1',
      body: '',
      noteType: 'lecture',
      status: 'review',
      folderPath: 'Курс/Химия',
      tags: const ['атом', 'лекция'],
      properties: const {'audience': '8 класс'},
    );

    final encoded = NoteDocument.serialize(note, '# Строение атома\n\nТекст');
    final parsed = NoteDocument.parse(encoded);

    expect(parsed.frontMatter['type'], 'lecture');
    expect(parsed.frontMatter['status'], 'review');
    expect(parsed.frontMatter['folder'], 'Курс/Химия');
    expect(parsed.frontMatter['audience'], '8 класс');
    expect(NoteDocument.parseTags(parsed.frontMatter['tags']), [
      'атом',
      'лекция',
    ]);
    expect(parsed.content, startsWith('# Строение атома'));
  });

  test('wiki links are discovered and converted to internal links', () {
    const markdown = 'См. [[RMSD]] и [[TM-score|сравнение]].';

    expect(NoteDocument.extractWikiTargets(markdown), {'RMSD', 'TM-score'});
    expect(
      NoteDocument.convertWikiLinksToMarkdown(markdown),
      contains('chronicle://note/RMSD'),
    );
  });

  test('word count ignores common markdown punctuation', () {
    expect(NoteDocument.wordCount('# Заголовок\n\nДва важных слова.'), 4);
  });
  test('content replacement preserves front matter byte structure', () {
    const original = '---\nstatus: draft\ncustom: value\n---\n\nOld text';

    final replaced = NoteDocument.replaceContent(original, 'New text');

    expect(
      replaced,
      '---\nstatus: draft\ncustom: value\n---\n\nNew text',
    );
  });

}
