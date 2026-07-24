import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/scheduler.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

import '../../models/app_models.dart';
import '../../vault/vault_asset_loader.dart';
import '../references/citation_syntax.dart';
import 'note_columns_syntax.dart';
import 'note_document.dart';
import 'note_editor_profile.dart';
import 'note_image_syntax.dart';
import 'scientific_reference_syntax.dart';

typedef VaultAttachmentBytesLoader =
    Future<Uint8List?> Function(String rootPath, String markdownPath);

typedef NoteImageEditCallback = void Function(NoteImageReference reference);
typedef NoteImageResizeCallback =
    void Function(
      NoteImageReference reference,
      NoteImagePresentation presentation,
    );
typedef NoteColumnsEditCallback = void Function(NoteColumnsReference reference);
typedef NoteColumnsResizeCallback =
    void Function(NoteColumnsReference reference, List<int> widths);

const int _decreaseImageWidthAction = -1;
const int _increaseImageWidthAction = -2;

const int noteDataImageMaxEncodedBytes = 14 * 1024 * 1024;
const int noteDataImageMaxDecodedBytes = 10 * 1024 * 1024;
const int noteDataImageMaxDimension = 8192;
const int noteDataImageMaxPixels = 40000000;

bool noteDataImageEncodedPayloadFits({required int encodedPayloadLength}) =>
    encodedPayloadLength >= 0 &&
    encodedPayloadLength <= noteDataImageMaxEncodedBytes;

bool noteDataImageDecodedLengthFits(int decodedLength) =>
    decodedLength >= 0 && decodedLength <= noteDataImageMaxDecodedBytes;

bool noteDataImageDimensionsFit({required int width, required int height}) =>
    width > 0 &&
    height > 0 &&
    width <= noteDataImageMaxDimension &&
    height <= noteDataImageMaxDimension &&
    width * height <= noteDataImageMaxPixels;

