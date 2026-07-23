import 'dart:convert';
import 'dart:typed_data';

import 'package:chronicle/features/notes/note_export.dart';
import 'package:chronicle/features/publications/publication_document_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final png = Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );
  final exporter = PublicationDocumentExporter(
    readAttachment: (relativePath) async =>
        relativePath == 'Attachments/rmsd.png' ? png : null,
  );
  const markdown = '''# ORF9b report

## Results

The **metastable** state is *reversible*, ~~temporary~~ and uses `RMSD`.
See [source](https://example.org).

- First observation
- [x] Verified observation

> This is a quoted conclusion.

| State | Frames |
| --- | ---: |
| A | 1200 |

```dart
final state = "A";
```

---

![RMSD trajectory](Attachments/rmsd.png "chronicle-image width=75 align=center caption=Рисунок%201.%20RMSD%20trajectory")
''';

  test('DOCX preserves Markdown structure and embeds managed images', () async {
    final payload = await exporter.export(
      format: ChronicleExportFormat.docx,
      title: 'ORF9b report',
      markdown: markdown,
    );

    expect(payload.extension, 'docx');
    expect(payload.bytes.take(2), orderedEquals(utf8.encode('PK')));
    expect(payload.assetCount, 1);
    expect(payload.missingAttachments, isEmpty);

    final entries = StoredZipArchiveBuilder.readStoredEntries(payload.bytes);
    expect(entries, contains('word/document.xml'));
    expect(entries, contains('word/media/image1.png'));
    expect(entries, contains('word/_rels/document.xml.rels'));

    final documentXml = utf8.decode(entries['word/document.xml']!);
    final relationships = utf8.decode(
      entries['word/_rels/document.xml.rels']!,
    );
    expect(documentXml, contains('w:pStyle w:val="Heading1"'));
    expect(documentXml, contains('<w:b/>'));
    expect(documentXml, contains('<w:i/>'));
    expect(documentXml, contains('<w:strike/>'));
    expect(documentXml, contains('<w:tbl>'));
    expect(documentXml, contains('<w:drawing>'));
    expect(documentXml, contains('[x] Verified observation'));
    expect(documentXml, contains('Рисунок 1. RMSD trajectory'));
    expect(documentXml, isNot(contains('Рисунок%201.')));
    expect(relationships, contains('relationships/image'));
    expect(relationships, contains('relationships/hyperlink'));
  });

  test('PDF preserves Markdown content and embeds a managed PNG', () async {
    final payload = await exporter.export(
      format: ChronicleExportFormat.pdf,
      title: 'Отчёт ORF9b',
      markdown: markdown,
    );

    expect(payload.fileName, 'Отчёт ORF9b.pdf');
    expect(payload.extension, 'pdf');
    expect(payload.bytes.take(5), orderedEquals(utf8.encode('%PDF-')));
    expect(payload.assetCount, 1);
    expect(payload.missingAttachments, isEmpty);
  });

  test('missing images are reported instead of silently discarded', () async {
    final payload = await exporter.export(
      format: ChronicleExportFormat.docx,
      title: 'Missing image',
      markdown: '![Plot](Attachments/missing.png)',
    );

    expect(payload.assetCount, 0);
    expect(payload.missingAttachments, <String>['Attachments/missing.png']);
    final entries = StoredZipArchiveBuilder.readStoredEntries(payload.bytes);
    final documentXml = utf8.decode(entries['word/document.xml']!);
    expect(documentXml, contains('Не удалось встроить Plot'));
    expect(documentXml, contains('Attachments/missing.png'));
  });
}
