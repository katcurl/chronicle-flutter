import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

import '../../vault/vault_asset_loader.dart';
import 'note_columns_syntax.dart';
import 'note_document.dart';
import 'note_image_syntax.dart';

typedef NoteImageEditCallback = void Function(NoteImageReference reference);
typedef NoteImageResizeCallback =
    void Function(
      NoteImageReference reference,
      NoteImagePresentation presentation,
    );
typedef NoteColumnsEditCallback =
    void Function(NoteColumnsReference reference);
typedef NoteColumnsResizeCallback =
    void Function(NoteColumnsReference reference, List<int> widths);

class NoteMarkdownView extends StatelessWidget {
  const NoteMarkdownView({
    super.key,
    required this.markdown,
    this.onWikiLink,
    this.onEditImage,
    this.onResizeImage,
    this.onEditColumns,
    this.onResizeColumns,
    this.vaultRootPath = '',
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 120),
  });

  final String markdown;
  final ValueChanged<String>? onWikiLink;
  final NoteImageEditCallback? onEditImage;
  final NoteImageResizeCallback? onResizeImage;
  final NoteColumnsEditCallback? onEditColumns;
  final NoteColumnsResizeCallback? onResizeColumns;
  final String vaultRootPath;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      children: _buildContentChunks(context, markdown, baseOffset: 0),
    );
  }

  List<Widget> _buildContentChunks(
    BuildContext context,
    String source, {
    required int baseOffset,
  }) {
    final chunks = _splitDocument(source, baseOffset: baseOffset);
    return [
      for (final chunk in chunks)
        switch (chunk.kind) {
          _DocumentChunkKind.math => _DisplayMath(source: chunk.value),
          _DocumentChunkKind.image => _buildManagedImage(
            context,
            chunk.image!,
          ),
          _DocumentChunkKind.columns => _buildManagedColumns(
            context,
            chunk.columns!,
          ),
          _DocumentChunkKind.markdown =>
            chunk.value.trim().isEmpty
                ? const SizedBox.shrink()
                : _buildMarkdownBody(chunk.value),
        },
    ];
  }

  Widget _buildMarkdownBody(String value) {
    return MarkdownBody(
      data: NoteDocument.convertWikiLinksToMarkdown(value),
      selectable: true,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      inlineSyntaxes: [InlineMathSyntax()],
      builders: {'math': InlineMathBuilder()},
      imageBuilder:
          (uri, _, alt) => ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _loadImage(uri.toString(), alt ?? ''),
          ),
      onTapLink: (_, href, __) {
        if (href == null || !href.startsWith('chronicle://note/')) {
          return;
        }
        final encoded = href.substring('chronicle://note/'.length);
        onWikiLink?.call(Uri.decodeComponent(encoded));
      },
    );
  }

  Widget _buildManagedColumns(
    BuildContext context,
    NoteColumnsReference reference,
  ) {
    return _ManagedNoteColumns(
      reference: reference,
      onEdit:
          reference.raw.isEmpty || onEditColumns == null
              ? null
              : () => onEditColumns!(reference),
      onResize:
          reference.raw.isEmpty || onResizeColumns == null
              ? null
              : (widths) => onResizeColumns!(reference, widths),
      children: [
        for (final column in reference.columns)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _buildContentChunks(
              context,
              column.markdown,
              baseOffset: column.start,
            ),
          ),
      ],
    );
  }

  Widget _buildManagedImage(
    BuildContext context,
    NoteImageReference reference,
  ) {
    return _ManagedNoteImage(
      reference: reference,
      onEdit:
          reference.raw.isEmpty || onEditImage == null
              ? null
              : () => onEditImage!(reference),
      onResize:
          reference.raw.isEmpty || onResizeImage == null
              ? null
              : (presentation) => onResizeImage!(reference, presentation),
      child: _loadImage(
        reference.target,
        reference.alt,
        expand: true,
      ),
    );
  }

  Widget _loadImage(
    String target,
    String alt, {
    bool expand = false,
  }) {
    final uri = Uri.tryParse(target);
    if (uri == null) {
      return _ImageFallback(label: alt.isEmpty ? target : alt);
    }
    if (uri.scheme == 'data') {
      final bytes = _decodeDataUri(uri.toString());
      if (bytes != null) {
        return Image.memory(
          bytes,
          width: expand ? double.infinity : null,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _ImageFallback(label: alt),
        );
      }
    }
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return Image.network(
        uri.toString(),
        width: expand ? double.infinity : null,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _ImageFallback(label: alt),
      );
    }
    if (vaultRootPath.isNotEmpty &&
        uri.toString().toLowerCase().contains('attachments/')) {
      return FutureBuilder<Uint8List?>(
        future: loadVaultAttachment(vaultRootPath, uri.toString()),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return _ImageFallback(label: alt.isEmpty ? target : alt);
          }
          return Image.memory(
            bytes,
            width: expand ? double.infinity : null,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _ImageFallback(label: alt),
          );
        },
      );
    }
    return _ImageFallback(label: alt.isEmpty ? target : alt);
  }
}