class NoteMarkdownView extends StatelessWidget {
  const NoteMarkdownView({
    super.key,
    required this.markdown,
    this.controller,
    this.onWikiLink,
    this.onEditImage,
    this.onResizeImage,
    this.onEditColumns,
    this.onResizeColumns,
    this.assetListenable,
    this.assetLoader,
    this.citationSources = const [],
    this.vaultRootPath = '',
    this.remoteImagePolicy = RemoteImagePolicy.block,
    this.allowedRemoteImageDomains = const <String>{},
    this.onAllowRemoteImageDomain,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 120),
  });

  final String markdown;
  final ScrollController? controller;
  final ValueChanged<String>? onWikiLink;
  final NoteImageEditCallback? onEditImage;
  final NoteImageResizeCallback? onResizeImage;
  final NoteColumnsEditCallback? onEditColumns;
  final NoteColumnsResizeCallback? onResizeColumns;
  final Listenable? assetListenable;
  final VaultAttachmentBytesLoader? assetLoader;
  final List<CitationSource> citationSources;
  final String vaultRootPath;
  final RemoteImagePolicy remoteImagePolicy;
  final Set<String> allowedRemoteImageDomains;
  final ValueChanged<String>? onAllowRemoteImageDomain;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final bibliography = CitationSyntax.bibliographyFor(
      markdown,
      citationSources,
    );
    final scientificIndex = ScientificReferenceSyntax.index(markdown);
    final chunks = _splitDocument(markdown, baseOffset: 0);
    return ListView.builder(
      controller: controller,
      padding: padding,
      scrollCacheExtent: const ScrollCacheExtent.pixels(640.0),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: chunks.length,
      itemBuilder:
          (context, index) => _buildContentChunk(
            context,
            chunks[index],
            bibliography,
            scientificIndex,
          ),
    );
  }

  List<Widget> _buildContentChunks(
    BuildContext context,
    String source, {
    required int baseOffset,
    required List<CitationSource> bibliography,
    required ScientificReferenceIndex scientificIndex,
  }) {
    final chunks = _splitDocument(source, baseOffset: baseOffset);
    return [
      for (final chunk in chunks)
        _buildContentChunk(context, chunk, bibliography, scientificIndex),
    ];
  }

  Widget _buildContentChunk(
    BuildContext context,
    _DocumentChunk chunk,
    List<CitationSource> bibliography,
    ScientificReferenceIndex scientificIndex,
  ) {
    return switch (chunk.kind) {
      _DocumentChunkKind.math => _DisplayMath(source: chunk.value),
      _DocumentChunkKind.image => _buildManagedImage(
        context,
        chunk.image!,
        scientificIndex,
      ),
      _DocumentChunkKind.columns => _buildManagedColumns(
        context,
        chunk.columns!,
        bibliography,
        scientificIndex,
      ),
      _DocumentChunkKind.markdown =>
        chunk.value.trim().isEmpty
            ? const SizedBox.shrink()
            : _buildMarkdownBody(chunk.value, bibliography, scientificIndex),
    };
  }

  Widget _buildMarkdownBody(
    String value,
    List<CitationSource> bibliography,
    ScientificReferenceIndex scientificIndex,
  ) {
    final citationRendered = CitationSyntax.renderMarkdownChunk(
      value,
      citationSources,
      bibliography: bibliography,
    );
    final rendered = ScientificReferenceSyntax.renderMarkdownChunk(
      citationRendered,
      scientificIndex,
    );
    return MarkdownBody(
      data: NoteDocument.convertWikiLinksToMarkdown(rendered),
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
    List<CitationSource> bibliography,
    ScientificReferenceIndex scientificIndex,
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
              bibliography: bibliography,
              scientificIndex: scientificIndex,
            ),
          ),
      ],
    );
  }

  Widget _buildManagedImage(
    BuildContext context,
    NoteImageReference reference,
    ScientificReferenceIndex scientificIndex,
  ) {
    return _ManagedNoteImage(
      reference: reference,
      scientificObject: scientificIndex.figureFor(reference),
      duplicateFigureId: scientificIndex.isDuplicate(
        ScientificObjectType.figure,
        reference.presentation.figureId,
      ),
      onEdit:
          reference.raw.isEmpty || onEditImage == null
              ? null
              : () => onEditImage!(reference),
      onResize:
          reference.raw.isEmpty || onResizeImage == null
              ? null
              : (presentation) => onResizeImage!(reference, presentation),
      child: _loadImage(reference.target, reference.alt, expand: true),
    );
  }

  Widget _loadImage(String target, String alt, {bool expand = false}) {
    if (target.toLowerCase().startsWith('data:')) {
      return _SafeDataNoteImage(
        key: ValueKey<String>('data-image:${target.hashCode}'),
        dataUri: target,
        fallbackLabel: alt,
        expand: expand,
      );
    }
    final uri = Uri.tryParse(target);
    if (uri == null) {
      return _ImageFallback(label: alt.isEmpty ? target : alt);
    }
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      if (uri.host.isEmpty || uri.userInfo.isNotEmpty) {
        return _ImageFallback(label: alt.isEmpty ? target : alt);
      }
      final domain = uri.host.toLowerCase();
      return _RemoteNoteImage(
        key: ValueKey<String>('remote-image:${uri.toString()}'),
        uri: uri,
        fallbackLabel: alt,
        expand: expand,
        policy: remoteImagePolicy,
        domainAllowed: allowedRemoteImageDomains.contains(domain),
        onAllowDomain: onAllowRemoteImageDomain,
      );
    }
    if (vaultRootPath.isNotEmpty &&
        uri.toString().toLowerCase().contains('attachments/')) {
      return _VaultAttachmentImage(
        rootPath: vaultRootPath,
        markdownPath: uri.toString(),
        fallbackLabel: alt.isEmpty ? target : alt,
        expand: expand,
        refreshListenable: assetListenable,
        loader: assetLoader ?? loadVaultAttachment,
      );
    }
    return _ImageFallback(label: alt.isEmpty ? target : alt);
  }
}

class _RemoteNoteImage extends StatefulWidget {
  const _RemoteNoteImage({
    super.key,
    required this.uri,
    required this.fallbackLabel,
    required this.expand,
    required this.policy,
    required this.domainAllowed,
    this.onAllowDomain,
  });

  final Uri uri;
  final String fallbackLabel;
  final bool expand;
  final RemoteImagePolicy policy;
  final bool domainAllowed;
  final ValueChanged<String>? onAllowDomain;

  @override
  State<_RemoteNoteImage> createState() => _RemoteNoteImageState();
}

class _RemoteNoteImageState extends State<_RemoteNoteImage> {
  late bool loadRequested = _loadsAutomatically;

  bool get _loadsAutomatically =>
      widget.policy == RemoteImagePolicy.allow || widget.domainAllowed;

  @override
  void didUpdateWidget(covariant _RemoteNoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri) {
      loadRequested = _loadsAutomatically;
    } else if (_loadsAutomatically) {
      loadRequested = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loadRequested) {
      return Image.network(
        widget.uri.toString(),
        width: widget.expand ? double.infinity : null,
        fit: BoxFit.contain,
        errorBuilder:
            (_, __, ___) => _ImageFallback(label: widget.fallbackLabel),
      );
    }

