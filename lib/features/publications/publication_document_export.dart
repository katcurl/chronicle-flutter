import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:markdown/markdown.dart' as md;
import 'package:path/path.dart' as path;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../notes/note_export.dart';
import '../notes/note_columns_syntax.dart';
import '../notes/note_image_syntax.dart';

typedef PublicationAttachmentReader =
    Future<Uint8List?> Function(String relativePath);

class PublicationDocumentExporter {
  const PublicationDocumentExporter({this.readAttachment});

  final PublicationAttachmentReader? readAttachment;

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

  Future<ChronicleExportPayload> docx({
    required String title,
    required String markdown,
  }) async {
    final parsed = _MarkdownParser().parse(markdown);
    final resolved = await _resolveImages(parsed);
    final builder = _DocxBuilder(title: title, resolved: resolved);
    final stem = NoteExportComposer.safeFileStem(title, fallback: 'document');
    return ChronicleExportPayload(
      fileName: '$stem.docx',
      extension: 'docx',
      bytes: builder.build(),
      assetCount: resolved.assetCount,
      missingAttachments: resolved.missingAttachments,
    );
  }

  Future<ChronicleExportPayload> pdf({
    required String title,
    required String markdown,
  }) async {
    final parsed = _MarkdownParser().parse(markdown);
    final resolved = await _resolveImages(parsed);
    final font = await _systemFont();
    final document = pw.Document(
      title: title,
      creator: 'Chronicle',
      theme: pw.ThemeData.withFont(
        base: font,
        bold: font,
        italic: font,
        boldItalic: font,
      ),
    );
    final renderer = _PdfRenderer(resolved);
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 54),
        build: (_) => renderer.widgets(),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(
              fontSize: 8.5,
              color: PdfColors.grey600,
            ),
          ),
        ),
      ),
    );
    final stem = NoteExportComposer.safeFileStem(title, fallback: 'document');
    return ChronicleExportPayload(
      fileName: '$stem.pdf',
      extension: 'pdf',
      bytes: Uint8List.fromList(await document.save()),
      assetCount: resolved.assetCount,
      missingAttachments: resolved.missingAttachments,
    );
  }

  Future<_ResolvedMarkdown> _resolveImages(_MarkdownDocument document) async {
    final images = <String, _ResolvedImage?>{};
    final missing = <String>[];
    final missingSet = <String>{};
    var assetCount = 0;

    for (final image in document.images) {
      if (images.containsKey(image.target)) {
        continue;
      }
      final resolved = await _loadImage(image.target);
      images[image.target] = resolved;
      if (resolved == null) {
        if (missingSet.add(image.target)) {
          missing.add(image.target);
        }
      } else {
        assetCount += 1;
      }
    }

    return _ResolvedMarkdown(
      document: document,
      images: images,
      assetCount: assetCount,
      missingAttachments: List<String>.unmodifiable(missing),
    );
  }

  Future<_ResolvedImage?> _loadImage(String target) async {
    final dataImage = _decodeDataImage(target);
    if (dataImage != null) {
      return dataImage;
    }

    final relativePath = _managedAttachmentPath(target);
    final reader = readAttachment;
    if (relativePath == null || reader == null) {
      return null;
    }
    final bytes = await reader(relativePath);
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    final extension = _imageExtension(relativePath, bytes);
    if (extension == null) {
      return null;
    }
    return _ResolvedImage(
      bytes: bytes,
      extension: extension,
      mimeType: _imageMimeType(extension),
      size: _pixelSize(bytes, extension),
    );
  }

  static _ResolvedImage? _decodeDataImage(String target) {
    final match = RegExp(
      r'^data:(image/[a-zA-Z0-9.+-]+);base64,(.+)$',
      dotAll: true,
    ).firstMatch(target.trim());
    if (match == null) {
      return null;
    }
    try {
      final bytes = Uint8List.fromList(base64Decode(match.group(2)!));
      final extension = switch (match.group(1)!.toLowerCase()) {
        'image/png' => 'png',
        'image/jpeg' => 'jpg',
        'image/gif' => 'gif',
        'image/webp' => 'webp',
        'image/svg+xml' => 'svg',
        'image/bmp' => 'bmp',
        _ => null,
      };
      if (extension == null) {
        return null;
      }
      return _ResolvedImage(
        bytes: bytes,
        extension: extension,
        mimeType: _imageMimeType(extension),
        size: _pixelSize(bytes, extension),
      );
    } on Object {
      return null;
    }
  }

  static String? _managedAttachmentPath(String target) {
    var decoded = target.trim();
    try {
      decoded = Uri.decodeComponent(decoded);
    } on Object {
      // Preserve malformed targets so they can be reported as missing.
    }
    decoded = decoded.replaceAll('\\', '/');
    final marker = decoded.indexOf('Attachments/');
    if (marker < 0) {
      return null;
    }
    final normalized = decoded.substring(marker).split(RegExp(r'[?#]')).first;
    final segments = normalized.split('/');
    if (segments.length < 2 ||
        segments.any((segment) => segment.isEmpty || segment == '..')) {
      return null;
    }
    return normalized;
  }

  static Future<pw.Font> _systemFont() async {
    for (final candidate in const <String>[
      r'C:\Windows\Fonts\arial.ttf',
      r'C:\Windows\Fonts\calibri.ttf',
      r'C:\Windows\Fonts\segoeui.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
      '/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf',
      '/System/Library/Fonts/Supplemental/Arial.ttf',
    ]) {
      final file = File(candidate);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        return pw.Font.ttf(
          bytes.buffer.asByteData(bytes.offsetInBytes, bytes.lengthInBytes),
        );
      }
    }
    throw StateError(
      'Не найден системный шрифт с поддержкой Unicode для PDF.',
    );
  }
}

class _MarkdownParser {
  _MarkdownDocument parse(String source) {
    final blocks = <_MarkdownBlock>[];
    _appendRichSource(source, blocks);
    if (blocks.isEmpty && source.trim().isNotEmpty) {
      blocks.add(_ParagraphBlock(<_Inline>[_Inline.text(source.trim())]));
    }
    return _MarkdownDocument(List<_MarkdownBlock>.unmodifiable(blocks));
  }

  void _appendRichSource(String source, List<_MarkdownBlock> output) {
    for (final chunk in _splitExportDocument(source)) {
      switch (chunk.kind) {
        case _ExportChunkKind.markdown:
          _appendMarkdownSource(chunk.markdown, output);
          break;
        case _ExportChunkKind.math:
          output.add(_MathBlock(chunk.math));
          break;
        case _ExportChunkKind.columns:
          final reference = chunk.columns!;
          output.add(
            _ColumnsBlock(
              widths: reference.widths,
              columns: <List<_MarkdownBlock>>[
                for (final column in reference.columns)
                  parse(column.markdown).blocks,
              ],
            ),
          );
          break;
      }
    }
  }

