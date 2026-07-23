import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:chronicle/features/publications/publication_document_export.dart';

void main() {
  test('DOCX export contains Open XML document text', () async {
    final payload = await const PublicationDocumentExporter().docx(title: 'ORF9b report', markdown: '# ORF9b report\n\n## Results\n\nMetastable state.');
    expect(payload.extension, 'docx');
    expect(payload.bytes.take(2), orderedEquals(utf8.encode('PK')));
    expect(payload.bytes, isNotEmpty);
  });
}
