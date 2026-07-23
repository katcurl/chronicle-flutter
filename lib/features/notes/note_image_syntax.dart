import 'dart:convert';

enum NoteImageAlignment { left, center, right }

class NoteImagePresentation {
  const NoteImagePresentation({
    this.widthPercent = 100,
    this.alignment = NoteImageAlignment.center,
    this.caption = '',
    this.figureId = '',
  });

  final int widthPercent;
  final NoteImageAlignment alignment;
  final String caption;
  final String figureId;

  NoteImagePresentation copyWith({
    int? widthPercent,
    NoteImageAlignment? alignment,
    String? caption,
    String? figureId,
  }) {
    return NoteImagePresentation(
      widthPercent: NoteImageSyntax.normalizeWidthPercent(
        widthPercent ?? this.widthPercent,
      ),
      alignment: alignment ?? this.alignment,
      caption: caption ?? this.caption,
      figureId: figureId ?? this.figureId,
    );
  }

  String toMarkdownTitle() {
    final parts = <String>[
      NoteImageSyntax.metadataPrefix,
      'width=${NoteImageSyntax.normalizeWidthPercent(widthPercent)}',
      'align=${alignment.name}',
    ];
    final normalizedCaption = caption.trim();
    if (normalizedCaption.isNotEmpty) {
      parts.add('caption=${Uri.encodeComponent(normalizedCaption)}');
    }
    final normalizedFigureId = figureId.trim();
    if (normalizedFigureId.isNotEmpty) {
      parts.add('figure=${Uri.encodeComponent(normalizedFigureId)}');
    }
    return parts.join(' ');
  }

  static NoteImagePresentation fromMarkdownTitle(String? title) {
    final value = title?.trim() ?? '';
    if (!value.startsWith(NoteImageSyntax.metadataPrefix)) {
      return const NoteImagePresentation();
    }

    var width = 100;
    var alignment = NoteImageAlignment.center;
    var caption = '';
    var figureId = '';

    final metadata =
        value.substring(NoteImageSyntax.metadataPrefix.length).trim();
    final fieldPattern = RegExp(r'(?:^|\s)(width|align|caption|figure)=');
    final fields = fieldPattern.allMatches(metadata).toList();

    for (var index = 0; index < fields.length; index += 1) {
      final field = fields[index];
      final key = field.group(1)!;
      final rawEnd =
          index + 1 < fields.length ? fields[index + 1].start : metadata.length;
      final raw = metadata.substring(field.end, rawEnd).trim();
      if (raw.isEmpty) continue;

      switch (key) {
        case 'width':
          width = int.tryParse(raw) ?? width;
          break;
        case 'align':
          alignment = NoteImageAlignment.values.firstWhere(
            (candidate) => candidate.name == raw,
            orElse: () => alignment,
          );
          break;
        case 'caption':
          caption = NoteImageSyntax.decodeMetadataValue(raw);
          break;
        case 'figure':
          figureId = NoteImageSyntax.decodeMetadataValue(raw);
          break;
      }
    }

    return NoteImagePresentation(
      widthPercent: NoteImageSyntax.normalizeWidthPercent(width),
      alignment: alignment,
      caption: caption,
      figureId: figureId,
    );
  }
}

class NoteImageReference {
  const NoteImageReference({
    required this.start,
    required this.end,
    required this.raw,
    required this.alt,
    required this.target,
    required this.presentation,
  });

  final int start;
  final int end;
  final String raw;
  final String alt;
  final String target;
  final NoteImagePresentation presentation;

  NoteImageReference shifted(int delta) {
    if (delta == 0) {
      return this;
    }
    return NoteImageReference(
      start: start + delta,
      end: end + delta,
      raw: raw,
      alt: alt,
      target: target,
      presentation: presentation,
    );
  }

  String toMarkdown({NoteImagePresentation? presentation}) {
    final effective = presentation ?? this.presentation;
    final escapedAlt = alt.replaceAll('\\', '\\\\').replaceAll(']', '\\]');
    final renderedTarget =
        target.contains(RegExp(r'\s')) ? '<$target>' : target;
    return '![$escapedAlt]($renderedTarget "${effective.toMarkdownTitle()}")';
  }
}