  void _appendMarkdownSource(String source, List<_MarkdownBlock> output) {
    if (source.trim().isEmpty) {
      return;
    }
    final nodes = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      inlineSyntaxes: <md.InlineSyntax>[_ExportInlineMathSyntax()],
      encodeHtml: false,
    ).parse(source);
    _appendNodes(nodes, output);
  }

  void _appendNodes(List<md.Node>? nodes, List<_MarkdownBlock> output) {
    if (nodes == null) {
      return;
    }
    for (final node in nodes) {
      if (node is md.Text) {
        if (node.text.trim().isNotEmpty) {
          output.add(_ParagraphBlock(<_Inline>[_Inline.text(node.text)]));
        }
        continue;
      }
      if (node is! md.Element) {
        continue;
      }
      final heading = RegExp(r'^h([1-6])$').firstMatch(node.tag);
      if (heading != null) {
        output.add(
          _HeadingBlock(
            int.parse(heading.group(1)!),
            _inlineNodes(node.children),
          ),
        );
        continue;
      }
      switch (node.tag) {
        case 'p':
          _appendParagraph(node.children, output);
          break;
        case 'blockquote':
          final quoted = <_MarkdownBlock>[];
          _appendNodes(node.children, quoted);
          output.add(_QuoteBlock(quoted));
          break;
        case 'ul':
          _appendList(node, output, ordered: false, depth: 0);
          break;
        case 'ol':
          _appendList(node, output, ordered: true, depth: 0);
          break;
        case 'pre':
          final codeNode = node.children
              ?.whereType<md.Element>()
              .where((element) => element.tag == 'code')
              .firstOrNull;
          output.add(
            _CodeBlock(
              codeNode?.textContent ?? node.textContent,
              language: _codeLanguage(codeNode),
            ),
          );
          break;
        case 'hr':
          output.add(const _HorizontalRuleBlock());
          break;
        case 'table':
          output.add(_table(node));
          break;
        default:
          final text = node.textContent;
          if (text.trim().isNotEmpty) {
            output.add(_ParagraphBlock(_inlineNodes(node.children)));
          }
      }
    }
  }

  void _appendParagraph(
    List<md.Node>? nodes,
    List<_MarkdownBlock> output,
  ) {
    final inlines = _inlineNodes(nodes);
    final buffer = <_Inline>[];

    void flush() {
      if (buffer.any((inline) => inline.plainText.trim().isNotEmpty)) {
        output.add(_ParagraphBlock(List<_Inline>.from(buffer)));
      }
      buffer.clear();
    }

    for (final inline in inlines) {
      if (inline.image == null) {
        buffer.add(inline);
      } else {
        flush();
        output.add(_ImageBlock(inline.image!));
      }
    }
    flush();
  }

  void _appendList(
    md.Element list,
    List<_MarkdownBlock> output, {
    required bool ordered,
    required int depth,
  }) {
    var number = int.tryParse(list.attributes['start'] ?? '') ?? 1;
    final children = list.children ?? const <md.Node>[];
    for (final child in children) {
      if (child is! md.Element || child.tag != 'li') {
        continue;
      }
      final itemInlines = <_Inline>[];
      final nested = <md.Element>[];
      for (final itemChild in child.children ?? const <md.Node>[]) {
        if (itemChild is md.Element &&
            (itemChild.tag == 'ul' || itemChild.tag == 'ol')) {
          nested.add(itemChild);
        } else if (itemChild is md.Element && itemChild.tag == 'p') {
          itemInlines.addAll(_inlineNodes(itemChild.children));
        } else {
          itemInlines.addAll(_inlineNodes(<md.Node>[itemChild]));
        }
      }
      output.add(
        _ListItemBlock(
          ordered: ordered,
          number: ordered ? number : null,
          depth: depth,
          inlines: itemInlines,
        ),
      );
      if (ordered) {
        number += 1;
      }
      for (final nestedList in nested) {
        _appendList(
          nestedList,
          output,
          ordered: nestedList.tag == 'ol',
          depth: depth + 1,
        );
      }
    }
  }

  _TableBlock _table(md.Element table) {
    final rows = <_TableRow>[];

    void collect(md.Node node, {required bool header}) {
      if (node is! md.Element) {
        return;
      }
      if (node.tag == 'tr') {
        final cells = <List<_Inline>>[];
        for (final child in node.children ?? const <md.Node>[]) {
          if (child is md.Element &&
              (child.tag == 'th' || child.tag == 'td')) {
            cells.add(_inlineNodes(child.children));
          }
        }
        if (cells.isNotEmpty) {
          rows.add(_TableRow(cells, header: header));
        }
        return;
      }
      final nestedHeader = header || node.tag == 'thead';
      for (final child in node.children ?? const <md.Node>[]) {
        collect(child, header: nestedHeader);
      }
    }

    collect(table, header: false);
    return _TableBlock(rows);
  }

  List<_Inline> _inlineNodes(
    List<md.Node>? nodes, {
    _InlineStyle style = const _InlineStyle(),
  }) {
    final result = <_Inline>[];
    for (final node in nodes ?? const <md.Node>[]) {
      if (node is md.Text) {
        result.add(_Inline.text(node.text, style: style));
        continue;
      }
      if (node is! md.Element) {
        continue;
      }
      switch (node.tag) {
        case 'strong':
        case 'b':
          result.addAll(
            _inlineNodes(node.children, style: style.copyWith(bold: true)),
          );
          break;
        case 'em':
        case 'i':
          result.addAll(
            _inlineNodes(node.children, style: style.copyWith(italic: true)),
          );
          break;
        case 'del':
        case 's':
          result.addAll(
            _inlineNodes(node.children, style: style.copyWith(strike: true)),
          );
          break;
        case 'code':
          result.add(
            _Inline.text(
              node.textContent,
              style: style.copyWith(code: true),
            ),
          );
          break;
        case 'chronicle-math':
          result.add(_Inline.math(node.textContent, style: style));
          break;
        case 'a':
          result.addAll(
            _inlineNodes(
              node.children,
              style: style.copyWith(link: node.attributes['href']),
            ),
          );
          break;
        case 'br':
          result.add(_Inline.text('\n', style: style));
          break;
        case 'img':
          final target = node.attributes['src'] ?? '';
          final title = node.attributes['title'];
          var presentation = NoteImagePresentation.fromMarkdownTitle(title);
          if ((title ?? '').trim().isNotEmpty &&
              !(title ?? '').trim().startsWith(NoteImageSyntax.metadataPrefix)) {
            presentation = presentation.copyWith(caption: title!.trim());
          }
          presentation = presentation.copyWith(
            caption: NoteImageSyntax.decodeMetadataValue(
              presentation.caption,
            ),
            figureId: NoteImageSyntax.decodeMetadataValue(
              presentation.figureId,
            ),
          );
          result.add(
            _Inline.image(
              _MarkdownImage(
                target: target,
                alt: node.attributes['alt'] ?? node.textContent,
                presentation: presentation,
              ),
            ),
          );
          break;
        case 'input':
          final checked = node.attributes.containsKey('checked');
          result.add(_Inline.text(checked ? '[x] ' : '[ ] ', style: style));
          break;
        default:
          result.addAll(_inlineNodes(node.children, style: style));
      }
    }
    return result;
  }

  static String _codeLanguage(md.Element? codeNode) {
    final className = codeNode?.attributes['class'] ?? '';
    if (className.startsWith('language-')) {
      return className.substring('language-'.length);
    }
    return codeNode?.attributes['data-metadata'] ?? '';
  }
}

enum _ExportChunkKind { markdown, math, columns }

