import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

import 'note_document.dart';

class NoteMarkdownView extends StatelessWidget {
  const NoteMarkdownView({
    super.key,
    required this.markdown,
    this.onWikiLink,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 120),
  });

  final String markdown;
  final ValueChanged<String>? onWikiLink;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final chunks = _splitMarkdown(markdown);
    return ListView(
      padding: padding,
      children: [
        for (final chunk in chunks)
          if (chunk.isMath)
            _DisplayMath(source: chunk.value)
          else if (chunk.value.trim().isNotEmpty)
            MarkdownBody(
              data: NoteDocument.convertWikiLinksToMarkdown(chunk.value),
              selectable: true,
              extensionSet: md.ExtensionSet.gitHubFlavored,
              inlineSyntaxes: [InlineMathSyntax()],
              builders: {'math': InlineMathBuilder()},
              imageBuilder: _buildImage,
              onTapLink: (_, href, __) {
                if (href == null || !href.startsWith('chronicle://note/')) {
                  return;
                }
                final encoded = href.substring('chronicle://note/'.length);
                onWikiLink?.call(Uri.decodeComponent(encoded));
              },
            ),
      ],
    );
  }

  Widget _buildImage(Uri uri, String? title, String? alt) {
    if (uri.scheme == 'data') {
      final bytes = _decodeDataUri(uri.toString());
      if (bytes != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.memory(bytes, fit: BoxFit.contain),
        );
      }
    }
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          uri.toString(),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _ImageFallback(label: alt),
        ),
      );
    }
    return _ImageFallback(label: alt ?? uri.toString());
  }
}

class InlineMathSyntax extends md.InlineSyntax {
  InlineMathSyntax() : super(r'\$([^$\n]+)\$', startCharacter: 0x24);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('math', match.group(1) ?? ''));
    return true;
  }
}

class InlineMathBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Math.tex(
        element.textContent,
        mathStyle: MathStyle.text,
        textStyle: preferredStyle,
        onErrorFallback:
            (error) => Text(
              element.textContent,
              style: preferredStyle?.copyWith(
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.wavy,
              ),
            ),
      ),
    );
  }
}

class _DisplayMath extends StatelessWidget {
  const _DisplayMath({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Math.tex(
          source,
          mathStyle: MathStyle.display,
          textStyle: Theme.of(context).textTheme.titleMedium,
          onErrorFallback:
              (error) => SelectableText(
                source,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 100),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined),
          if (label != null && label!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(label!, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

class _MarkdownChunk {
  const _MarkdownChunk(this.value, {required this.isMath});

  final String value;
  final bool isMath;
}

List<_MarkdownChunk> _splitMarkdown(String source) {
  final pattern = RegExp(r'(\\\[[\s\S]*?\\\]|\$\$[\s\S]*?\$\$)');
  final result = <_MarkdownChunk>[];
  var cursor = 0;
  for (final match in pattern.allMatches(source)) {
    if (match.start > cursor) {
      result.add(
        _MarkdownChunk(source.substring(cursor, match.start), isMath: false),
      );
    }
    final raw = match.group(0) ?? '';
    final value =
        raw.startsWith(r'\[')
            ? raw.substring(2, raw.length - 2)
            : raw.substring(2, raw.length - 2);
    result.add(_MarkdownChunk(value.trim(), isMath: true));
    cursor = match.end;
  }
  if (cursor < source.length) {
    result.add(_MarkdownChunk(source.substring(cursor), isMath: false));
  }
  if (result.isEmpty) result.add(_MarkdownChunk(source, isMath: false));
  return result;
}

Uint8List? _decodeDataUri(String value) {
  final comma = value.indexOf(',');
  if (comma < 0 || !value.substring(0, comma).contains(';base64')) return null;
  try {
    return base64Decode(value.substring(comma + 1));
  } on FormatException {
    return null;
  }
}
