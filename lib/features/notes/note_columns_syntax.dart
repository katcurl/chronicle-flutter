class NoteColumnsLayout {
  const NoteColumnsLayout({
    required this.columnCount,
    required this.widths,
  });

  final int columnCount;
  final List<int> widths;
}

class NoteColumnContent {
  const NoteColumnContent({
    required this.start,
    required this.end,
    required this.markdown,
  });

  final int start;
  final int end;
  final String markdown;

  NoteColumnContent shifted(int delta) {
    if (delta == 0) {
      return this;
    }
    return NoteColumnContent(
      start: start + delta,
      end: end + delta,
      markdown: markdown,
    );
  }
}

class NoteColumnsReference {
  const NoteColumnsReference({
    required this.start,
    required this.end,
    required this.raw,
    required this.widths,
    required this.columns,
  });

  final int start;
  final int end;
  final String raw;
  final List<int> widths;
  final List<NoteColumnContent> columns;

  int get columnCount => columns.length;

  NoteColumnsReference shifted(int delta) {
    if (delta == 0) {
      return this;
    }
    return NoteColumnsReference(
      start: start + delta,
      end: end + delta,
      raw: raw,
      widths: widths,
      columns: [for (final column in columns) column.shifted(delta)],
    );
  }

  List<String> orderedContents([List<int>? order]) {
    final normalizedOrder = NoteColumnsSyntax.normalizeOrder(
      order ?? [for (var index = 0; index < columnCount; index += 1) index],
      columnCount,
    );
    return [
      for (final index in normalizedOrder) columns[index].markdown,
    ];
  }

  String toPlainMarkdown({List<int>? order}) {
    return orderedContents(order)
        .map((content) => content.trim())
        .where((content) => content.isNotEmpty)
        .join('\n\n');
  }

  String toMarkdown({
    List<int>? widths,
    List<String>? contents,
  }) {
    final renderedContents = contents ?? orderedContents();
    final normalizedWidths = NoteColumnsSyntax.normalizeWidths(
      widths ?? this.widths,
      renderedContents.length,
    );
    return NoteColumnsSyntax.build(
      widths: normalizedWidths,
      contents: renderedContents,
    );
  }
}

class NoteColumnsSyntax {
  const NoteColumnsSyntax._();

  static const String startPrefix = '<!-- chronicle-columns';
  static const String dividerMarker = '<!-- chronicle-column -->';
  static const String endMarker = '<!-- /chronicle-columns -->';

  static final RegExp _startPattern = RegExp(
    r'^[ \t]*<!--\s*chronicle-columns(?:\s+widths=([0-9, \t]+))?\s*-->[ \t]*$',
    multiLine: true,
  );
  static final RegExp _dividerPattern = RegExp(
    r'^[ \t]*<!--\s*chronicle-column\s*-->[ \t]*$',
    multiLine: true,
  );
  static final RegExp _endPattern = RegExp(
    r'^[ \t]*<!--\s*/chronicle-columns\s*-->[ \t]*$',
    multiLine: true,
  );
  static final RegExp _allMarkerPattern = RegExp(
    r'^[ \t]*<!--\s*(?:chronicle-columns(?:\s+widths=[0-9, \t]+)?|chronicle-column|/chronicle-columns)\s*-->[ \t]*(?:\n|$)',
    multiLine: true,
  );

  static Iterable<NoteColumnsReference> all(String markdown) sync* {
    var occupiedUntil = -1;
    for (final startMatch in _startPattern.allMatches(markdown)) {
      if (startMatch.start < occupiedUntil ||
          _isInsideMarkdownCode(markdown, startMatch.start)) {
        continue;
      }

      RegExpMatch? endMatch;
      for (final candidate in _endPattern.allMatches(markdown, startMatch.end)) {
        if (!_isInsideMarkdownCode(markdown, candidate.start)) {
          endMatch = candidate;
          break;
        }
      }
      if (endMatch == null) {
        continue;
      }

      final dividers = <RegExpMatch>[];
      for (final divider in _dividerPattern.allMatches(
        markdown,
        startMatch.end,
      )) {
        if (divider.start >= endMatch.start) {
          break;
        }
        if (!_isInsideMarkdownCode(markdown, divider.start)) {
          dividers.add(divider);
        }
      }
      final columnCount = dividers.length + 1;
      if (columnCount < 2 || columnCount > 3) {
        continue;
      }

      final boundaries = <int>[
        _afterLineBreak(markdown, startMatch.end),
        for (final divider in dividers)
          _afterLineBreak(markdown, divider.end),
      ];
      final ends = <int>[
        for (final divider in dividers)
          _beforeLineBreak(markdown, divider.start),
        _beforeLineBreak(markdown, endMatch.start),
      ];
      final columns = <NoteColumnContent>[];
      for (var index = 0; index < columnCount; index += 1) {
        final start = boundaries[index].clamp(0, markdown.length).toInt();
        final end = ends[index].clamp(start, markdown.length).toInt();
        columns.add(
          NoteColumnContent(
            start: start,
            end: end,
            markdown: markdown.substring(start, end),
          ),
        );
      }

      final reference = NoteColumnsReference(
        start: startMatch.start,
        end: endMatch.end,
        raw: markdown.substring(startMatch.start, endMatch.end),
        widths: normalizeWidths(
          _parseWidths(startMatch.group(1)),
          columnCount,
        ),
        columns: columns,
      );
      occupiedUntil = reference.end;
      yield reference;
    }
  }