class _ExportChunk {
  const _ExportChunk.markdown(this.markdown)
      : kind = _ExportChunkKind.markdown,
        math = '',
        columns = null;

  const _ExportChunk.math(this.math)
      : kind = _ExportChunkKind.math,
        markdown = '',
        columns = null;

  const _ExportChunk.columns(this.columns)
      : kind = _ExportChunkKind.columns,
        markdown = '',
        math = '';

  final _ExportChunkKind kind;
  final String markdown;
  final String math;
  final NoteColumnsReference? columns;
}

class _ExportToken {
  const _ExportToken({
    required this.start,
    required this.end,
    required this.kind,
    this.math = '',
    this.columns,
  });

  final int start;
  final int end;
  final _ExportChunkKind kind;
  final String math;
  final NoteColumnsReference? columns;
}

List<_ExportChunk> _splitExportDocument(String source) {
  final tokens = <_ExportToken>[];
  final mathPattern = RegExp(r'(\\\[[\s\S]*?\\\]|\$\$[\s\S]*?\$\$)');

  for (final columns in NoteColumnsSyntax.all(source)) {
    tokens.add(
      _ExportToken(
        start: columns.start,
        end: columns.end,
        kind: _ExportChunkKind.columns,
        columns: columns,
      ),
    );
  }
  for (final match in mathPattern.allMatches(source)) {
    if (_isInsideExportCode(source, match.start)) {
      continue;
    }
    final raw = match.group(0) ?? '';
    tokens.add(
      _ExportToken(
        start: match.start,
        end: match.end,
        kind: _ExportChunkKind.math,
        math: raw.length >= 4
            ? raw.substring(2, raw.length - 2).trim()
            : raw,
      ),
    );
  }

  tokens.sort((left, right) {
    final byStart = left.start.compareTo(right.start);
    if (byStart != 0) {
      return byStart;
    }
    return right.end.compareTo(left.end);
  });

  final result = <_ExportChunk>[];
  var cursor = 0;
  for (final token in tokens) {
    if (token.start < cursor) {
      continue;
    }
    if (token.start > cursor) {
      result.add(_ExportChunk.markdown(source.substring(cursor, token.start)));
    }
    switch (token.kind) {
      case _ExportChunkKind.markdown:
        break;
      case _ExportChunkKind.math:
        result.add(_ExportChunk.math(token.math));
        break;
      case _ExportChunkKind.columns:
        result.add(_ExportChunk.columns(token.columns));
        break;
    }
    cursor = token.end;
  }
  if (cursor < source.length) {
    result.add(_ExportChunk.markdown(source.substring(cursor)));
  }
  if (result.isEmpty) {
    result.add(_ExportChunk.markdown(source));
  }
  return result;
}

bool _isInsideExportCode(String source, int offset) {
  final before = source.substring(0, offset);
  final fenceCount = RegExp(
    r'^[ \t]*(?:```|~~~)',
    multiLine: true,
  ).allMatches(before).length;
  if (fenceCount.isOdd) {
    return true;
  }

  final lineStart =
      source.lastIndexOf('\n', offset == 0 ? 0 : offset - 1) + 1;
  final linePrefix = source.substring(lineStart, offset);
  var backticks = 0;
  for (var index = 0; index < linePrefix.length; index += 1) {
    if (linePrefix.codeUnitAt(index) == 0x60 &&
        (index == 0 || linePrefix.codeUnitAt(index - 1) != 0x5c)) {
      backticks += 1;
    }
  }
  return backticks.isOdd;
}

class _ExportInlineMathSyntax extends md.InlineSyntax {
  _ExportInlineMathSyntax()
      : super(r'\$([^$\n]+)\$', startCharacter: 0x24);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(
      md.Element.text('chronicle-math', match.group(1)?.trim() ?? ''),
    );
    return true;
  }
}

class _MathText {
  const _MathText._();

  static const Map<String, String> _commands = <String, String>{
    r'\alpha': 'α',
    r'\beta': 'β',
    r'\gamma': 'γ',
    r'\delta': 'δ',
    r'\epsilon': 'ε',
    r'\varepsilon': 'ε',
    r'\zeta': 'ζ',
    r'\eta': 'η',
    r'\theta': 'θ',
    r'\vartheta': 'ϑ',
    r'\iota': 'ι',
    r'\kappa': 'κ',
    r'\lambda': 'λ',
    r'\mu': 'μ',
    r'\nu': 'ν',
    r'\xi': 'ξ',
    r'\pi': 'π',
    r'\rho': 'ρ',
    r'\sigma': 'σ',
    r'\tau': 'τ',
    r'\upsilon': 'υ',
    r'\phi': 'φ',
    r'\varphi': 'ϕ',
    r'\chi': 'χ',
    r'\psi': 'ψ',
    r'\omega': 'ω',
    r'\Gamma': 'Γ',
    r'\Delta': 'Δ',
    r'\Theta': 'Θ',
    r'\Lambda': 'Λ',
    r'\Xi': 'Ξ',
    r'\Pi': 'Π',
    r'\Sigma': 'Σ',
    r'\Phi': 'Φ',
    r'\Psi': 'Ψ',
    r'\Omega': 'Ω',
    r'\pm': '±',
    r'\mp': '∓',
    r'\times': '×',
    r'\cdot': '·',
    r'\leq': '≤',
    r'\geq': '≥',
    r'\neq': '≠',
    r'\approx': '≈',
    r'\sim': '∼',
    r'\infty': '∞',
    r'\rightarrow': '→',
    r'\leftarrow': '←',
    r'\leftrightarrow': '↔',
    r'\Rightarrow': '⇒',
    r'\Leftarrow': '⇐',
    r'\Leftrightarrow': '⇔',
    r'\partial': '∂',
    r'\nabla': '∇',
    r'\sum': '∑',
    r'\prod': '∏',
    r'\int': '∫',
    r'\degree': '°',
  };

  static const Map<String, String> _superscripts = <String, String>{
    '0': '⁰',
    '1': '¹',
    '2': '²',
    '3': '³',
    '4': '⁴',
    '5': '⁵',
    '6': '⁶',
    '7': '⁷',
    '8': '⁸',
    '9': '⁹',
    '+': '⁺',
    '-': '⁻',
    '=': '⁼',
    '(': '⁽',
    ')': '⁾',
  };

  static const Map<String, String> _subscripts = <String, String>{
    '0': '₀',
    '1': '₁',
    '2': '₂',
    '3': '₃',
    '4': '₄',
    '5': '₅',
    '6': '₆',
    '7': '₇',
    '8': '₈',
    '9': '₉',
    '+': '₊',
    '-': '₋',
    '=': '₌',
    '(': '₍',
    ')': '₎',
  };

