enum NoteImageAlignment { left, center, right }

class NoteImagePresentation {
  const NoteImagePresentation({
    this.widthPercent = 100,
    this.alignment = NoteImageAlignment.center,
    this.caption = '',
  });

  final int widthPercent;
  final NoteImageAlignment alignment;
  final String caption;

  NoteImagePresentation copyWith({
    int? widthPercent,
    NoteImageAlignment? alignment,
    String? caption,
  }) {
    return NoteImagePresentation(
      widthPercent: _normalizeWidth(widthPercent ?? this.widthPercent),
      alignment: alignment ?? this.alignment,
      caption: caption ?? this.caption,
    );
  }

  String toMarkdownTitle() {
    final parts = <String>[
      NoteImageSyntax.metadataPrefix,
      'width=${_normalizeWidth(widthPercent)}',
      'align=${alignment.name}',
    ];
    final normalizedCaption = caption.trim();
    if (normalizedCaption.isNotEmpty) {
      parts.add('caption=${Uri.encodeComponent(normalizedCaption)}');
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

    for (final token in value.split(RegExp(r'\s+')).skip(1)) {
      final separator = token.indexOf('=');
      if (separator <= 0 || separator == token.length - 1) {
        continue;
      }
      final key = token.substring(0, separator);
      final raw = token.substring(separator + 1);
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
          try {
            caption = Uri.decodeComponent(raw);
          } on Object {
            caption = raw;
          }
          break;
      }
    }

    return NoteImagePresentation(
      widthPercent: _normalizeWidth(width),
      alignment: alignment,
      caption: caption,
    );
  }

  static int _normalizeWidth(int value) => value.clamp(20, 100).toInt();
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

  static const String metadataPrefix = 'chronicle-image';

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
    return value.replaceAllMapped(
      RegExp(r'\\(.)'),
      (match) => match.group(1)!,
    );
  }
}
