import 'note_image_syntax.dart';

enum ScientificObjectType { figure, table }

extension ScientificObjectTypeLabel on ScientificObjectType {
  String get singularLower => switch (this) {
    ScientificObjectType.figure => 'рисунок',
    ScientificObjectType.table => 'таблица',
  };

  String get singularTitle => switch (this) {
    ScientificObjectType.figure => 'Рисунок',
    ScientificObjectType.table => 'Таблица',
  };

  String get tokenPrefix => switch (this) {
    ScientificObjectType.figure => 'fig',
    ScientificObjectType.table => 'tbl',
  };
}

class ScientificObjectReference {
  const ScientificObjectReference({
    required this.type,
    required this.id,
    required this.number,
    required this.caption,
    required this.start,
    required this.end,
  });

  final ScientificObjectType type;
  final String id;
  final int number;
  final String caption;
  final int start;
  final int end;

  String get key => '${type.name}:$id';
  String get label => '${type.singularTitle} $number';
  String get inlineLabel => '${type.singularLower} $number';
  String get markdownReference => '@${type.tokenPrefix}($id)';
}

class ScientificCrossReference {
  const ScientificCrossReference({
    required this.type,
    required this.id,
    required this.start,
    required this.end,
    required this.raw,
  });

  final ScientificObjectType type;
  final String id;
  final int start;
  final int end;
  final String raw;

  String get key => '${type.name}:$id';
}

class ScientificTableReference {
  const ScientificTableReference({
    required this.id,
    required this.caption,
    required this.start,
    required this.end,
    required this.markerEnd,
    required this.raw,
  });

  final String id;
  final String caption;
  final int start;
  final int end;
  final int markerEnd;
  final String raw;
}

class ScientificReferenceIndex {
  const ScientificReferenceIndex({
    required this.objects,
    required this.crossReferences,
    required this.duplicateKeys,
  });

  final List<ScientificObjectReference> objects;
  final List<ScientificCrossReference> crossReferences;
  final Set<String> duplicateKeys;

  ScientificObjectReference? objectFor(ScientificObjectType type, String id) {
    final key = '${type.name}:$id';
    if (duplicateKeys.contains(key)) {
      return null;
    }
    for (final object in objects) {
      if (object.key == key) {
        return object;
      }
    }
    return null;
  }

  ScientificObjectReference? figureFor(NoteImageReference image) {
    final id = image.presentation.figureId.trim();
    if (id.isEmpty) {
      return null;
    }
    return objectFor(ScientificObjectType.figure, id);
  }

  bool isDuplicate(ScientificObjectType type, String id) {
    return duplicateKeys.contains('${type.name}:$id');
  }

  List<ScientificCrossReference> get brokenCrossReferences => [
    for (final reference in crossReferences)
      if (!duplicateKeys.contains(reference.key) &&
          objectFor(reference.type, reference.id) == null)
        reference,
  ];

  List<ScientificCrossReference> get ambiguousCrossReferences => [
    for (final reference in crossReferences)
      if (duplicateKeys.contains(reference.key)) reference,
  ];

  bool get hasWarnings =>
      duplicateKeys.isNotEmpty ||
      brokenCrossReferences.isNotEmpty ||
      ambiguousCrossReferences.isNotEmpty;
}

class ScientificTableDraft {
  const ScientificTableDraft({
    required this.id,
    required this.caption,
    required this.columns,
    required this.rows,
  });

  final String id;
  final String caption;
  final int columns;
  final int rows;

  String toMarkdown() {
    final safeColumns = columns.clamp(2, 8).toInt();
    final safeRows = rows.clamp(1, 20).toInt();
    final headerCells = [
      for (var index = 1; index <= safeColumns; index += 1) 'Столбец $index',
    ];
    final separatorCells = [
      for (var index = 0; index < safeColumns; index += 1) '---',
    ];
    final emptyCells = [
      for (var index = 0; index < safeColumns; index += 1) ' ',
    ];
    final header = '| ${headerCells.join(' | ')} |';
    final separator = '| ${separatorCells.join(' | ')} |';
    final emptyRow = '| ${emptyCells.join(' | ')} |';
    final body = [for (var row = 0; row < safeRows; row += 1) emptyRow];
    return [
      ScientificReferenceSyntax.tableMarker(id: id, caption: caption),
      header,
      separator,
      ...body,
    ].join('\n');
  }
}

class ScientificReferenceSyntax {
  const ScientificReferenceSyntax._();