  static String normalize(String source) {
    var value = source.trim();
    value = _replaceRepeated(
      value,
      RegExp(r'\\frac\s*\{([^{}]*)\}\s*\{([^{}]*)\}'),
      (match) =>
          '(${normalize(match.group(1)!)})⁄(${normalize(match.group(2)!)})',
    );
    value = _replaceRepeated(
      value,
      RegExp(r'\\sqrt\s*\{([^{}]*)\}'),
      (match) => '√(${normalize(match.group(1)!)})',
    );
    value = _replaceRepeated(
      value,
      RegExp(r'\\(?:mathrm|mathbf|mathit|text|operatorname)\s*\{([^{}]*)\}'),
      (match) => match.group(1)!,
    );
    for (final entry in _commands.entries) {
      value = value.replaceAll(entry.key, entry.value);
    }
    value = value
        .replaceAll(RegExp(r'\\(?:left|right)'), '')
        .replaceAll(RegExp(r'\\[,;:! ]'), ' ')
        .replaceAll(r'\,', ' ')
        .replaceAll(r'\;', ' ')
        .replaceAll(r'\:', ' ')
        .replaceAll(r'\!', '')
        .replaceAll(r'\ ', ' ');
    value = _replaceScripts(value, '^', _superscripts);
    value = _replaceScripts(value, '_', _subscripts);
    value = value
        .replaceAllMapped(
          RegExp(r'\\([A-Za-z]+)'),
          (match) => match.group(1) ?? '',
        )
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
    return value.isEmpty ? source.trim() : value;
  }

  static String _replaceRepeated(
    String value,
    RegExp pattern,
    String Function(RegExpMatch match) replacement,
  ) {
    var current = value;
    while (true) {
      final match = pattern.firstMatch(current);
      if (match == null) {
        return current;
      }
      current = current.replaceRange(
        match.start,
        match.end,
        replacement(match),
      );
    }
  }

  static String _replaceScripts(
    String value,
    String marker,
    Map<String, String> alphabet,
  ) {
    final pattern = RegExp(
      '${RegExp.escape(marker)}(?:\\{([^{}]+)\\}|([A-Za-z0-9+\\-=()]))',
    );
    return value.replaceAllMapped(pattern, (match) {
      final content = match.group(1) ?? match.group(2) ?? '';
      final converted = StringBuffer();
      for (final rune in content.runes) {
        final character = String.fromCharCode(rune);
        final mapped = alphabet[character];
        if (mapped == null) {
          return '$marker($content)';
        }
        converted.write(mapped);
      }
      return converted.toString();
    });
  }
}


class _DocxBuilder {
  _DocxBuilder({required this.title, required this.resolved});

  final String title;
  final _ResolvedMarkdown resolved;
  final StoredZipArchiveBuilder _archive = StoredZipArchiveBuilder();
  final List<String> _relationships = <String>[];
  final Map<String, String> _imageRelationshipByTarget = <String, String>{};
  final Map<String, String> _hyperlinkRelationshipByTarget = <String, String>{};
  final Map<String, String> _contentTypes = <String, String>{};
  var _nextRelationship = 1;
  var _nextImage = 1;
  var _nextDrawing = 1;

  Uint8List build() {
    final body = StringBuffer();
    for (final block in resolved.document.blocks) {
      _writeBlock(block, body);
    }
    final generated = DateTime.now().toUtc().toIso8601String();

    _archive
      ..addText('[Content_Types].xml', _contentTypesXml())
      ..addText('_rels/.rels', _packageRelationshipsXml())
      ..addText('word/document.xml', _documentXml(body.toString()))
      ..addText('word/styles.xml', _stylesXml())
      ..addText(
        'word/_rels/document.xml.rels',
        _documentRelationshipsXml(),
      )
      ..addText('docProps/core.xml', _corePropertiesXml(generated))
      ..addText('docProps/app.xml', _appPropertiesXml());
    return _archive.build();
  }

  void _writeBlock(_MarkdownBlock block, StringBuffer output) {
    if (block is _ParagraphBlock) {
      output.write(_paragraph(block.inlines));
      return;
    }
    if (block is _HeadingBlock) {
      output.write(
        _paragraph(block.inlines, style: 'Heading${block.level}'),
      );
      return;
    }
    if (block is _ListItemBlock) {
      final prefix = block.ordered ? '${block.number}. ' : '• ';
      output.write(
        _paragraph(
          <_Inline>[_Inline.text(prefix), ...block.inlines],
          leftIndent: 360 + block.depth * 360,
          hangingIndent: 240,
        ),
      );
      return;
    }
    if (block is _CodeBlock) {
      final label = block.language.trim().isEmpty
          ? ''
          : '${block.language.trim()}\n';
      output.write(
        _paragraph(
          <_Inline>[
            _Inline.text(
              '$label${block.code}',
              style: const _InlineStyle(code: true),
            ),
          ],
          style: 'Code',
        ),
      );
      return;
    }
    if (block is _HorizontalRuleBlock) {
      output.write(
        '<w:p><w:pPr><w:pBdr><w:bottom w:val="single" '
        'w:sz="8" w:space="1" w:color="B7B7B7"/>'
        '</w:pBdr></w:pPr></w:p>',
      );
      return;
    }
    if (block is _MathBlock) {
      output.write(_displayMath(block.source));
      return;
    }
    if (block is _ColumnsBlock) {
      output.write(_columns(block));
      return;
    }
    if (block is _ImageBlock) {
      output.write(_image(block.image));
      return;
    }
    if (block is _TableBlock) {
      output.write(_table(block));
      return;
    }
    if (block is _QuoteBlock) {
      for (final child in block.children) {
        if (child is _ParagraphBlock) {
          output.write(_paragraph(child.inlines, style: 'Quote'));
        } else {
          _writeBlock(child, output);
        }
      }
    }
  }

  String _paragraph(
    List<_Inline> inlines, {
    String? style,
    int? leftIndent,
    int? hangingIndent,
  }) {
    final properties = StringBuffer();
    if (style != null) {
      properties.write('<w:pStyle w:val="${_xml(style)}"/>');
    }
    if (leftIndent != null || hangingIndent != null) {
      properties.write(
        '<w:ind${leftIndent == null ? '' : ' w:left="$leftIndent"'}'
        '${hangingIndent == null ? '' : ' w:hanging="$hangingIndent"'}/>',
      );
    }
    final runs = StringBuffer();
    for (final inline in inlines) {
      final mathSource = inline.math;
      if (mathSource != null) {
        runs.write(_inlineMath(mathSource));
        continue;
      }
      final image = inline.image;
      if (image == null) {
        runs.write(_run(inline));
        continue;
      }
      final resolvedImage = resolved.images[image.target];
      if (resolvedImage == null) {
        runs.write(_missingImageRun(image));
      } else {
        runs.write(_inlineImageRun(image, resolvedImage));
      }
    }
    return '<w:p><w:pPr>$properties</w:pPr>$runs</w:p>';
  }

  String _run(_Inline inline) {
    final style = inline.style;
    final properties = StringBuffer();
    if (style.bold) {
      properties.write('<w:b/>');
    }
    if (style.italic) {
      properties.write('<w:i/>');
    }
    if (style.strike) {
      properties.write('<w:strike/>');
    }
    if (style.code) {
      properties
        ..write('<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas"/>')
        ..write('<w:shd w:val="clear" w:fill="EEEEEE"/>');
    }
    if (style.link != null) {
      properties
        ..write('<w:color w:val="0563C1"/>')
        ..write('<w:u w:val="single"/>');
    }
    final content = inline.text
        .split('\n')
        .map((part) => '<w:t xml:space="preserve">${_xml(part)}</w:t>')
        .join('<w:br/>');
    final run = '<w:r><w:rPr>$properties</w:rPr>$content</w:r>';
    final link = style.link;
    if (link == null || link.trim().isEmpty) {
      return run;
    }
    final relationship = _hyperlinkRelationship(link);
    return '<w:hyperlink r:id="$relationship" w:history="1">$run</w:hyperlink>';
  }