class _ManagedNoteColumns extends StatefulWidget {
  const _ManagedNoteColumns({
    required this.reference,
    required this.children,
    this.onEdit,
    this.onResize,
  });

  final NoteColumnsReference reference;
  final List<Widget> children;
  final VoidCallback? onEdit;
  final ValueChanged<List<int>>? onResize;

  @override
  State<_ManagedNoteColumns> createState() => _ManagedNoteColumnsState();
}

class _ManagedNoteColumnsState extends State<_ManagedNoteColumns> {
  bool hovering = false;
  List<double>? dragWidths;
  double availableWidth = 1;

  bool get editable => widget.onEdit != null || widget.onResize != null;

  @override
  void didUpdateWidget(covariant _ManagedNoteColumns oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reference.raw != widget.reference.raw) {
      dragWidths = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final widths =
        dragWidths ??
        [for (final width in widget.reference.widths) width.toDouble()];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          availableWidth =
              constraints.hasBoundedWidth
                  ? constraints.maxWidth
                  : MediaQuery.sizeOf(context).width;
          final stacked = availableWidth < 620;

          return MouseRegion(
            onEnter: (_) => setState(() => hovering = true),
            onExit: (_) => setState(() => hovering = false),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color:
                          hovering && editable
                              ? Theme.of(context).colorScheme.outlineVariant
                              : Colors.transparent,
                    ),
                  ),
                  child:
                      stacked
                          ? _buildStacked(context)
                          : _buildHorizontal(context, widths),
                ),
                if (widget.onEdit != null && hovering)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(999),
                      elevation: 2,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: widget.onEdit,
                        child: const Padding(
                          padding: EdgeInsets.all(7),
                          child: Icon(Icons.view_column_rounded, size: 18),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStacked(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < widget.children.length; index += 1) ...[
          widget.children[index],
          if (index < widget.children.length - 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildHorizontal(BuildContext context, List<double> widths) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < widget.children.length; index += 1) ...[
          Expanded(
            flex: widths[index].round().clamp(1, 100).toInt(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: widget.children[index],
            ),
          ),
          if (index < widget.children.length - 1)
            _ColumnResizeHandle(
              enabled: widget.onResize != null,
              active: dragWidths != null,
              onUpdate: (delta) => _updateDivider(index, delta),
              onEnd: _finishResize,
              onCancel: _cancelResize,
            ),
        ],
      ],
    );
  }

  void _updateDivider(int index, double deltaX) {
    if (widget.onResize == null || availableWidth <= 0) {
      return;
    }
    final current = List<double>.from(
      dragWidths ??
          [for (final width in widget.reference.widths) width.toDouble()],
    );
    final minimum = current.length == 2 ? 20.0 : 15.0;
    final delta = deltaX / availableWidth * 100;
    final nextLeft = current[index] + delta;
    final nextRight = current[index + 1] - delta;
    if (nextLeft < minimum || nextRight < minimum) {
      return;
    }
    current[index] = nextLeft;
    current[index + 1] = nextRight;
    setState(() => dragWidths = current);
  }

  void _finishResize() {
    final current = dragWidths;
    if (current == null) {
      return;
    }
    final normalized = NoteColumnsSyntax.normalizeWidths(
      [for (final width in current) width.round()],
      current.length,
    );
    setState(() => dragWidths = null);
    widget.onResize?.call(normalized);
  }

  void _cancelResize() {
    if (dragWidths != null) {
      setState(() => dragWidths = null);
    }
  }
}

class _ColumnResizeHandle extends StatelessWidget {
  const _ColumnResizeHandle({
    required this.enabled,
    required this.active,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
  });

