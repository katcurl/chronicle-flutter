import 'package:chronicle/features/notes/note_table_syntax.dart';
import 'package:chronicle/features/notes/scientific_reference_syntax.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scientific table round-trips cells, alignment and metadata', () {
    final model = NoteTableModel(
      id: 'nmr-conditions',
      caption: 'Условия ЯМР',
      headers: const ['Параметр', 'Значение | единица', 'Комментарий'],
      rows: const [
        ['Температура', '298 K', 'основной спектр'],
        ['Буфер', '20 mM Tris', 'pH 7.4\n10% D2O'],
      ],
      alignments: const [
        NoteTableAlignment.left,
        NoteTableAlignment.center,
        NoteTableAlignment.right,
      ],
    );

    final markdown = model.toMarkdown();
    final reference = ScientificReferenceSyntax.tables(markdown).single;
    final parsed = NoteTableSyntax.parseReference(reference);

    expect(parsed, isNotNull);
    expect(parsed!.id, 'nmr-conditions');
    expect(parsed.caption, 'Условия ЯМР');
    expect(parsed.headers, ['Параметр', 'Значение | единица', 'Комментарий']);
    expect(parsed.rows[1][2], 'pH 7.4\n10% D2O');
    expect(parsed.alignments, [
      NoteTableAlignment.left,
      NoteTableAlignment.center,
      NoteTableAlignment.right,
    ]);
  });

  test('parses a tab-separated range copied from a spreadsheet', () {
    final parsed = NoteTableSyntax.parseClipboard(
      'Образец\tКонцентрация\tСтатус\nORF9b\t0.8 mM\tготов\nNPM1\t0.3 mM\tочистка',
    );

    expect(parsed.columnCount, 3);
    expect(parsed.rows, [
      ['Образец', 'Концентрация', 'Статус'],
      ['ORF9b', '0.8 mM', 'готов'],
      ['NPM1', '0.3 mM', 'очистка'],
    ]);
  });

  test('parses quoted CSV and preserves delimiters inside cells', () {
    final parsed = NoteTableSyntax.parseClipboard(
      'Sample,Comment,Value\nORF9b,"two states, reversible",0.72',
    );

    expect(parsed.rows[1], ['ORF9b', 'two states, reversible', '0.72']);
  });

  test('single clipboard column is padded to a portable two-column table', () {
    final parsed = NoteTableSyntax.parseClipboard('A\nB\nC');

    expect(parsed.columnCount, 2);
    expect(parsed.rows, [
      ['A', ''],
      ['B', ''],
      ['C', ''],
    ]);
  });
}
