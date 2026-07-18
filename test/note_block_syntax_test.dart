import 'package:chronicle/features/notes/note_block_syntax.dart';
import 'package:chronicle/features/notes/note_columns_syntax.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recognizes portable Markdown block types', () {
    final columns = NoteColumnsSyntax.build(
      widths: const [40, 60],
      contents: const ['Фото', 'Описание'],
    );
    final source = '''# Заголовок

Обычный абзац
из двух строк.

- [ ] Проверить модель
- [x] Сохранить результат

![Orf9b](../../Attachments/orf9b.png)

\\[
RMSD = \\sqrt{x}
\\]

```python
print("block")

print("with blank line")
```

$columns
''';

    final blocks = NoteBlockSyntax.all(source);

    expect(
      blocks.map((block) => block.type),
      [
        NoteBlockType.heading,
        NoteBlockType.paragraph,
        NoteBlockType.checklist,
        NoteBlockType.image,
        NoteBlockType.math,
        NoteBlockType.code,
        NoteBlockType.columns,
      ],
    );
    expect(blocks[5].raw, contains('with blank line'));
    expect(blocks[6].raw, contains('chronicle-columns'));
  });

  test('finds a whole columns block from a cursor inside a column', () {
    final columns = NoteColumnsSyntax.build(
      widths: const [50, 50],
      contents: const ['Левая часть', 'Правая часть'],
    );
    final source = 'До\n\n$columns\n\nПосле';

    final block = NoteBlockSyntax.findAtOffset(
      source,
      source.indexOf('Правая часть'),
    );

    expect(block, isNotNull);
    expect(block!.type, NoteBlockType.columns);
    expect(block.raw, columns);
  });

  test('moves a block up without rewriting its Markdown', () {
    const source = 'Первый\n\n## Второй\n\n> Третий';

    final result = NoteBlockSyntax.moveUp(
      source,
      source.indexOf('Второй'),
    )!;

    expect(result.text, '## Второй\n\nПервый\n\n> Третий');
    expect(
      result.text.substring(result.selectionStart, result.selectionEnd),
      '## Второй',
    );
  });

  test('moves a fenced code block down as one unit', () {
    const source = '''До

```text
A

B
```

После''';

    final result = NoteBlockSyntax.moveDown(
      source,
      source.indexOf('```text'),
    )!;

    expect(result.text, '''До

После

```text
A

B
```''');
  });

  test('duplicates the selected block and preserves separators', () {
    const source = 'Один\n\nДва\n\nТри';

    final result = NoteBlockSyntax.duplicate(
      source,
      source.indexOf('Два'),
    )!;

    expect(result.text, 'Один\n\nДва\n\nДва\n\nТри');
    expect(
      result.text.substring(result.selectionStart, result.selectionEnd),
      'Два',
    );
  });

  test('deletes one block without joining neighboring text', () {
    const source = 'Один\n\nУдалить\n\nТри';

    final result = NoteBlockSyntax.delete(
      source,
      source.indexOf('Удалить'),
    )!;

    expect(result.text, 'Один\n\nТри');
  });

  test('converts paragraphs, headings, lists and quotes safely', () {
    const source = 'Первая строка\nВторая строка';

    final heading = NoteBlockSyntax.convert(
      source,
      0,
      NoteBlockConversion.heading2,
    )!;
    expect(heading.text, '## Первая строка Вторая строка');

    final checklist = NoteBlockSyntax.convert(
      source,
      0,
      NoteBlockConversion.checklist,
    )!;
    expect(checklist.text, '- [ ] Первая строка\n- [ ] Вторая строка');

    final paragraph = NoteBlockSyntax.convert(
      '> Первая строка\n> Вторая строка',
      2,
      NoteBlockConversion.paragraph,
    )!;
    expect(paragraph.text, 'Первая строка\nВторая строка');
  });

  test('does not convert structural blocks that could lose data', () {
    const code = '```python\nprint(1)\n```';
    const image = '![Схема](../../Attachments/schema.png)';

    expect(
      NoteBlockSyntax.convert(code, 4, NoteBlockConversion.heading1),
      isNull,
    );
    expect(
      NoteBlockSyntax.convert(image, 4, NoteBlockConversion.quote),
      isNull,
    );
  });
  test('finds the nearest block in a large document without rescanning it', () {
    final source = List.generate(
      1200,
      (index) => '## Раздел $index\n\nТекст блока $index',
    ).join('\n\n');
    final blocks = NoteBlockSyntax.all(source);
    final targetOffset = source.indexOf('Текст блока 973');

    final target = NoteBlockSyntax.findIn(
      blocks,
      source.length,
      targetOffset,
    );
    final gap = NoteBlockSyntax.findIn(
      blocks,
      source.length,
      source.indexOf('## Раздел 974') - 1,
    );

    expect(target, isNotNull);
    expect(target!.raw, 'Текст блока 973');
    expect(gap, isNotNull);
    expect(gap!.raw, 'Текст блока 973');
  });

}