    final domain = widget.uri.host.toLowerCase();
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: ValueKey<String>('remote-image-blocked:$domain'),
      constraints: const BoxConstraints(minHeight: 104),
      width: widget.expand ? double.infinity : null,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Внешнее изображение заблокировано: $domain',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton(
                onPressed: () => setState(() => loadRequested = true),
                child: const Text('Загрузить один раз'),
              ),
              TextButton(
                onPressed: () {
                  widget.onAllowDomain?.call(domain);
                  setState(() => loadRequested = true);
                },
                child: const Text('Разрешить домен'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SafeDataNoteImage extends StatefulWidget {
  const _SafeDataNoteImage({
    super.key,
    required this.dataUri,
    required this.fallbackLabel,
    required this.expand,
  });

  final String dataUri;
  final String fallbackLabel;
  final bool expand;

  @override
  State<_SafeDataNoteImage> createState() => _SafeDataNoteImageState();
}

class _SafeDataNoteImageState extends State<_SafeDataNoteImage> {
  Uint8List? bytes;
  bool rejected = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _SafeDataNoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataUri != widget.dataUri) {
      bytes = null;
      rejected = false;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final candidate = await compute(_decodeBoundedNoteDataUri, widget.dataUri);
    if (candidate == null) {
      if (mounted) setState(() => rejected = true);
      return;
    }

    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    var dimensionsAllowed = false;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(candidate);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      dimensionsAllowed = noteDataImageDimensionsFit(
        width: descriptor.width,
        height: descriptor.height,
      );
    } on Object {
      dimensionsAllowed = false;
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }

    if (!mounted) return;
    setState(() {
      if (dimensionsAllowed) {
        bytes = candidate;
      } else {
        rejected = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final imageBytes = bytes;
    if (imageBytes != null) {
      return Image.memory(
        imageBytes,
        width: widget.expand ? double.infinity : null,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder:
            (_, __, ___) => _ImageFallback(label: widget.fallbackLabel),
      );
    }
    if (rejected) {
      return _ImageFallback(
        label:
            widget.fallbackLabel.isEmpty
                ? 'Встроенное изображение отклонено'
                : widget.fallbackLabel,
      );
    }
    return const SizedBox(
      height: 64,
      child: Center(child: Icon(Icons.image_outlined)),
    );
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
                    child: Tooltip(
                      message: 'Управление колонками',
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
    final normalized = NoteColumnsSyntax.normalizeWidths([
      for (final width in current) width.round(),
    ], current.length);
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
    required this.scientificObject,
    required this.duplicateFigureId,
    this.onEdit,
    this.onResize,
  });

  final NoteImageReference reference;
  final Widget child;
  final ScientificObjectReference? scientificObject;
  final bool duplicateFigureId;
  final VoidCallback? onEdit;
  final ValueChanged<NoteImagePresentation>? onResize;

  @override
  State<_ManagedNoteImage> createState() => _ManagedNoteImageState();
}

class _ManagedNoteImageState extends State<_ManagedNoteImage> {
  bool hovering = false;
  double? dragPercent;
  int? pendingWidthPercent;
  double availableWidth = 1;
  double queuedDragDeltaX = 0;
  bool dragFrameScheduled = false;

  bool get editable => widget.onEdit != null || widget.onResize != null;

  @override
  void didUpdateWidget(covariant _ManagedNoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pending = pendingWidthPercent;
    if (pending != null &&
        widget.reference.presentation.widthPercent == pending) {
      pendingWidthPercent = null;
    }
    if (oldWidget.reference.target != widget.reference.target ||
        oldWidget.reference.alt != widget.reference.alt) {
      dragPercent = null;
      pendingWidthPercent = null;
      queuedDragDeltaX = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final presentation = widget.reference.presentation;
    final effectivePercent =
        dragPercent ??
        pendingWidthPercent?.toDouble() ??
        presentation.widthPercent.toDouble();
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
              availableWidth *
              (effectivePercent.clamp(
                    NoteImageSyntax.minWidthPercent,
                    NoteImageSyntax.maxWidthPercent,
                  ) /
                  100);

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
                            child: RepaintBoundary(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: widget.child,
                              ),
                            ),
                          ),
                          if (editable &&
                              (hovering ||
                                  dragPercent != null ||
                                  pendingWidthPercent != null))
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
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (widget.onResize != null)
                                      PopupMenuButton<int>(
                                        tooltip: 'Размер изображения',
                                        onSelected: _applyQuickWidthAction,
                                        itemBuilder:
                                            (context) => <PopupMenuEntry<int>>[
                                              for (final width
                                                  in NoteImageSyntax
                                                      .widthPresets)
                                                CheckedPopupMenuItem<int>(
                                                  value: width,
                                                  checked:
                                                      NoteImageSyntax.normalizeWidthPercent(
                                                        effectivePercent,
                                                      ) ==
                                                      width,
                                                  child: Text(
                                                    width ==
                                                            NoteImageSyntax
                                                                .maxWidthPercent
                                                        ? '$width% · по ширине'
                                                        : '$width%',
                                                  ),
                                                ),
                                              const PopupMenuDivider(),
                                              const PopupMenuItem<int>(
                                                value:
                                                    _decreaseImageWidthAction,
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.remove_rounded,
                                                      size: 18,
                                                    ),
                                                    SizedBox(width: 10),
                                                    Text('Уменьшить на 5%'),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem<int>(
                                                value:
                                                    _increaseImageWidthAction,
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.add_rounded,
                                                      size: 18,
                                                    ),
                                                    SizedBox(width: 10),
                                                    Text('Увеличить на 5%'),
                                                  ],
                                                ),
                                              ),
                                            ],
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            11,
                                            7,
                                            8,
                                            7,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.aspect_ratio_rounded,
                                                size: 17,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                '${NoteImageSyntax.normalizeWidthPercent(effectivePercent)}%',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                              const SizedBox(width: 2),
                                              const Icon(
                                                Icons.arrow_drop_down_rounded,
                                                size: 18,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if (widget.onEdit != null)
                                      IconButton(
                                        tooltip: 'Другие настройки изображения',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: widget.onEdit,
                                        icon: const Icon(
                                          Icons.tune_rounded,
                                          size: 18,
                                        ),
                                      ),
                                  ],
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
                                  onHorizontalDragUpdate:
                                      (details) =>
                                          _queueResizeDelta(details.delta.dx),
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
                    if (presentation.caption.trim().isNotEmpty ||
                        widget.scientificObject != null ||
                        widget.duplicateFigureId) ...[
                      const SizedBox(height: 7),
                      Text(
                        _captionText(presentation),
                        textAlign: textAlign,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              widget.duplicateFigureId
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                          fontWeight:
                              widget.scientificObject != null ||
                                      widget.duplicateFigureId
                                  ? FontWeight.w700
                                  : null,
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

  String _captionText(NoteImagePresentation presentation) {
    final caption = presentation.caption.trim();
    if (widget.duplicateFigureId) {
      final id = presentation.figureId.trim();
      return '[повторяющийся ID рисунка: $id]${caption.isEmpty ? '' : ' — $caption'}';
    }
    final object = widget.scientificObject;
    if (object != null) {
      return '${object.label}${caption.isEmpty ? '' : ' — $caption'}';
    }
    return caption;
  }

  void _applyQuickWidthAction(int action) {
    final current = NoteImageSyntax.normalizeWidthPercent(
      pendingWidthPercent ?? widget.reference.presentation.widthPercent,
    );
    final next = switch (action) {
      _decreaseImageWidthAction => current - NoteImageSyntax.widthStepPercent,
      _increaseImageWidthAction => current + NoteImageSyntax.widthStepPercent,
      _ => action,
    };
    final normalized = NoteImageSyntax.normalizeWidthPercent(next);
    setState(() => pendingWidthPercent = normalized);
    widget.onResize?.call(
      widget.reference.presentation.copyWith(widthPercent: normalized),
    );
  }

  void _queueResizeDelta(double deltaX) {
    queuedDragDeltaX += deltaX;
    if (dragFrameScheduled) {
      return;
    }
    dragFrameScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      dragFrameScheduled = false;
      if (!mounted) {
        queuedDragDeltaX = 0;
        return;
      }
      _applyQueuedResizeDelta();
    });
  }

  void _applyQueuedResizeDelta({bool rebuild = true}) {
    final deltaX = queuedDragDeltaX;
    queuedDragDeltaX = 0;
    if (deltaX == 0 || availableWidth <= 0) {
      return;
    }
    final current =
        dragPercent ??
        pendingWidthPercent?.toDouble() ??
        widget.reference.presentation.widthPercent.toDouble();
    final next =
        (current + deltaX / availableWidth * 100)
            .clamp(
              NoteImageSyntax.minWidthPercent,
              NoteImageSyntax.maxWidthPercent,
            )
            .toDouble();
    if (rebuild) {
      setState(() => dragPercent = next);
    } else {
      dragPercent = next;
    }
  }

  void _finishResize() {
    _applyQueuedResizeDelta(rebuild: false);
    final current =
        dragPercent ??
        pendingWidthPercent?.toDouble() ??
        widget.reference.presentation.widthPercent.toDouble();
    final rounded = NoteImageSyntax.normalizeWidthPercent(
      (current / NoteImageSyntax.widthStepPercent).round() *
          NoteImageSyntax.widthStepPercent,
    );
    setState(() {
      dragPercent = null;
      pendingWidthPercent = rounded;
    });
    widget.onResize?.call(
      widget.reference.presentation.copyWith(widthPercent: rounded),
    );
  }

  void _cancelResize() {
    queuedDragDeltaX = 0;
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

class _VaultAttachmentImage extends StatefulWidget {
  const _VaultAttachmentImage({
    required this.rootPath,
    required this.markdownPath,
    required this.fallbackLabel,
    required this.expand,
    required this.loader,
    this.refreshListenable,
  });

  final String rootPath;
  final String markdownPath;
  final String fallbackLabel;
  final bool expand;
  final VaultAttachmentBytesLoader loader;
  final Listenable? refreshListenable;

  @override
  State<_VaultAttachmentImage> createState() => _VaultAttachmentImageState();
}

class _VaultAttachmentImageState extends State<_VaultAttachmentImage> {
  Uint8List? _bytes;
  bool _initialLoadPending = true;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    widget.refreshListenable?.addListener(_reload);
    _startLoad();
  }

  @override
  void didUpdateWidget(covariant _VaultAttachmentImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshListenable != widget.refreshListenable) {
      oldWidget.refreshListenable?.removeListener(_reload);
      widget.refreshListenable?.addListener(_reload);
    }
    if (oldWidget.rootPath != widget.rootPath ||
        oldWidget.markdownPath != widget.markdownPath ||
        oldWidget.loader != widget.loader) {
      _bytes = null;
      _initialLoadPending = true;
      _startLoad();
    }
  }

  @override
  void dispose() {
    _loadGeneration += 1;
    widget.refreshListenable?.removeListener(_reload);
    super.dispose();
  }

  Future<Uint8List?> _load() =>
      widget.loader(widget.rootPath, widget.markdownPath);

  void _startLoad() {
    final generation = ++_loadGeneration;
    unawaited(_completeLoad(generation));
  }

  Future<void> _completeLoad(int generation) async {
    final bytes = await _load();
    if (!mounted || generation != _loadGeneration) {
      return;
    }
    setState(() {
      _bytes = bytes;
      _initialLoadPending = false;
    });
  }

  void _reload() {
    if (!mounted) {
      return;
    }
    // Keep the current image/fallback visible while the new bytes are read.
    // The explicit setState in _completeLoad schedules a frame after dart:io
    // finishes, instead of relying on FutureBuilder timing.
    _startLoad();
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) {
      if (_initialLoadPending) {
        return const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return _ImageFallback(
        key: ValueKey('vault-image-fallback:${widget.markdownPath}'),
        label: widget.fallbackLabel,
      );
    }
    return Image.memory(
      bytes,
      key: ValueKey('vault-image:${widget.markdownPath}'),
      width: widget.expand ? double.infinity : null,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _ImageFallback(label: widget.fallbackLabel),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({super.key, this.label});

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

List<_DocumentChunk> _splitDocument(String source, {required int baseOffset}) {
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
  final fenceCount =
      RegExp(r'^[ \t]*(?:```|~~~)', multiLine: true).allMatches(before).length;
  if (fenceCount.isOdd) {
    return true;
  }

  final lineStart = source.lastIndexOf('\n', offset == 0 ? 0 : offset - 1) + 1;
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

Uint8List? _decodeBoundedNoteDataUri(String value) {
  final comma = value.indexOf(',');
  if (comma < 0 || comma > 256) {
    return null;
  }
  final metadata = value.substring(0, comma).toLowerCase();
  if (!metadata.startsWith('data:image/') ||
      !metadata.split(';').contains('base64')) {
    return null;
  }

  final payloadLength = value.length - comma - 1;
  if (!noteDataImageEncodedPayloadFits(encodedPayloadLength: payloadLength)) {
    return null;
  }
  var padding = 0;
  if (value.endsWith('==')) {
    padding = 2;
  } else if (value.endsWith('=')) {
    padding = 1;
  }
  final estimatedDecodedLength = (payloadLength * 3 ~/ 4) - padding;
  if (!noteDataImageDecodedLengthFits(estimatedDecodedLength)) {
    return null;
  }
  try {
    final decoded = base64Decode(value.substring(comma + 1));
    return noteDataImageDecodedLengthFits(decoded.length) ? decoded : null;
  } on Object {
    return null;
  }
}