  static NoteColumnsReference? first(String markdown) {
    final iterator = all(markdown).iterator;
    return iterator.moveNext() ? iterator.current : null;
  }

  static NoteColumnsReference? findAtOffset(String markdown, int offset) {
    final safeOffset = offset.clamp(0, markdown.length).toInt();
    for (final reference in all(markdown)) {
      if (safeOffset >= reference.start && safeOffset <= reference.end) {
        return reference;
      }
    }
    return null;
  }

  static NoteColumnsReference? relocate(
    String markdown,
    NoteColumnsReference previous,
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
    return null;
  }

  static String build({
    required List<int> widths,
    required List<String> contents,
  }) {
    if (contents.length < 2 || contents.length > 3) {
      throw ArgumentError.value(
        contents.length,
        'contents.length',
        'Chronicle supports two or three columns',
      );
    }
    final normalizedWidths = normalizeWidths(widths, contents.length);
    final buffer = StringBuffer(
      '<!-- chronicle-columns widths=${normalizedWidths.join(',')} -->\n',
    );
    for (var index = 0; index < contents.length; index += 1) {
      if (index > 0) {
        buffer.writeln(dividerMarker);
      }
      final content = contents[index].trim();
      if (content.isNotEmpty) {
        buffer.writeln(content);
      }
    }
    buffer.write(endMarker);
    return buffer.toString();
  }

  static String stripMarkers(String markdown) {
    return markdown.replaceAll(_allMarkerPattern, ' ');
  }

  static List<String> normalizeContents(
    List<String> values,
    int count, {
    String placeholder = 'Новая колонка',
  }) {
    if (count < 2 || count > 3) {
      throw ArgumentError.value(count, 'count');
    }

    final normalized = List<String>.from(values);
    if (normalized.length > count) {
      final merged = normalized
          .sublist(count - 1)
          .map((content) => content.trim())
          .where((content) => content.isNotEmpty)
          .join('\n\n');
      normalized
        ..removeRange(count - 1, normalized.length)
        ..add(merged);
    }
    while (normalized.length < count) {
      normalized.add(placeholder);
    }
    return normalized;
  }

  static List<int> normalizeOrder(List<int> values, int count) {
    final identity = [for (var index = 0; index < count; index += 1) index];
    if (values.length != count) {
      return identity;
    }
    final unique = values.toSet();
    if (unique.length != count ||
        values.any((value) => value < 0 || value >= count)) {
      return identity;
    }
    return List<int>.from(values);
  }

  static List<int> normalizeWidths(List<int> values, int count) {
    if (count < 2 || count > 3) {
      throw ArgumentError.value(count, 'count');
    }
    final defaults = count == 2 ? const [50, 50] : const [34, 33, 33];
    if (values.length != count || values.any((value) => value <= 0)) {
      return List<int>.from(defaults);
    }

    final minimum = count == 2 ? 20 : 15;
    final clamped = [
      for (final value in values) value.clamp(minimum, 100).toInt(),
    ];
    final sum = clamped.fold<int>(0, (total, value) => total + value);
    if (sum <= 0) {
      return List<int>.from(defaults);
    }

    final normalized = <int>[];
    var assigned = 0;
    for (var index = 0; index < count - 1; index += 1) {
      final remainingMinimum = minimum * (count - index - 1);
      final scaled = (clamped[index] / sum * 100).round();
      final maximum = 100 - assigned - remainingMinimum;
      final value = scaled.clamp(minimum, maximum).toInt();
      normalized.add(value);
      assigned += value;
    }
    normalized.add(100 - assigned);
    return normalized;
  }

  static List<int> _parseWidths(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }
    return raw
        .split(',')
        .map((value) => int.tryParse(value.trim()))
        .whereType<int>()
        .toList();
  }

  static int _afterLineBreak(String source, int offset) {
    if (offset < source.length && source.codeUnitAt(offset) == 0x0d) {
      offset += 1;
    }
    if (offset < source.length && source.codeUnitAt(offset) == 0x0a) {
      offset += 1;
    }
    return offset;
  }

  static int _beforeLineBreak(String source, int offset) {
    var result = offset;
    if (result > 0 && source.codeUnitAt(result - 1) == 0x0a) {
      result -= 1;
    }
    if (result > 0 && source.codeUnitAt(result - 1) == 0x0d) {
      result -= 1;
    }
    return result;
  }

  static bool _isInsideMarkdownCode(String source, int offset) {
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
}
