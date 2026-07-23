import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../notes/note_export.dart';

class PublicationDocumentExporter {
  const PublicationDocumentExporter();

  Future<ChronicleExportPayload> export({
    required ChronicleExportFormat format,
    required String title,
    required String markdown,
  }) {
    return switch (format) {
      ChronicleExportFormat.docx => docx(title: title, markdown: markdown),
      ChronicleExportFormat.pdf => pdf(title: title, markdown: markdown),
      _ => throw ArgumentError.value(
          format,
          'format',
          'PublicationDocumentExporter supports only DOCX and PDF.',
        ),
    };
  }
  Future<ChronicleExportPayload> docx({required String title,required String markdown}) async {
    final stem=NoteExportComposer.safeFileStem(title,fallback:'document'), body=StringBuffer();
    for(final p in _paragraphs(markdown)){final style=p.level==1?'<w:pStyle w:val="Title"/>':p.level>1?'<w:pStyle w:val="Heading${p.level.clamp(1,3)}"/>':'';body.writeln('<w:p><w:pPr>$style</w:pPr><w:r><w:t xml:space="preserve">${const HtmlEscape(HtmlEscapeMode.element).convert(p.text)}</w:t></w:r></w:p>');}
    final zip=StoredZipArchiveBuilder()
      ..addText('[Content_Types].xml','<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/></Types>')
      ..addText('_rels/.rels','<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>')
      ..addText('word/document.xml','<?xml version="1.0" encoding="UTF-8"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>$body<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134"/></w:sectPr></w:body></w:document>')
      ..addText('word/styles.xml','<?xml version="1.0" encoding="UTF-8"?><w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:rPr><w:sz w:val="22"/></w:rPr></w:style><w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:rPr><w:b/><w:sz w:val="36"/></w:rPr></w:style><w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:rPr><w:b/><w:sz w:val="28"/></w:rPr></w:style><w:style w:type="paragraph" w:styleId="Heading3"><w:name w:val="heading 3"/><w:rPr><w:b/><w:sz w:val="24"/></w:rPr></w:style></w:styles>');
    return ChronicleExportPayload(fileName:'$stem.docx',extension:'docx',bytes:zip.build(),assetCount:0,missingAttachments:const[]);
  }
  Future<ChronicleExportPayload> pdf({required String title,required String markdown}) async {
    final doc=pw.Document(), ps=_paragraphs(markdown), font=await _systemFont();
    doc.addPage(pw.MultiPage(pageFormat:PdfPageFormat.a4,margin:const pw.EdgeInsets.all(48),theme:pw.ThemeData.withFont(base:font,bold:font),build:(_)=>[for(final p in ps)if(p.level==1)pw.Header(level:0,child:pw.Text(p.text,style:pw.TextStyle(fontSize:22,fontWeight:pw.FontWeight.bold)))else if(p.level>1)pw.Header(level:p.level.clamp(1,3),text:p.text)else pw.Padding(padding:const pw.EdgeInsets.only(bottom:8),child:pw.Text(p.text))]));
    return ChronicleExportPayload(fileName:'${NoteExportComposer.safeFileStem(title,fallback:'document')}.pdf',extension:'pdf',bytes:Uint8List.fromList(await doc.save()),assetCount:0,missingAttachments:const[]);
  }
  Future<pw.Font> _systemFont() async {
    for (final candidate in const <String>[r'C:\Windows\Fonts\arial.ttf', r'C:\Windows\Fonts\calibri.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', '/System/Library/Fonts/Supplemental/Arial.ttf']) {
      final file = File(candidate);
      if (await file.exists()) { final bytes=await file.readAsBytes(); return pw.Font.ttf(bytes.buffer.asByteData(bytes.offsetInBytes,bytes.lengthInBytes)); }
    }
    throw StateError('Не найден системный шрифт с поддержкой Unicode для PDF.');
  }
  List<_P> _paragraphs(String md){final out=<_P>[];for(final raw in const LineSplitter().convert(md)){final s=raw.trim();if(s.isEmpty||s.startsWith('<!--'))continue;final h=RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(s);if(h!=null){out.add(_P(h.group(2)!,h.group(1)!.length));continue;}if(s.startsWith('|')&&s.endsWith('|')){if(RegExp(r'^\|[\s:|-]+\|$').hasMatch(s))continue;out.add(_P(s.split('|').where((x)=>x.trim().isNotEmpty).map((x)=>x.trim()).join('  |  '),0));continue;}out.add(_P(s.replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]*\)'),r'[Рисунок: $1]').replaceAll(RegExp(r'\[([^\]]+)\]\([^)]*\)'),r'$1').replaceAll(RegExp(r'[*_`>]'),'').replaceFirst(RegExp(r'^[-+]\s+'),'• '),0));}return out;}
}
class _P{const _P(this.text,this.level);final String text;final int level;}
