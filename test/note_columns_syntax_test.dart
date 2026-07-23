import 'package:chronicle/features/notes/note_columns_syntax.dart';
import 'package:chronicle/features/notes/note_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('two-column block is parsed with widths and content', () {
    const source = '''Введение

<!-- chronicle-columns widths=40,60 -->
![Orf9b](../../Attachments/orf9b.png)
<!-- chronicle-column -->
## Интерпретация

Текст справа.
<!-- /chronicle-columns -->

Вывод
''';

    final block = NoteColumnsSyntax.first(source);

    expect(block, isNotNull);
    expect(block!.columnCount, 2);
    expect(block.widths, [40, 60]);
    expect(block.columns[0].markdown, contains('orf9b.png'));
    expect(block.columns[1].markdown, contains('Текст справа'));
    expect(source.substring(block.start, block.end), block.raw);
  });

  test('column layout survives Markdown round-trip', () {
    final markdown = NoteColumnsSyntax.build(
      widths: const [35, 65],
      contents: const [
        '![Схема](../../Attachments/schema.png)',
        'Подробное объяснение справа.',
      ],
    );
    final restored = NoteColumnsSyntax.first(markdown)!;

    expect(restored.widths, [35, 65]);
    expect(restored.columnCount, 2);
    expect(restored.columns[0].markdown, contains('Схема'));
    expect(restored.columns[1].markdown, 'Подробное объяснение справа.');
  });

  test('three columns normalize to one hundred percent', () {
    final markdown = NoteColumnsSyntax.build(
      widths: const [25, 50, 25],
      contents: const ['A', 'B', 'C'],
    );
    final restored = NoteColumnsSyntax.first(markdown)!;

    expect(restored.columnCount, 3);
    expect(restored.widths, [25, 50, 25]);
    expect(restored.widths.reduce((a, b) => a + b), 100);
  });

  test('column block can be found at cursor and relocated', () {
    final blockMarkdown = NoteColumnsSyntax.build(
      widths: const [50, 50],
      contents: const ['Левая', 'Правая'],
    );
    final source = 'До\n\n$blockMarkdown\n\nПосле';
    final cursor = source.indexOf('Правая');
    final block = NoteColumnsSyntax.findAtOffset(source, cursor)!;

    final shifted = 'Префикс\n$source';
    final relocated = NoteColumnsSyntax.relocate(shifted, block);

    expect(relocated, isNotNull);
    expect(relocated!.start, block.start + 'Префикс\n'.length);
    expect(relocated.widths, [50, 50]);
  });

  test('column content can be reordered without changing its Markdown', () {
    final markdown = NoteColumnsSyntax.build(
      widths: const [25, 50, 25],
      contents: const ['Первая', 'Вторая', 'Третья'],
    );
    final block = NoteColumnsSyntax.first(markdown)!;
    final reordered = block.orderedContents(const [2, 0, 1]);
    final rebuilt = block.toMarkdown(contents: reordered);
    final restored = NoteColumnsSyntax.first(rebuilt)!;

    expect(restored.columns[0].markdown, 'Третья');
    expect(restored.columns[1].markdown, 'Первая');
    expect(restored.columns[2].markdown, 'Вторая');
  });

  test('column block can be converted back to ordinary Markdown', () {
    final markdown = NoteColumnsSyntax.build(
      widths: const [40, 60],
      contents: const ['Левая часть', 'Правая часть'],
    );
    final block = NoteColumnsSyntax.first(markdown)!;

    expect(
      block.toPlainMarkdown(order: const [1, 0]),
      'Правая часть\n\nЛевая часть',
    );
  });

  test('invalid column order falls back to original order', () {
    expect(NoteColumnsSyntax.normalizeOrder(const [1, 1], 2), [0, 1]);
    expect(NoteColumnsSyntax.normalizeOrder(const [2, 0], 2), [0, 1]);
    expect(NoteColumnsSyntax.normalizeOrder(const [1, 0], 2), [1, 0]);
  });

  test('visual composer adds a third placeholder without losing content', () {
    final contents = NoteColumnsSyntax.normalizeContents(const [
      'Рисунок',
      'Интерпретация',
    ], 3);

    expect(contents, ['Рисунок', 'Интерпретация', 'Новая колонка']);
  });

  test('visual composer merges the last body when reducing to two columns', () {
    final contents = NoteColumnsSyntax.normalizeContents(const [
      'Слева',
      'В центре',
      'Справа',
    ], 2);

    expect(contents, ['Слева', 'В центре\n\nСправа']);
  });

  test('visual composer preserves Markdown while changing column count', () {
    final contents = NoteColumnsSyntax.normalizeContents(const [
      '![Orf9b](../../Attachments/orf9b.png)',
      '## Результат\n\n\$R_g = 1.8\\,\\mathrm{nm}\$',
      '- [x] Проверено',
    ], 2);
    final markdown = NoteColumnsSyntax.build(
      widths: const [40, 60],
      contents: contents,
    );
    final restored = NoteColumnsSyntax.first(markdown)!;

    expect(restored.columns[0].markdown, contains('orf9b.png'));
    expect(restored.columns[1].markdown, contains(r'$R_g'));
    expect(restored.columns[1].markdown, contains('- [x] Проверено'));
  });

  test('column cards can be moved with their exact content', () {
    final moved = NoteColumnsSyntax.moveItem(
      const ['Рисунок', 'Текст', 'Вывод'],
      0,
      2,
    );

    expect(moved, ['Текст', 'Вывод', 'Рисунок']);
  });

  test('a column can be duplicated only while a third slot is available', () {
    expect(NoteColumnsSyntax.duplicateContent(const ['Рисунок', 'Текст'], 0), [
      'Рисунок',
      'Рисунок',
      'Текст',
    ]);
    expect(NoteColumnsSyntax.duplicateContent(const ['A', 'B', 'C'], 1), [
      'A',
      'B',
      'C',
    ]);
  });

  test('safe column removal preserves Markdown reading order', () {
    expect(
      NoteColumnsSyntax.removeContentSafely(const [
        'Рисунок',
        'Подпись',
        'Интерпретация',
      ], 0),
      ['Рисунок\n\nПодпись', 'Интерпретация'],
    );
    expect(
      NoteColumnsSyntax.removeContentSafely(const [
        'Рисунок',
        'Подпись',
        'Интерпретация',
      ], 2),
      ['Рисунок', 'Подпись\n\nИнтерпретация'],
    );
  });

  test('column control markers do not inflate word count', () {
    final markdown = NoteColumnsSyntax.build(
      widths: const [40, 60],
      contents: const ['Фото белка', 'Описание метастабильного состояния'],
    );

    expect(NoteDocument.wordCount(markdown), 5);
  });

  test('column-like markers inside code fence are ignored', () {
    const source = '''```markdown
<!-- chronicle-columns widths=50,50 -->
A
<!-- chronicle-column -->
B
<!-- /chronicle-columns -->
```
''';

    expect(NoteColumnsSyntax.first(source), isNull);
  });
}
