import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:chronicle/features/notes/note_data_import.dart';
import 'package:chronicle/vault/vault_models.dart';

void main() {
  test('CSV with UTF-8 BOM becomes a scientific table', () {
    final file = NoteDataImportFile(
      name: 'RMSD results.csv',
      bytes: Uint8List.fromList(<int>[
        0xef,
        0xbb,
        0xbf,
        ...utf8.encode('frame,rmsd\n0,0.12\n1,0.18'),
      ]),
    );

    final table = NoteDataImport.tableModelFor(
      file: file,
      existingObjectKeys: const <String>{'table:rmsd-results'},
    );

    expect(table.id, 'rmsd-results-2');
    expect(table.caption, 'RMSD results');
    expect(table.headers, <String>['frame', 'rmsd']);
    expect(table.rows, <List<String>>[
      <String>['0', '0.12'],
      <String>['1', '0.18'],
    ]);
  });

  test('table import keeps a link to the original source file', () {
    final file = NoteDataImportFile(
      name: 'sample.tsv',
      bytes: Uint8List.fromList(utf8.encode('sample\tvalue\nA\t10')),
    );
    final table = NoteDataImport.tableModelFor(
      file: file,
      existingObjectKeys: const <String>{},
    );
    final markdown = NoteDataImport.buildTableImportMarkdown(
      title: 'Измерения',
      table: table,
      source: NoteDataImportAttachment(
        sourceName: file.name,
        result: _attachment(
          markdown: '[sample.tsv](../../Attachments/sample.tsv)',
        ),
      ),
    );

    expect(markdown, contains('## Измерения'));
    expect(markdown, contains('<!-- chronicle-table id=sample'));
    expect(markdown, contains('**Исходный файл:** [sample.tsv]'));
  });

  test('bundle can preview images and list other files', () {
    final markdown = NoteDataImport.buildAttachmentBundleMarkdown(
      title: 'MD results',
      showImagePreviews: true,
      attachments: <NoteDataImportAttachment>[
        NoteDataImportAttachment(
          sourceName: 'plot.png',
          result: _attachment(
            markdown: '![plot.png](../../Attachments/plot.png)',
            isImage: true,
          ),
        ),
        NoteDataImportAttachment(
          sourceName: 'values.csv',
          result: _attachment(
            markdown: '[values.csv](../../Attachments/values.csv)',
          ),
        ),
      ],
    );

    expect(markdown, contains('### Изображения'));
    expect(markdown, contains('![plot.png]'));
    expect(markdown, contains('### Файлы'));
    expect(markdown, contains('- [values.csv]'));
  });

  test('image becomes a normal link when previews are disabled', () {
    final markdown = NoteDataImport.buildAttachmentBundleMarkdown(
      title: 'Raw files',
      showImagePreviews: false,
      attachments: <NoteDataImportAttachment>[
        NoteDataImportAttachment(
          sourceName: 'plot.png',
          result: _attachment(
            markdown: '![plot.png](../../Attachments/plot.png)',
            isImage: true,
          ),
        ),
      ],
    );

    expect(markdown, contains('- [plot.png]'));
    expect(markdown, isNot(contains('![plot.png]')));
  });
}

AttachmentImportResult _attachment({
  required String markdown,
  bool isImage = false,
}) {
  return AttachmentImportResult(
    fileName: 'stored-file',
    relativePath: 'Attachments/stored-file',
    markdown: markdown,
    byteLength: 10,
    isImage: isImage,
    sha256: 'hash',
    mimeType: isImage ? 'image/png' : 'text/csv',
    alreadyExisted: false,
  );
}