  String _inlineMath(String source) {
    return '<m:oMath>${_mathRun(source)}</m:oMath>';
  }

  String _displayMath(String source) {
    return '<m:oMathPara><m:oMath>${_mathRun(source)}</m:oMath></m:oMathPara>';
  }

  String _mathRun(String source) {
    final visible = _MathText.normalize(source);
    return '<m:r><m:rPr><m:sty m:val="p"/></m:rPr>'
        '<m:t>${_xml(visible)}</m:t></m:r>';
  }

  String _columns(_ColumnsBlock block) {
    if (block.columns.length < 2 || block.columns.length > 3) {
      return '';
    }
    final widths = NoteColumnsSyntax.normalizeWidths(
      block.widths,
      block.columns.length,
    );
    final table = StringBuffer(
      '<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/>'
      '<w:tblLayout w:type="fixed"/>'
      '<w:tblCellMar><w:top w:w="80" w:type="dxa"/>'
      '<w:left w:w="100" w:type="dxa"/>'
      '<w:bottom w:w="80" w:type="dxa"/>'
      '<w:right w:w="100" w:type="dxa"/></w:tblCellMar>'
      '<w:tblBorders><w:top w:val="nil"/><w:left w:val="nil"/>'
      '<w:bottom w:val="nil"/><w:right w:val="nil"/>'
      '<w:insideH w:val="nil"/><w:insideV w:val="nil"/>'
      '</w:tblBorders></w:tblPr><w:tblGrid>',
    );
    for (final width in widths) {
      table.write('<w:gridCol w:w="${(9638 * width / 100).round()}"/>');
    }
    table.write('</w:tblGrid><w:tr>');
    for (var index = 0; index < block.columns.length; index += 1) {
      final cell = StringBuffer();
      for (final child in block.columns[index]) {
        _writeBlock(child, cell);
      }
      if (cell.isEmpty) {
        cell.write('<w:p/>');
      }
      table.write(
        '<w:tc><w:tcPr><w:tcW w:w="${widths[index] * 50}" '
        'w:type="pct"/><w:vAlign w:val="top"/></w:tcPr>$cell</w:tc>',
      );
    }
    table.write('</w:tr></w:tbl>');
    return table.toString();
  }

  String _image(_MarkdownImage image) {
    final resolvedImage = resolved.images[image.target];
    if (resolvedImage == null) {
      return '<w:p>${_missingImageRun(image)}</w:p>';
    }
    final width = (5486400 *
            image.presentation.widthPercent.clamp(20, 100).toDouble() /
            100)
        .round();
    final height = _drawingHeight(width, resolvedImage.size);
    final alignment = switch (image.presentation.alignment) {
      NoteImageAlignment.left => 'left',
      NoteImageAlignment.center => 'center',
      NoteImageAlignment.right => 'right',
    };
    final drawing = '<w:p><w:pPr><w:jc w:val="$alignment"/></w:pPr>'
        '${_drawingRun(image, resolvedImage, width: width, height: height)}</w:p>';
    final caption = image.presentation.caption.trim();
    if (caption.isEmpty) {
      return drawing;
    }
    return '$drawing${_paragraph(<_Inline>[_Inline.text(caption)], style: 'Caption')}';
  }

  String _inlineImageRun(
    _MarkdownImage image,
    _ResolvedImage resolvedImage,
  ) {
    final width = (1800000 *
            image.presentation.widthPercent.clamp(20, 100).toDouble() /
            100)
        .round();
    return _drawingRun(
      image,
      resolvedImage,
      width: width,
      height: _drawingHeight(width, resolvedImage.size),
    );
  }

  int _drawingHeight(int width, _PixelSize? sourceSize) {
    if (sourceSize == null || sourceSize.width <= 0) {
      return (width * 0.625).round();
    }
    return (width * sourceSize.height / sourceSize.width).round();
  }

  String _drawingRun(
    _MarkdownImage image,
    _ResolvedImage resolvedImage, {
    required int width,
    required int height,
  }) {
    final relationship = _imageRelationship(image.target, resolvedImage);
    final drawingId = _nextDrawing++;
    final description = image.alt.trim().isEmpty ? image.target : image.alt;
    return '<w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0">'
        '<wp:extent cx="$width" cy="$height"/>'
        '<wp:docPr id="$drawingId" name="Chronicle image $drawingId" '
        'descr="${_xmlAttribute(description)}"/>'
        '<a:graphic><a:graphicData '
        'uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:pic><pic:nvPicPr><pic:cNvPr id="$drawingId" '
        'name="Chronicle image $drawingId"/><pic:cNvPicPr/></pic:nvPicPr>'
        '<pic:blipFill><a:blip r:embed="$relationship"/>'
        '<a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
        '<pic:spPr><a:xfrm><a:off x="0" y="0"/>'
        '<a:ext cx="$width" cy="$height"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
        '</pic:pic></a:graphicData></a:graphic>'
        '</wp:inline></w:drawing></w:r>';
  }

  String _missingImageRun(_MarkdownImage image) {
    final alt = image.alt.trim().isEmpty ? 'изображение' : image.alt.trim();
    return _run(
      _Inline.text(
        '[Не удалось встроить $alt: ${image.target}]',
        style: const _InlineStyle(italic: true),
      ),
    );
  }

  String _table(_TableBlock block) {
    if (block.rows.isEmpty) {
      return '';
    }
    final output = StringBuffer(
      '<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/>'
      '<w:tblBorders><w:top w:val="single" w:sz="4" w:color="B7B7B7"/>'
      '<w:left w:val="single" w:sz="4" w:color="B7B7B7"/>'
      '<w:bottom w:val="single" w:sz="4" w:color="B7B7B7"/>'
      '<w:right w:val="single" w:sz="4" w:color="B7B7B7"/>'
      '<w:insideH w:val="single" w:sz="4" w:color="D9D9D9"/>'
      '<w:insideV w:val="single" w:sz="4" w:color="D9D9D9"/>'
      '</w:tblBorders></w:tblPr>',
    );
    for (final row in block.rows) {
      output.write('<w:tr>');
      for (final cell in row.cells) {
        final cellInlines = row.header
            ? <_Inline>[
                for (final inline in cell)
                  inline.copyWith(style: inline.style.copyWith(bold: true)),
              ]
            : cell;
        output.write(
          '<w:tc><w:tcPr><w:tcW w:w="0" w:type="auto"/>'
          '${row.header ? '<w:shd w:val="clear" w:fill="EDEDED"/>' : ''}'
          '</w:tcPr>${_paragraph(cellInlines)}</w:tc>',
        );
      }
      output.write('</w:tr>');
    }
    output.write('</w:tbl>');
    return output.toString();
  }

  String _imageRelationship(String target, _ResolvedImage image) {
    final existing = _imageRelationshipByTarget[target];
    if (existing != null) {
      return existing;
    }
    final relationship = 'rId${_nextRelationship++}';
    final fileName = 'image${_nextImage++}.${image.extension}';
    _archive.addBytes('word/media/$fileName', image.bytes);
    _relationships.add(
      '<Relationship Id="$relationship" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
      'Target="media/$fileName"/>',
    );
    _contentTypes[image.extension] = image.mimeType;
    _imageRelationshipByTarget[target] = relationship;
    return relationship;
  }