  static final RegExp _crossReferencePattern = RegExp(
    r'@(fig|tbl)\(([A-Za-z0-9][A-Za-z0-9._-]{0,79})\)',
  );
  static final RegExp _tableMarkerPattern = RegExp(
    r'^[ \t]*<!--\s*chronicle-table\s+id=([^\s>]+)(?:\s+caption=([^\s>]+))?\s*-->[ \t]*$',
    multiLine: true,
  );
  static final RegExp _tableSeparatorCell = RegExp(r'^:?-{3,}:?$');
  static final RegExp _validIdPattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$',
  );

  static bool isValidId(String value) => _validIdPattern.hasMatch(value.trim());

  static String normalizeId(String value) {
    var normalized = value.trim().toLowerCase();
    normalized = normalized
        .replaceAll(RegExp(r'[^a-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^[-._]+|[-._]+$'), '');
    if (normalized.length > 80) {
      normalized = normalized
          .substring(0, 80)
          .replaceFirst(RegExp(r'[-._]+$'), '');
    }
    if (normalized.isEmpty || !RegExp(r'^[A-Za-z0-9]').hasMatch(normalized)) {
      normalized = 'object-$normalized'.replaceFirst(RegExp(r'-$'), '');
    }
    return normalized;
  }

  static String tableMarker({required String id, required String caption}) {
    final normalizedId = normalizeId(id);
    final normalizedCaption = caption.trim();
    final captionPart =
        normalizedCaption.isEmpty
            ? ''
            : ' caption=${Uri.encodeComponent(normalizedCaption)}';
    return '<!-- chronicle-table id=$normalizedId$captionPart -->';
  }

  static List<ScientificTableReference> tables(String markdown) {
    final result = <ScientificTableReference>[];
    for (final match in _tableMarkerPattern.allMatches(markdown)) {
      if (_isInsideMarkdownCode(markdown, match.start)) {
        continue;
      }
      final id = _decode(match.group(1) ?? '').trim();
      if (!isValidId(id)) {
        continue;
      }
      final caption = _decode(match.group(2) ?? '').trim();
      final firstLineStart = _nextLineStart(markdown, match.end);
      if (firstLineStart == null) {
        continue;
      }
      final firstLineEnd = _lineEnd(markdown, firstLineStart);
      final separatorStart = _nextLineStart(markdown, firstLineEnd);
      if (separatorStart == null) {
        continue;
      }
      final separatorEnd = _lineEnd(markdown, separatorStart);
      final header = markdown.substring(firstLineStart, firstLineEnd);
      final separator = markdown.substring(separatorStart, separatorEnd);
      if (!_looksLikeTableHeader(header) ||
          !_looksLikeTableSeparator(separator)) {
        continue;
      }

      var tableEnd = separatorEnd;
      var cursor = _nextLineStart(markdown, separatorEnd);
      while (cursor != null && cursor < markdown.length) {
        final end = _lineEnd(markdown, cursor);
        final line = markdown.substring(cursor, end);
        if (line.trim().isEmpty || !_looksLikeTableRow(line)) {
          break;
        }
        tableEnd = end;
        cursor = _nextLineStart(markdown, end);
      }
      result.add(
        ScientificTableReference(
          id: id,
          caption: caption,
          start: match.start,
          end: tableEnd,
          markerEnd: match.end,
          raw: markdown.substring(match.start, tableEnd),
        ),
      );
    }
    return result;
  }

  static List<ScientificCrossReference> crossReferences(String markdown) {
    final result = <ScientificCrossReference>[];
    for (final match in _crossReferencePattern.allMatches(markdown)) {
      if (_isInsideMarkdownCode(markdown, match.start)) {
        continue;
      }
      final type =
          match.group(1) == 'fig'
              ? ScientificObjectType.figure
              : ScientificObjectType.table;
      result.add(
        ScientificCrossReference(
          type: type,
          id: match.group(2) ?? '',
          start: match.start,
          end: match.end,
          raw: match.group(0) ?? '',
        ),
      );
    }
    return result;
  }

  static ScientificReferenceIndex index(String markdown) {
    final candidates = <_ScientificCandidate>[];
    for (final image in NoteImageSyntax.all(markdown)) {
      final id = image.presentation.figureId.trim();
      if (id.isEmpty ||
          !isValidId(id) ||
          _isInsideMarkdownCode(markdown, image.start) ||
          !_isStandaloneImage(markdown, image)) {
        continue;
      }
      candidates.add(
        _ScientificCandidate(
          type: ScientificObjectType.figure,
          id: id,
          caption: image.presentation.caption.trim(),
          start: image.start,
          end: image.end,
        ),
      );
    }
    for (final table in tables(markdown)) {
      candidates.add(
        _ScientificCandidate(
          type: ScientificObjectType.table,
          id: table.id,
          caption: table.caption,
          start: table.start,
          end: table.end,
        ),
      );
    }
    candidates.sort((left, right) => left.start.compareTo(right.start));

    final counts = <String, int>{};
    for (final candidate in candidates) {
      counts[candidate.key] = (counts[candidate.key] ?? 0) + 1;
    }
    final duplicateKeys = <String>{
      for (final entry in counts.entries)
        if (entry.value > 1) entry.key,
    };

    var figureNumber = 0;
    var tableNumber = 0;
    final objects = <ScientificObjectReference>[];
    for (final candidate in candidates) {
      final int number;
      if (candidate.type == ScientificObjectType.figure) {
        figureNumber += 1;
        number = figureNumber;
      } else {
        tableNumber += 1;
        number = tableNumber;
      }
      objects.add(
        ScientificObjectReference(
          type: candidate.type,
          id: candidate.id,
          number: number,
          caption: candidate.caption,
          start: candidate.start,
          end: candidate.end,
        ),
      );
    }

    return ScientificReferenceIndex(
      objects: objects,
      crossReferences: crossReferences(markdown),
      duplicateKeys: duplicateKeys,
    );
  }

  static String renderMarkdownChunk(
    String markdown,
    ScientificReferenceIndex index,
  ) {
    var rendered = markdown;
    final replacements = <_Replacement>[];

    for (final match in _tableMarkerPattern.allMatches(markdown)) {
      if (_isInsideMarkdownCode(markdown, match.start)) {
        continue;
      }
      final id = _decode(match.group(1) ?? '').trim();
      final caption = _decode(match.group(2) ?? '').trim();
      final object = index.objectFor(ScientificObjectType.table, id);
      final captionLine =
          index.isDuplicate(ScientificObjectType.table, id)
              ? '**[повторяющийся идентификатор таблицы: $id]**'
              : object == null
              ? '**[некорректная таблица: $id]**'
              : '**${object.label}${caption.isEmpty ? '' : ' — $caption'}**';
      final replacement = '$captionLine\n';
      replacements.add(
        _Replacement(start: match.start, end: match.end, value: replacement),
      );
    }

    for (final match in _crossReferencePattern.allMatches(markdown)) {
      if (_isInsideMarkdownCode(markdown, match.start)) {
        continue;
      }
      final type =
          match.group(1) == 'fig'
              ? ScientificObjectType.figure
              : ScientificObjectType.table;
      final id = match.group(2) ?? '';
      final object = index.objectFor(type, id);
      final replacement =
          index.isDuplicate(type, id)
              ? '**[неоднозначная ссылка: ${type.singularLower} $id]**'
              : object == null
              ? '**[нет объекта: ${type.singularLower} $id]**'
              : '**${object.inlineLabel}**';
      replacements.add(
        _Replacement(start: match.start, end: match.end, value: replacement),
      );
    }

    replacements.sort((left, right) => right.start.compareTo(left.start));
    for (final replacement in replacements) {
      rendered = rendered.replaceRange(
        replacement.start,
        replacement.end,
        replacement.value,
      );
    }
    return rendered;
  }

  static String stripMarkersForWordCount(String markdown) {
    return markdown
        .replaceAll(_tableMarkerPattern, ' ')
        .replaceAll(_crossReferencePattern, ' ');
  }

  static bool isTableMarkerLine(String text) {
    return _tableMarkerPattern.hasMatch(text);
  }

  static int? _nextLineStart(String source, int offset) {
    if (offset >= source.length) {
      return null;
    }
    if (source.codeUnitAt(offset) == 0x0a) {
      return offset + 1;
    }
    final newline = source.indexOf('\n', offset);
    return newline < 0 ? null : newline + 1;
  }

  static int _lineEnd(String source, int start) {
    final newline = source.indexOf('\n', start);
    return newline < 0 ? source.length : newline;
  }

  static bool _looksLikeTableHeader(String line) {
    final trimmed = line.trim();
    return trimmed.contains('|') &&
        trimmed.replaceAll('|', '').trim().isNotEmpty;
  }

  static bool _looksLikeTableSeparator(String line) {
    final cells = _tableCells(line);
    return cells.length >= 2 && cells.every(_tableSeparatorCell.hasMatch);
  }

  static bool _looksLikeTableRow(String line) {
    final trimmed = line.trim();
    return trimmed.contains('|');
  }

  static List<String> _tableCells(String line) {
    var trimmed = line.trim();
    if (trimmed.startsWith('|')) {
      trimmed = trimmed.substring(1);
    }
    if (trimmed.endsWith('|')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed.split('|').map((cell) => cell.trim()).toList();
  }

  static String _decode(String value) {
    try {
      return Uri.decodeComponent(value);
    } on Object {
      return value;
    }
  }
}

class _ScientificCandidate {
  const _ScientificCandidate({
    required this.type,
    required this.id,
    required this.caption,
    required this.start,
    required this.end,
  });

  final ScientificObjectType type;
  final String id;
  final String caption;
  final int start;
  final int end;

  String get key => '${type.name}:$id';
}

class _Replacement {
  const _Replacement({
    required this.start,
    required this.end,
    required this.value,
  });

  final int start;
  final int end;
  final String value;
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