  final bool enabled;
  final bool active;
  final ValueChanged<double> onUpdate;
  final VoidCallback onEnd;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor:
          enabled
              ? SystemMouseCursors.resizeLeftRight
              : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate:
            enabled ? (details) => onUpdate(details.delta.dx) : null,
        onHorizontalDragEnd: enabled ? (_) => onEnd() : null,
        onHorizontalDragCancel: enabled ? onCancel : null,
        child: SizedBox(
          width: 18,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: active ? 4 : 2,
              height: 54,
              decoration: BoxDecoration(
                color:
                    active
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ManagedNoteImage extends StatefulWidget {
  const _ManagedNoteImage({
    required this.reference,
    required this.child,
    this.onEdit,
    this.onResize,
  });

  final NoteImageReference reference;
  final Widget child;
  final VoidCallback? onEdit;
  final ValueChanged<NoteImagePresentation>? onResize;

  @override
  State<_ManagedNoteImage> createState() => _ManagedNoteImageState();
}

class _ManagedNoteImageState extends State<_ManagedNoteImage> {
  bool hovering = false;
  double? dragPercent;
  double availableWidth = 1;

  bool get editable => widget.onEdit != null || widget.onResize != null;

  @override
  void didUpdateWidget(covariant _ManagedNoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reference.raw != widget.reference.raw) {
      dragPercent = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final presentation = widget.reference.presentation;
    final effectivePercent =
        dragPercent ?? presentation.widthPercent.toDouble();
    final alignment = switch (presentation.alignment) {
      NoteImageAlignment.left => Alignment.centerLeft,
      NoteImageAlignment.center => Alignment.center,
      NoteImageAlignment.right => Alignment.centerRight,
    };
    final textAlign = switch (presentation.alignment) {
      NoteImageAlignment.left => TextAlign.left,
      NoteImageAlignment.center => TextAlign.center,
      NoteImageAlignment.right => TextAlign.right,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          availableWidth =
              constraints.hasBoundedWidth
                  ? constraints.maxWidth
                  : MediaQuery.sizeOf(context).width;
          final displayedWidth =
              availableWidth * (effectivePercent.clamp(20, 100) / 100);

          return SizedBox(
            width: double.infinity,
            child: Align(
              alignment: alignment,
              child: SizedBox(
                width: displayedWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MouseRegion(
                      onEnter: (_) => setState(() => hovering = true),
                      onExit: (_) => setState(() => hovering = false),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          GestureDetector(
                            onTap: widget.onEdit,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: widget.child,
                            ),
                          ),
                          if (editable && (hovering || dragPercent != null))
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Material(
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(999),
                                elevation: 2,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(999),
                                  onTap: widget.onEdit,
                                  child: const Padding(
                                    padding: EdgeInsets.all(7),
                                    child: Icon(Icons.tune_rounded, size: 18),
                                  ),
                                ),
                              ),
                            ),
                          if (widget.onResize != null)
                            Positioned(
                              right: 6,
                              bottom: 6,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.resizeLeftRight,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onHorizontalDragUpdate: (details) {
                                    final current =
                                        dragPercent ??
                                        presentation.widthPercent.toDouble();
                                    setState(() {
                                      dragPercent = (current +
                                              details.delta.dx /
                                                  availableWidth *
                                                  100)
                                          .clamp(20, 100)
                                          .toDouble();
                                    });
                                  },
                                  onHorizontalDragEnd: (_) => _finishResize(),
                                  onHorizontalDragCancel: _cancelResize,
                                  child: AnimatedOpacity(
                                    opacity:
                                        hovering || dragPercent != null ? 1 : 0,
                                    duration: const Duration(milliseconds: 120),
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.drag_handle_rounded,
                                        size: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (dragPercent != null)
                            Positioned(
                              left: 8,
                              bottom: 8,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.inverseSurface.withAlpha(220),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    '${dragPercent!.round()}%',
                                    style: TextStyle(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onInverseSurface,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (presentation.caption.trim().isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        presentation.caption.trim(),
                        textAlign: textAlign,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _finishResize() {
    final current = dragPercent;
    if (current == null) {
      return;
    }
    final rounded = ((current / 5).round() * 5).clamp(20, 100).toInt();
    setState(() => dragPercent = null);
    widget.onResize?.call(
      widget.reference.presentation.copyWith(widthPercent: rounded),
    );
  }

  void _cancelResize() {
    if (dragPercent != null) {
      setState(() => dragPercent = null);
    }
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

enum _DocumentChunkKind { markdown, math, image, columns }

class _DocumentChunk {
  const _DocumentChunk.markdown(this.value)
    : kind = _DocumentChunkKind.markdown,
      image = null,
      columns = null;

  const _DocumentChunk.math(this.value)
    : kind = _DocumentChunkKind.math,
      image = null,
      columns = null;

  const _DocumentChunk.image(NoteImageReference reference)
    : kind = _DocumentChunkKind.image,
      value = '',
      image = reference,
      columns = null;

  const _DocumentChunk.columns(NoteColumnsReference reference)
    : kind = _DocumentChunkKind.columns,
      value = '',
      image = null,
      columns = reference;

  final _DocumentChunkKind kind;
  final String value;
  final NoteImageReference? image;
  final NoteColumnsReference? columns;
}

class _DocumentToken {
  const _DocumentToken({
    required this.start,
    required this.end,
    required this.kind,
    this.value = '',
    this.image,
    this.columns,
  });

  final int start;
  final int end;
  final _DocumentChunkKind kind;
  final String value;
  final NoteImageReference? image;
  final NoteColumnsReference? columns;
}

List<_DocumentChunk> _splitDocument(
  String source, {
  required int baseOffset,
}) {
  final tokens = <_DocumentToken>[];
  final mathPattern = RegExp(r'(\\\[[\s\S]*?\\\]|\$\$[\s\S]*?\$\$)');

  for (final columns in NoteColumnsSyntax.all(source)) {
    tokens.add(
      _DocumentToken(
        start: columns.start,
        end: columns.end,
        kind: _DocumentChunkKind.columns,
        columns: columns.shifted(baseOffset),
      ),
    );
  }
  for (final match in mathPattern.allMatches(source)) {
    if (_isInsideMarkdownCode(source, match.start)) {
      continue;
    }
    final raw = match.group(0) ?? '';
    tokens.add(
      _DocumentToken(
        start: match.start,
        end: match.end,
        kind: _DocumentChunkKind.math,
        value: raw.length >= 4 ? raw.substring(2, raw.length - 2).trim() : raw,
      ),
    );
  }
  for (final image in NoteImageSyntax.all(source)) {
    if (_isInsideMarkdownCode(source, image.start) ||
        !_isStandaloneImage(source, image)) {
      continue;
    }
    tokens.add(
      _DocumentToken(
        start: image.start,
        end: image.end,
        kind: _DocumentChunkKind.image,
        image: image.shifted(baseOffset),
      ),
    );
  }

  tokens.sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    if (byStart != 0) {
      return byStart;
    }
    return b.end.compareTo(a.end);
  });

  final result = <_DocumentChunk>[];
  var cursor = 0;
  for (final token in tokens) {
    if (token.start < cursor) {
      continue;
    }
    if (token.start > cursor) {
      result.add(
        _DocumentChunk.markdown(source.substring(cursor, token.start)),
      );
    }
    switch (token.kind) {
      case _DocumentChunkKind.math:
        result.add(_DocumentChunk.math(token.value));
        break;
      case _DocumentChunkKind.image:
        result.add(_DocumentChunk.image(token.image!));
        break;
      case _DocumentChunkKind.columns:
        result.add(_DocumentChunk.columns(token.columns!));
        break;
      case _DocumentChunkKind.markdown:
        result.add(_DocumentChunk.markdown(token.value));
        break;
    }
    cursor = token.end;
  }
  if (cursor < source.length) {
    result.add(_DocumentChunk.markdown(source.substring(cursor)));
  }
  if (result.isEmpty) {
    result.add(_DocumentChunk.markdown(source));
  }
  return result;
}

bool _isStandaloneImage(String source, NoteImageReference image) {
  final lineStart =
      source.lastIndexOf('\n', image.start == 0 ? 0 : image.start - 1) + 1;
  final nextBreak = source.indexOf('\n', image.end);
  final lineEnd = nextBreak < 0 ? source.length : nextBreak;
  return source.substring(lineStart, image.start).trim().isEmpty &&
      source.substring(image.end, lineEnd).trim().isEmpty;
}

bool _isInsideMarkdownCode(String source, int offset) {
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

Uint8List? _decodeDataUri(String value) {
  final comma = value.indexOf(',');
  if (comma < 0 || !value.substring(0, comma).contains(';base64')) {
    return null;
  }
  try {
    return base64Decode(value.substring(comma + 1));
  } on FormatException {
    return null;
  }
}