  String _hyperlinkRelationship(String target) {
    final existing = _hyperlinkRelationshipByTarget[target];
    if (existing != null) {
      return existing;
    }
    final relationship = 'rId${_nextRelationship++}';
    _relationships.add(
      '<Relationship Id="$relationship" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" '
      'Target="${_xmlAttribute(target)}" TargetMode="External"/>',
    );
    _hyperlinkRelationshipByTarget[target] = relationship;
    return relationship;
  }

  String _contentTypesXml() {
    final imageDefaults = _contentTypes.entries
        .map(
          (entry) => '<Default Extension="${_xmlAttribute(entry.key)}" '
              'ContentType="${_xmlAttribute(entry.value)}"/>',
        )
        .join();
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" '
        'ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '$imageDefaults'
        '<Override PartName="/word/document.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '<Override PartName="/word/styles.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
        '<Override PartName="/docProps/core.xml" '
        'ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
        '<Override PartName="/docProps/app.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>'
        '</Types>';
  }

  String _packageRelationshipsXml() =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
      'Target="word/document.xml"/>'
      '<Relationship Id="rId2" '
      'Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" '
      'Target="docProps/core.xml"/>'
      '<Relationship Id="rId3" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" '
      'Target="docProps/app.xml"/>'
      '</Relationships>';

  String _documentRelationshipsXml() =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="styles" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" '
      'Target="styles.xml"/>'
      '${_relationships.join()}'
      '</Relationships>';

  String _documentXml(String body) =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:document '
      'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
      'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
      'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
      'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" '
      'xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math">'
      '<w:body>$body<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
      '<w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134"/>'
      '</w:sectPr></w:body></w:document>';

  String _stylesXml() {
    final headingStyles = StringBuffer();
    const sizes = <int>[0, 34, 30, 27, 24, 22, 20];
    for (var level = 1; level <= 6; level += 1) {
      headingStyles.write(
        '<w:style w:type="paragraph" w:styleId="Heading$level">'
        '<w:name w:val="heading $level"/><w:basedOn w:val="Normal"/>'
        '<w:next w:val="Normal"/><w:qFormat/><w:pPr>'
        '<w:keepNext/><w:keepLines/><w:spacing w:before="240" w:after="120"/>'
        '</w:pPr><w:rPr><w:b/><w:sz w:val="${sizes[level]}"/>'
        '</w:rPr></w:style>',
      );
    }
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:style w:type="paragraph" w:default="1" w:styleId="Normal">'
        '<w:name w:val="Normal"/><w:pPr><w:spacing w:after="120" '
        'w:line="276" w:lineRule="auto"/></w:pPr><w:rPr>'
        '<w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:eastAsia="Arial"/>'
        '<w:sz w:val="22"/></w:rPr></w:style>'
        '$headingStyles'
        '<w:style w:type="paragraph" w:styleId="Quote">'
        '<w:name w:val="Quote"/><w:basedOn w:val="Normal"/>'
        '<w:pPr><w:ind w:left="480"/><w:spacing w:before="80" w:after="120"/>'
        '<w:pBdr><w:left w:val="single" w:sz="12" w:space="8" '
        'w:color="A6A6A6"/></w:pBdr></w:pPr><w:rPr><w:i/>'
        '<w:color w:val="595959"/></w:rPr></w:style>'
        '<w:style w:type="paragraph" w:styleId="Code">'
        '<w:name w:val="Code"/><w:basedOn w:val="Normal"/>'
        '<w:pPr><w:ind w:left="240" w:right="240"/>'
        '<w:shd w:val="clear" w:fill="F2F2F2"/></w:pPr><w:rPr>'
        '<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas"/>'
        '<w:sz w:val="19"/></w:rPr></w:style>'
        '<w:style w:type="paragraph" w:styleId="Caption">'
        '<w:name w:val="Caption"/><w:basedOn w:val="Normal"/>'
        '<w:pPr><w:jc w:val="center"/><w:spacing w:after="160"/></w:pPr>'
        '<w:rPr><w:i/><w:color w:val="595959"/><w:sz w:val="20"/>'
        '</w:rPr></w:style>'
        '</w:styles>';
  }

  String _corePropertiesXml(String generated) =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<cp:coreProperties '
      'xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
      'xmlns:dc="http://purl.org/dc/elements/1.1/" '
      'xmlns:dcterms="http://purl.org/dc/terms/" '
      'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
      '<dc:title>${_xml(title)}</dc:title><dc:creator>Chronicle</dc:creator>'
      '<cp:lastModifiedBy>Chronicle</cp:lastModifiedBy>'
      '<dcterms:created xsi:type="dcterms:W3CDTF">$generated</dcterms:created>'
      '<dcterms:modified xsi:type="dcterms:W3CDTF">$generated</dcterms:modified>'
      '</cp:coreProperties>';

  String _appPropertiesXml() =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Properties '
      'xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" '
      'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">'
      '<Application>Chronicle</Application></Properties>';
}

class _PdfRenderer {
  const _PdfRenderer(this.resolved);

  final _ResolvedMarkdown resolved;

  List<pw.Widget> widgets() {
    final result = <pw.Widget>[];
    for (final block in resolved.document.blocks) {
      result.addAll(_block(block));
    }
    return result;
  }

