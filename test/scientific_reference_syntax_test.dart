import 'package:chronicle/features/notes/note_image_syntax.dart';
import 'package:chronicle/features/notes/scientific_reference_syntax.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('numbers figures and tables independently in document order', () {
    final firstImage = NoteImageSyntax.first(
      '![Первый](../../Attachments/first.png)',
    )!.toMarkdown(
      presentation: const NoteImagePresentation(
        caption: 'Первая структура',
        figureId: 'first-structure',
      ),
    );
    final secondImage = NoteImageSyntax.first(
      '![Второй](../../Attachments/second.png)',
    )!.toMarkdown(
      presentation: const NoteImagePresentation(
        caption: 'Вторая структура',
        figureId: 'second-structure',
      ),
    );
    const table = ScientificTableDraft(
      id: 'conditions',
      caption: 'Условия эксперимента',
      columns: 2,
      rows: 1,
    );
    final source = '$firstImage\n\n${table.toMarkdown()}\n\n$secondImage';

    final index = ScientificReferenceSyntax.index(source);

    expect(index.objects.map((object) => object.label), [
      'Рисунок 1',
      'Таблица 1',
      'Рисунок 2',
    ]);
    expect(
      index.objectFor(ScientificObjectType.figure, 'second-structure')?.number,
      2,
    );
    expect(
      index.objectFor(ScientificObjectType.table, 'conditions')?.number,
      1,
    );
  });

  test('renders stable cross references and reports missing targets', () {
    final image = NoteImageSyntax.first(
      '![График](../../Attachments/plot.png)',
    )!.toMarkdown(
      presentation: const NoteImagePresentation(
        caption: 'RMSD траектория',
        figureId: 'rmsd-plot',
      ),
    );
    final source = '$image\n\nСм. @fig(rmsd-plot) и @tbl(missing-table).';
    final index = ScientificReferenceSyntax.index(source);

    final rendered = ScientificReferenceSyntax.renderMarkdownChunk(
      source,
      index,
    );

    expect(rendered, contains('**рисунок 1**'));
    expect(rendered, contains('[нет объекта: таблица missing-table]'));
    expect(index.brokenCrossReferences, hasLength(1));
  });

  test('detects duplicate identifiers without choosing an arbitrary target', () {
    final imageA = NoteImageSyntax.first(
      '![A](../../Attachments/a.png)',
    )!.toMarkdown(
      presentation: const NoteImagePresentation(figureId: 'same-id'),
    );
    final imageB = NoteImageSyntax.first(
      '![B](../../Attachments/b.png)',
    )!.toMarkdown(
      presentation: const NoteImagePresentation(figureId: 'same-id'),
    );
    final source = '$imageA\n\n$imageB\n\n@fig(same-id)';

    final index = ScientificReferenceSyntax.index(source);

    expect(index.duplicateKeys, contains('figure:same-id'));
    expect(
      index.objectFor(ScientificObjectType.figure, 'same-id'),
      isNull,
    );
    expect(index.ambiguousCrossReferences, hasLength(1));
  });

  test('scientific table remains one portable Markdown block', () {
    const draft = ScientificTableDraft(
      id: 'md-conditions',
      caption: 'Параметры МД',
      columns: 3,
      rows: 2,
    );
    final markdown = draft.toMarkdown();
    final tables = ScientificReferenceSyntax.tables(markdown);

    expect(tables, hasLength(1));
    expect(tables.single.id, 'md-conditions');
    expect(tables.single.caption, 'Параметры МД');
    expect(markdown, contains('| Столбец 1 | Столбец 2 | Столбец 3 |'));
    expect(markdown, contains('<!-- chronicle-table'));
  });

  test('scientific syntax inside fenced code is ignored', () {
    const source = '''```markdown
@fig(fake)
<!-- chronicle-table id=fake caption=Fake -->
| A | B |
| --- | --- |
| 1 | 2 |
```''';

    final index = ScientificReferenceSyntax.index(source);

    expect(index.objects, isEmpty);
    expect(index.crossReferences, isEmpty);
  });

  test('reference number follows object order without rewriting its token', () {
    final imageA = NoteImageSyntax.first(
      '![A](../../Attachments/a.png)',
    )!.toMarkdown(
      presentation: const NoteImagePresentation(figureId: 'a'),
    );
    final imageB = NoteImageSyntax.first(
      '![B](../../Attachments/b.png)',
    )!.toMarkdown(
      presentation: const NoteImagePresentation(figureId: 'b'),
    );
    final source = '$imageB\n\n$imageA\n\nСм. @fig(b).';
    final index = ScientificReferenceSyntax.index(source);

    expect(
      ScientificReferenceSyntax.renderMarkdownChunk(source, index),
      contains('См. **рисунок 1**.'),
    );
    expect(source, contains('@fig(b)'));
  });
}