class NoteImageSyntax {
  const NoteImageSyntax._();

  /// Decodes percent-encoded metadata without rejecting raw Unicode that may
  /// appear beside encoded bytes in older or manually edited notes.
  static String decodeMetadataValue(String value) {
    if (!value.contains('%')) {
      return value;
    }

    final output = StringBuffer();
    final encodedBytes = <int>[];

    void flushEncodedBytes() {
      if (encodedBytes.isEmpty) {
        return;
      }
      output.write(utf8.decode(encodedBytes, allowMalformed: true));
      encodedBytes.clear();
    }

    var index = 0;
    while (index < value.length) {
      if (value.codeUnitAt(index) == 0x25 && index + 2 < value.length) {
        final byte = int.tryParse(
          value.substring(index + 1, index + 3),
          radix: 16,
        );
        if (byte != null) {
          encodedBytes.add(byte);
          index += 3;
          continue;
        }
      }
      flushEncodedBytes();
      output.writeCharCode(value.codeUnitAt(index));
      index += 1;
    }
    flushEncodedBytes();
    return output.toString();
  }

  static const String metadataPrefix = 'chronicle-image';
  static const int minWidthPercent = 20;
  static const int maxWidthPercent = 100;
  static const int widthStepPercent = 5;
  static const List<int> widthPresets = <int>[25, 50, 75, 100];

  static int normalizeWidthPercent(num value) {
    return value.round().clamp(minWidthPercent, maxWidthPercent).toInt();
  }

  static final RegExp _imagePattern = RegExp(
    r'!\[((?:\\.|[^\]])*)\]\(\s*(<[^>]+>|[^\s)]+)(?:\s+"([^"]*)")?\s*\)',
    multiLine: true,
  );

  static Iterable<NoteImageReference> all(String markdown) sync* {
    for (final match in _imagePattern.allMatches(markdown)) {
      final rawTarget = match.group(2) ?? '';
      final target =
          rawTarget.startsWith('<') && rawTarget.endsWith('>')
              ? rawTarget.substring(1, rawTarget.length - 1)
              : rawTarget;
      yield NoteImageReference(
        start: match.start,
        end: match.end,
        raw: match.group(0) ?? '',
        alt: _unescapeAlt(match.group(1) ?? ''),
        target: target,
        presentation: NoteImagePresentation.fromMarkdownTitle(match.group(3)),
      );
    }
  }

  static NoteImageReference? first(String markdown) {
    final iterator = all(markdown).iterator;
    return iterator.moveNext() ? iterator.current : null;
  }

  static NoteImageReference? findAtOffset(String markdown, int offset) {
    final safeOffset = offset.clamp(0, markdown.length).toInt();
    final lineStart =
        markdown.lastIndexOf('\n', safeOffset == 0 ? 0 : safeOffset - 1) + 1;
    final nextBreak = markdown.indexOf('\n', safeOffset);
    final lineEnd = nextBreak < 0 ? markdown.length : nextBreak;

    for (final reference in all(markdown)) {
      if (safeOffset >= reference.start && safeOffset <= reference.end) {
        return reference;
      }
      if (reference.start >= lineStart && reference.end <= lineEnd) {
        return reference;
      }
    }
    return null;
  }

  static NoteImageReference? relocate(
    String markdown,
    NoteImageReference previous,
  ) {
    if (previous.start >= 0 &&
        previous.end <= markdown.length &&
        markdown.substring(previous.start, previous.end) == previous.raw) {
      return previous;
    }

    for (final reference in all(markdown)) {
      if (reference.raw == previous.raw) {
        return reference;
      }
    }
    for (final reference in all(markdown)) {
      if (reference.target == previous.target &&
          reference.alt == previous.alt) {
        return reference;
      }
    }
    return null;
  }

  static String _unescapeAlt(String value) {
    return value.replaceAllMapped(RegExp(r'\\(.)'), (match) => match.group(1)!);
  }
}