  List<pw.Widget> _block(_MarkdownBlock block) {
    if (block is _ParagraphBlock) {
      return <pw.Widget>[_paragraph(block.inlines)];
    }
    if (block is _HeadingBlock) {
      const sizes = <double>[0, 22, 18, 15, 13.5, 12.5, 12];
      return <pw.Widget>[
        pw.Padding(
          padding: pw.EdgeInsets.only(
            top: block.level == 1 ? 0 : 10,
            bottom: 5,
          ),
          child: _paragraph(
            block.inlines,
            baseStyle: pw.TextStyle(
              fontSize: sizes[block.level.clamp(1, 6).toInt()],
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ];
    }
    if (block is _ListItemBlock) {
      final prefix = block.ordered ? '${block.number}. ' : '• ';
      return <pw.Widget>[
        pw.Padding(
          padding: pw.EdgeInsets.only(
            left: 12.0 + block.depth * 14.0,
            bottom: 4,
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.SizedBox(width: 22, child: pw.Text(prefix)),
              pw.Expanded(child: _paragraph(block.inlines, bottom: 0)),
            ],
          ),
        ),
      ];
    }
    if (block is _CodeBlock) {
      final label = block.language.trim().isEmpty
          ? ''
          : '${block.language.trim()}\n';
      return <pw.Widget>[
        pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(bottom: 9),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xfff2f2f2)),
          child: pw.Text(
            '$label${block.code}',
            style: const pw.TextStyle(fontSize: 9.5),
          ),
        ),
      ];
    }
    if (block is _HorizontalRuleBlock) {
      return <pw.Widget>[
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          child: pw.Divider(color: PdfColors.grey400),
        ),
      ];
    }
    if (block is _MathBlock) {
      return <pw.Widget>[_displayMath(block.source)];
    }
    if (block is _ColumnsBlock) {
      return <pw.Widget>[_columns(block)];
    }
    if (block is _ImageBlock) {
      return <pw.Widget>[_image(block.image)];
    }
    if (block is _TableBlock) {
      return <pw.Widget>[
        _table(block),
        pw.SizedBox(height: 10),
      ];
    }
    if (block is _QuoteBlock) {
      final quoted = <pw.Widget>[];
      for (final child in block.children) {
        quoted.addAll(_block(child));
      }
      return <pw.Widget>[
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 9),
          padding: const pw.EdgeInsets.fromLTRB(10, 6, 8, 2),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              left: pw.BorderSide(color: PdfColors.grey500, width: 2),
            ),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: quoted,
          ),
        ),
      ];
    }
    return const <pw.Widget>[];
  }

  pw.Widget _displayMath(String source) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(top: 4, bottom: 10),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xfff7f7f7),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        _MathText.normalize(source),
        textAlign: pw.TextAlign.center,
        style: const pw.TextStyle(
          fontSize: 12.5,
          fontStyle: pw.FontStyle.italic,
        ),
      ),
    );
  }

  pw.Widget _columns(_ColumnsBlock block) {
    final widths = NoteColumnsSyntax.normalizeWidths(
      block.widths,
      block.columns.length,
    );
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          for (var index = 0; index < block.columns.length; index += 1)
            pw.Expanded(
              flex: widths[index],
              child: pw.Padding(
                padding: pw.EdgeInsets.only(
                  left: index == 0 ? 0 : 6,
                  right: index == block.columns.length - 1 ? 0 : 6,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    for (final child in block.columns[index])
                      ..._block(child),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _paragraph(
    List<_Inline> inlines, {
    pw.TextStyle? baseStyle,
    double bottom = 8,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: bottom),
      child: pw.RichText(
        text: pw.TextSpan(
          style: baseStyle ?? const pw.TextStyle(fontSize: 11),
          children: <pw.InlineSpan>[
            for (final inline in inlines) _span(inline),
          ],
        ),
      ),
    );
  }

  pw.InlineSpan _span(_Inline inline) {
    if (inline.image != null) {
      return _inlineImageSpan(inline.image!);
    }
    if (inline.math != null) {
      return pw.TextSpan(
        text: _MathText.normalize(inline.math!),
        style: const pw.TextStyle(fontStyle: pw.FontStyle.italic),
      );
    }
    final style = inline.style;
    return pw.TextSpan(
      text: inline.text,
      annotation: style.link == null ? null : pw.AnnotationUrl(style.link!),
      style: pw.TextStyle(
        fontWeight: style.bold ? pw.FontWeight.bold : null,
        fontStyle: style.italic ? pw.FontStyle.italic : null,
        decoration: style.strike
            ? pw.TextDecoration.lineThrough
            : style.link == null
                ? null
                : pw.TextDecoration.underline,
        color: style.link == null ? null : PdfColors.blue700,
        fontSize: style.code ? 9.5 : null,
      ),
    );
  }

  pw.InlineSpan _inlineImageSpan(_MarkdownImage image) {
    final data = resolved.images[image.target];
    if (data == null) {
      final alt = image.alt.trim().isEmpty ? 'изображение' : image.alt.trim();
      return pw.TextSpan(
        text: '[Не удалось встроить $alt: ${image.target}]',
        style: const pw.TextStyle(fontStyle: pw.FontStyle.italic),
      );
    }
    final width = 110.0 *
        image.presentation.widthPercent.clamp(20, 100).toDouble() /
        100.0;
    try {
      final rendered = data.extension == 'svg'
          ? pw.SvgImage(
              svg: utf8.decode(data.bytes),
              width: width,
              fit: pw.BoxFit.contain,
            )
          : pw.Image(
              pw.MemoryImage(data.bytes),
              width: width,
              fit: pw.BoxFit.contain,
            );
      return pw.WidgetSpan(child: rendered);
    } on Object {
      return pw.TextSpan(
        text: '[Изображение не удалось декодировать: ${image.target}]',
        style: const pw.TextStyle(fontStyle: pw.FontStyle.italic),
      );
    }
  }

  pw.Widget _image(_MarkdownImage image) {
    final data = resolved.images[image.target];
    if (data == null) {
      final alt = image.alt.trim().isEmpty ? 'изображение' : image.alt.trim();
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 9),
        child: pw.Text(
          '[Не удалось встроить $alt: ${image.target}]',
          style: const pw.TextStyle(fontStyle: pw.FontStyle.italic),
        ),
      );
    }
    final width = 495.0 *
        image.presentation.widthPercent.clamp(20, 100).toDouble() /
        100.0;
    final alignment = switch (image.presentation.alignment) {
      NoteImageAlignment.left => pw.Alignment.centerLeft,
      NoteImageAlignment.center => pw.Alignment.center,
      NoteImageAlignment.right => pw.Alignment.centerRight,
    };
    pw.Widget rendered;
    if (data.extension == 'svg') {
      try {
        rendered = pw.SvgImage(
          svg: utf8.decode(data.bytes),
          width: width,
          fit: pw.BoxFit.contain,
        );
      } on Object {
        rendered = pw.Text('[SVG не удалось декодировать: ${image.target}]');
      }
    } else {
      try {
        rendered = pw.Image(
          pw.MemoryImage(data.bytes),
          width: width,
          fit: pw.BoxFit.contain,
        );
      } on Object {
        rendered = pw.Text('[Изображение не удалось декодировать: ${image.target}]');
      }
    }
    final caption = image.presentation.caption.trim();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: <pw.Widget>[
          pw.Align(alignment: alignment, child: rendered),
          if (caption.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                caption,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                  fontSize: 9.5,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _table(_TableBlock block) {
    if (block.rows.isEmpty) {
      return pw.SizedBox();
    }
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
      children: <pw.TableRow>[
        for (final row in block.rows)
          pw.TableRow(
            repeat: row.header,
            decoration: row.header
                ? pw.BoxDecoration(color: PdfColor.fromInt(0xffededed))
                : null,
            children: <pw.Widget>[
              for (final cell in row.cells)
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: _paragraph(
                    row.header
                        ? <_Inline>[
                            for (final inline in cell)
                              inline.copyWith(
                                style: inline.style.copyWith(bold: true),
                              ),
                          ]
                        : cell,
                    bottom: 0,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _MarkdownDocument {
  const _MarkdownDocument(this.blocks);

  final List<_MarkdownBlock> blocks;

  Iterable<_MarkdownImage> get images sync* {
    for (final block in blocks) {
      yield* _imagesInBlock(block);
    }
  }

  static Iterable<_MarkdownImage> _imagesInBlock(_MarkdownBlock block) sync* {
    if (block is _ImageBlock) {
      yield block.image;
      return;
    }
    if (block is _ParagraphBlock) {
      yield* _imagesInInlines(block.inlines);
      return;
    }
    if (block is _HeadingBlock) {
      yield* _imagesInInlines(block.inlines);
      return;
    }
    if (block is _ListItemBlock) {
      yield* _imagesInInlines(block.inlines);
      return;
    }
    if (block is _TableBlock) {
      for (final row in block.rows) {
        for (final cell in row.cells) {
          yield* _imagesInInlines(cell);
        }
      }
      return;
    }
    if (block is _ColumnsBlock) {
      for (final column in block.columns) {
        for (final child in column) {
          yield* _imagesInBlock(child);
        }
      }
      return;
    }
    if (block is _QuoteBlock) {
      for (final child in block.children) {
        yield* _imagesInBlock(child);
      }
    }
  }

  static Iterable<_MarkdownImage> _imagesInInlines(
    Iterable<_Inline> inlines,
  ) sync* {
    for (final inline in inlines) {
      final image = inline.image;
      if (image != null) {
        yield image;
      }
    }
  }
}

class _ResolvedMarkdown {
  const _ResolvedMarkdown({
    required this.document,
    required this.images,
    required this.assetCount,
    required this.missingAttachments,
  });

  final _MarkdownDocument document;
  final Map<String, _ResolvedImage?> images;
  final int assetCount;
  final List<String> missingAttachments;
}

abstract class _MarkdownBlock {
  const _MarkdownBlock();
}

class _ParagraphBlock extends _MarkdownBlock {
  const _ParagraphBlock(this.inlines);

  final List<_Inline> inlines;
}

class _HeadingBlock extends _MarkdownBlock {
  const _HeadingBlock(this.level, this.inlines);

  final int level;
  final List<_Inline> inlines;
}

class _ListItemBlock extends _MarkdownBlock {
  const _ListItemBlock({
    required this.ordered,
    required this.number,
    required this.depth,
    required this.inlines,
  });

  final bool ordered;
  final int? number;
  final int depth;
  final List<_Inline> inlines;
}

class _QuoteBlock extends _MarkdownBlock {
  const _QuoteBlock(this.children);

  final List<_MarkdownBlock> children;
}

class _CodeBlock extends _MarkdownBlock {
  const _CodeBlock(this.code, {required this.language});

  final String code;
  final String language;
}

class _HorizontalRuleBlock extends _MarkdownBlock {
  const _HorizontalRuleBlock();
}

class _MathBlock extends _MarkdownBlock {
  const _MathBlock(this.source);

  final String source;
}

class _ColumnsBlock extends _MarkdownBlock {
  const _ColumnsBlock({required this.widths, required this.columns});

  final List<int> widths;
  final List<List<_MarkdownBlock>> columns;
}

class _ImageBlock extends _MarkdownBlock {
  const _ImageBlock(this.image);

  final _MarkdownImage image;
}

class _TableBlock extends _MarkdownBlock {
  const _TableBlock(this.rows);

  final List<_TableRow> rows;
}

class _TableRow {
  const _TableRow(this.cells, {required this.header});

  final List<List<_Inline>> cells;
  final bool header;
}

class _Inline {
  const _Inline._({
    required this.text,
    required this.style,
    required this.image,
    required this.math,
  });

  factory _Inline.text(
    String text, {
    _InlineStyle style = const _InlineStyle(),
  }) =>
      _Inline._(text: text, style: style, image: null, math: null);

  factory _Inline.image(_MarkdownImage image) => _Inline._(
        text: '',
        style: const _InlineStyle(),
        image: image,
        math: null,
      );

  factory _Inline.math(
    String source, {
    _InlineStyle style = const _InlineStyle(),
  }) =>
      _Inline._(text: '', style: style, image: null, math: source);

  final String text;
  final _InlineStyle style;
  final _MarkdownImage? image;
  final String? math;

  String get plainText => image != null ? image!.alt : math ?? text;

  _Inline copyWith({_InlineStyle? style}) => _Inline._(
        text: text,
        style: style ?? this.style,
        image: image,
        math: math,
      );
}

class _InlineStyle {
  const _InlineStyle({
    this.bold = false,
    this.italic = false,
    this.strike = false,
    this.code = false,
    this.link,
  });

  final bool bold;
  final bool italic;
  final bool strike;
  final bool code;
  final String? link;

  _InlineStyle copyWith({
    bool? bold,
    bool? italic,
    bool? strike,
    bool? code,
    String? link,
  }) =>
      _InlineStyle(
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        strike: strike ?? this.strike,
        code: code ?? this.code,
        link: link ?? this.link,
      );
}

class _MarkdownImage {
  const _MarkdownImage({
    required this.target,
    required this.alt,
    required this.presentation,
  });

  final String target;
  final String alt;
  final NoteImagePresentation presentation;
}

class _ResolvedImage {
  const _ResolvedImage({
    required this.bytes,
    required this.extension,
    required this.mimeType,
    required this.size,
  });

  final Uint8List bytes;
  final String extension;
  final String mimeType;
  final _PixelSize? size;
}

class _PixelSize {
  const _PixelSize(this.width, this.height);

  final int width;
  final int height;
}

String? _imageExtension(String fileName, Uint8List bytes) {
  final extension = path.extension(fileName).toLowerCase().replaceFirst('.', '');
  if (const <String>{'png', 'jpg', 'jpeg', 'gif', 'webp', 'svg', 'bmp'}
      .contains(extension)) {
    return extension == 'jpeg' ? 'jpg' : extension;
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47) {
    return 'png';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return 'jpg';
  }
  if (bytes.length >= 6 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46) {
    return 'gif';
  }
  final prefix = utf8.decode(bytes.take(math.min(bytes.length, 256)).toList(),
      allowMalformed: true);
  if (prefix.contains('<svg')) {
    return 'svg';
  }
  return null;
}

String _imageMimeType(String extension) => switch (extension) {
      'png' => 'image/png',
      'jpg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'svg' => 'image/svg+xml',
      'bmp' => 'image/bmp',
      _ => 'application/octet-stream',
    };

_PixelSize? _pixelSize(Uint8List bytes, String extension) {
  try {
    if (extension == 'png' && bytes.length >= 24) {
      final data = ByteData.sublistView(bytes);
      return _PixelSize(data.getUint32(16), data.getUint32(20));
    }
    if (extension == 'gif' && bytes.length >= 10) {
      final data = ByteData.sublistView(bytes);
      return _PixelSize(
        data.getUint16(6, Endian.little),
        data.getUint16(8, Endian.little),
      );
    }
    if (extension == 'jpg') {
      return _jpegSize(bytes);
    }
  } on Object {
    return null;
  }
  return null;
}

_PixelSize? _jpegSize(Uint8List bytes) {
  var offset = 2;
  while (offset + 9 < bytes.length) {
    if (bytes[offset] != 0xff) {
      offset += 1;
      continue;
    }
    final marker = bytes[offset + 1];
    offset += 2;
    if (marker == 0xd8 || marker == 0xd9) {
      continue;
    }
    if (offset + 2 > bytes.length) {
      return null;
    }
    final length = (bytes[offset] << 8) | bytes[offset + 1];
    if (length < 2 || offset + length > bytes.length) {
      return null;
    }
    if (const <int>{
      0xc0,
      0xc1,
      0xc2,
      0xc3,
      0xc5,
      0xc6,
      0xc7,
      0xc9,
      0xca,
      0xcb,
      0xcd,
      0xce,
      0xcf,
    }.contains(marker)) {
      final height = (bytes[offset + 3] << 8) | bytes[offset + 4];
      final width = (bytes[offset + 5] << 8) | bytes[offset + 6];
      return _PixelSize(width, height);
    }
    offset += length;
  }
  return null;
}

String _xml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String _xmlAttribute(String value) => _xml(value)
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
