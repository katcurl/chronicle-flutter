import 'dart:convert';

import 'package:chronicle/features/publications/publication_document_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const exporter = PublicationDocumentExporter();

  test('DOCX export contains Open XML document text', () async {
    final payload = await exporter.docx(
      title: 'ORF9b report',
      markdown: '# ORF9b report\n\n## Results\n\nMetastable state.',
    );

    expect(payload.extension, 'docx');
    expect(payload.bytes.take(2), orderedEquals(utf8.encode('PK')));
    expect(payload.bytes, isNotEmpty);
  });

  test('PDF export uses a local Unicode font and creates a PDF', () async {
    final payload = await exporter.pdf(
      title: 'Отчёт ORF9b',
      markdown: '# Отчёт ORF9b\n\n## Результаты\n\nМетастабильное состояние.',
    );

    expect(payload.fileName, 'Отчёт ORF9b.pdf');
    expect(payload.extension, 'pdf');
    expect(
      payload.bytes.take(5),
      orderedEquals(utf8.encode('%PDF-')),
    );
  });
}
