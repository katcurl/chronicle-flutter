import 'note_image_syntax.dart';
import 'scientific_reference_syntax.dart';

enum NoteBlockType {
  paragraph,
  heading,
  bulletedList,
  checklist,
  quote,
  code,
  math,
  image,
  table,
  columns,
  divider,
}

enum NoteBlockConversion {
  paragraph,
  heading1,
  heading2,
  bulletedList,
  checklist,
  quote,
}

class NoteBlockReference {
  const NoteBlockReference({
    required this.start,
    required this.end,
    required this.index,
    required this.type,
    required this.raw,
  });

  final int start;
  final int end;
  final int index;
  final NoteBlockType type;
  final String raw;

  bool get supportsTextConversion => switch (type) {
    NoteBlockType.paragraph ||
    NoteBlockType.heading ||
    NoteBlockType.bulletedList ||
    NoteBlockType.checklist ||
    NoteBlockType.quote => true,
    _ => false,
  };

  String get label => switch (type) {
    NoteBlockType.paragraph => 'Абзац',
    NoteBlockType.heading => 'Заголовок',
    NoteBlockType.bulletedList => 'Список',
    NoteBlockType.checklist => 'Чек-лист',
    NoteBlockType.quote => 'Цитата',
    NoteBlockType.code => 'Код',
    NoteBlockType.math => 'Формула',
    NoteBlockType.image => 'Изображение',
    NoteBlockType.table => 'Таблица',
    NoteBlockType.columns => 'Колонки',
    NoteBlockType.divider => 'Разделитель',
  };
}

class NoteBlockEditResult {
  const NoteBlockEditResult({
    required this.text,
    required this.selectionStart,
    required this.selectionEnd,
  });

  final String text;
  final int selectionStart;
  final int selectionEnd;
}

class NoteBlockSyntax {
  const NoteBlockSyntax._();

  static final RegExp _columnsStart = RegExp(
    r'^[ \t]*<!--\s*chronicle-columns(?:\s+widths=[0-9, \t]+)?\s*-->[ \t]*$',
  );
  static final RegExp _columnsEnd = RegExp(
    r'^[ \t]*<!--\s*/chronicle-columns\s*-->[ \t]*$',
  );
  static final RegExp _heading = RegExp(r'^\s{0,3}#{1,6}(?:\s+|$)');
  static final RegExp _checklist = RegExp(r'^\s{0,3}[-*+]\s+\[[ xX]\]\s+');
  static final RegExp _list = RegExp(r'^\s{0,3}(?:[-*+]\s+|\d+[.)]\s+)');
  static final RegExp _quote = RegExp(r'^\s{0,3}>');
  static final RegExp _divider = RegExp(
    r'^\s{0,3}(?:(?:\*\s*){3,}|(?:-\s*){3,}|(?:_\s*){3,})$',
  );
  static final RegExp _fenceStart = RegExp(r'^\s{0,3}(`{3,}|~{3,})');

  static List<NoteBlockReference> all(String source) {
    if (source.isEmpty) {
      return const [];
    }
    final lines = _LineSpan.parse(source);
    final tablesByStart = {
      for (final table in ScientificReferenceSyntax.tables(source))
        table.start: table,
    };
    final blocks = <NoteBlockReference>[];
    var lineIndex = 0;

    void addBlock(int firstLine, int lastLine, NoteBlockType type) {
      final start = lines[firstLine].start;
      final end = lines[lastLine].contentEnd;
      blocks.add(
        NoteBlockReference(
          start: start,
          end: end,
          index: blocks.length,
          type: type,
          raw: source.substring(start, end),
        ),
      );
    }

    while (lineIndex < lines.length) {
      if (lines[lineIndex].text.trim().isEmpty) {
        lineIndex += 1;
        continue;
      }

      final text = lines[lineIndex].text;
      final table = tablesByStart[lines[lineIndex].start];
      if (table != null) {
        var endLine = lineIndex;
        while (endLine + 1 < lines.length &&
            lines[endLine].contentEnd < table.end) {
          endLine += 1;
        }
        addBlock(lineIndex, endLine, NoteBlockType.table);
        lineIndex = endLine + 1;
        continue;
      }
      if (_columnsStart.hasMatch(text)) {
        var endLine = lineIndex;
        while (endLine + 1 < lines.length) {
          endLine += 1;
          if (_columnsEnd.hasMatch(lines[endLine].text)) {
            break;
          }
        }
        addBlock(lineIndex, endLine, NoteBlockType.columns);
        lineIndex = endLine + 1;
        continue;
      }

      final fence = _fenceStart.firstMatch(text);
      if (fence != null) {
        final token = fence.group(1)!;
        final marker = token[0];
        final minimumLength = token.length;
        var endLine = lineIndex;
        while (endLine + 1 < lines.length) {
          endLine += 1;
          if (_isFenceEnd(lines[endLine].text, marker, minimumLength)) {
            break;
          }
        }
        addBlock(lineIndex, endLine, NoteBlockType.code);
        lineIndex = endLine + 1;
        continue;
      }

      if (text.trim() == r'\[') {
        var endLine = lineIndex;
        while (endLine + 1 < lines.length) {
          endLine += 1;
          if (lines[endLine].text.trim() == r'\]') {
            break;
          }
        }
        addBlock(lineIndex, endLine, NoteBlockType.math);
        lineIndex = endLine + 1;
        continue;
      }

      if (_heading.hasMatch(text)) {
        addBlock(lineIndex, lineIndex, NoteBlockType.heading);
        lineIndex += 1;
        continue;
      }
      if (_divider.hasMatch(text)) {
        addBlock(lineIndex, lineIndex, NoteBlockType.divider);
        lineIndex += 1;
        continue;
      }
      if (_isWholeLineImage(text)) {
        addBlock(lineIndex, lineIndex, NoteBlockType.image);
        lineIndex += 1;
        continue;
      }
      if (_checklist.hasMatch(text)) {
        final endLine = _consumeList(lines, lineIndex, checklist: true);
        addBlock(lineIndex, endLine, NoteBlockType.checklist);
        lineIndex = endLine + 1;
        continue;
      }
      if (_list.hasMatch(text)) {
        final endLine = _consumeList(lines, lineIndex, checklist: false);
        addBlock(lineIndex, endLine, NoteBlockType.bulletedList);
        lineIndex = endLine + 1;
        continue;
      }
      if (_quote.hasMatch(text)) {
        var endLine = lineIndex;
        while (endLine + 1 < lines.length &&
            lines[endLine + 1].text.trim().isNotEmpty &&
            _quote.hasMatch(lines[endLine + 1].text)) {
          endLine += 1;
        }
        addBlock(lineIndex, endLine, NoteBlockType.quote);
        lineIndex = endLine + 1;
        continue;
      }

      var endLine = lineIndex;
      while (endLine + 1 < lines.length) {
        final next = lines[endLine + 1].text;
        if (next.trim().isEmpty || _startsIndependentBlock(next)) {
          break;
        }
        endLine += 1;
      }
      addBlock(lineIndex, endLine, NoteBlockType.paragraph);
      lineIndex = endLine + 1;
    }

    return blocks;
  }

  static NoteBlockReference? findAtOffset(String source, int offset) {
    return findIn(all(source), source.length, offset);
  }

  static NoteBlockReference? findIn(
    List<NoteBlockReference> blocks,
    int sourceLength,
    int offset,
  ) {
    return _findIn(blocks, sourceLength, offset);
  }

  static NoteBlockEditResult? moveUp(String source, int offset) {
    final blocks = all(source);
    final current = _findIn(blocks, source.length, offset);
    if (current == null || current.index == 0) {
      return null;
    }
    final previous = blocks[current.index - 1];
    final separator = source.substring(previous.end, current.start);
    final replacement = '${current.raw}$separator${previous.raw}';
    return NoteBlockEditResult(
      text: source.replaceRange(previous.start, current.end, replacement),
      selectionStart: previous.start,
      selectionEnd: previous.start + current.raw.length,
    );
  }

  static NoteBlockEditResult? moveDown(String source, int offset) {
    final blocks = all(source);
    final current = _findIn(blocks, source.length, offset);
    if (current == null || current.index >= blocks.length - 1) {
      return null;
    }
    final next = blocks[current.index + 1];
    final separator = source.substring(current.end, next.start);
    final replacement = '${next.raw}$separator${current.raw}';
    final movedStart = current.start + next.raw.length + separator.length;
    return NoteBlockEditResult(
      text: source.replaceRange(current.start, next.end, replacement),
      selectionStart: movedStart,
      selectionEnd: movedStart + current.raw.length,
    );
  }

  static NoteBlockEditResult? reorder(
    String source,
    List<int> order, {
    int? selectedOriginalIndex,
  }) {
    final blocks = all(source);
    if (blocks.length < 2 || order.length != blocks.length) {
      return null;
    }

    final seen = List<bool>.filled(blocks.length, false);
    var changed = false;
    for (var index = 0; index < order.length; index += 1) {
      final originalIndex = order[index];
      if (originalIndex < 0 ||
          originalIndex >= blocks.length ||
          seen[originalIndex]) {
        return null;
      }
      seen[originalIndex] = true;
      changed = changed || originalIndex != index;
    }
    if (!changed) {
      return null;
    }

    final separators = <String>[
      for (var index = 0; index < blocks.length - 1; index += 1)
        source.substring(blocks[index].end, blocks[index + 1].start),
    ];
    final prefix = source.substring(0, blocks.first.start);
    final suffix = source.substring(blocks.last.end);
    var fallbackSelectionIndex = order.first;
    for (var slot = 0; slot < order.length; slot += 1) {
      if (order[slot] != slot) {
        fallbackSelectionIndex = order[slot];
        break;
      }
    }
    final selectedIndex =
        selectedOriginalIndex != null &&
                selectedOriginalIndex >= 0 &&
                selectedOriginalIndex < blocks.length
            ? selectedOriginalIndex
            : fallbackSelectionIndex;

    final buffer = StringBuffer(prefix);
    var selectionStart = prefix.length;
    var selectionEnd = prefix.length;
    for (var slot = 0; slot < order.length; slot += 1) {
      final originalIndex = order[slot];
      final block = blocks[originalIndex];
      final blockStart = buffer.length;
      buffer.write(block.raw);
      final blockEnd = buffer.length;
      if (originalIndex == selectedIndex) {
        selectionStart = blockStart;
        selectionEnd = blockEnd;
      }
      if (slot < separators.length) {
        buffer.write(separators[slot]);
      }
    }
    buffer.write(suffix);

    return NoteBlockEditResult(
      text: buffer.toString(),
      selectionStart: selectionStart,
      selectionEnd: selectionEnd,
    );
  }

  static NoteBlockEditResult? duplicate(String source, int offset) {
    final blocks = all(source);
    final current = _findIn(blocks, source.length, offset);
    if (current == null) {
      return null;
    }
    final separator =
        current.index < blocks.length - 1
            ? source.substring(current.end, blocks[current.index + 1].start)
            : source.substring(current.end).isNotEmpty
            ? source.substring(current.end)
            : '\n\n';
    final insertion = '$separator${current.raw}';
    final copyStart = current.end + separator.length;
    return NoteBlockEditResult(
      text: source.replaceRange(current.end, current.end, insertion),
      selectionStart: copyStart,
      selectionEnd: copyStart + current.raw.length,
    );
  }

  static NoteBlockEditResult? delete(String source, int offset) {
    final blocks = all(source);
    final current = _findIn(blocks, source.length, offset);
    if (current == null) {
      return null;
    }
    if (blocks.length == 1) {
      return const NoteBlockEditResult(
        text: '',
        selectionStart: 0,
        selectionEnd: 0,
      );
    }
    if (current.index < blocks.length - 1) {
      final next = blocks[current.index + 1];
      return NoteBlockEditResult(
        text: source.replaceRange(current.start, next.start, ''),
        selectionStart: current.start,
        selectionEnd: current.start,
      );
    }
    final previous = blocks[current.index - 1];
    return NoteBlockEditResult(
      text: source.replaceRange(previous.end, current.end, ''),
      selectionStart: previous.end,
      selectionEnd: previous.end,
    );
  }

  static NoteBlockEditResult? convert(
    String source,
    int offset,
    NoteBlockConversion conversion,
  ) {
    final blocks = all(source);
    final current = _findIn(blocks, source.length, offset);
    if (current == null || !current.supportsTextConversion) {
      return null;
    }
    final plainLines = _plainTextLines(current.raw);
    final replacement = switch (conversion) {
      NoteBlockConversion.paragraph
          when current.type == NoteBlockType.paragraph =>
        current.raw,
      NoteBlockConversion.bulletedList
          when current.type == NoteBlockType.bulletedList =>
        current.raw,
      NoteBlockConversion.checklist
          when current.type == NoteBlockType.checklist =>
        current.raw,
      NoteBlockConversion.quote when current.type == NoteBlockType.quote =>
        current.raw,
      NoteBlockConversion.paragraph => plainLines.join('\n'),
      NoteBlockConversion.heading1 => '# ${_singleLine(plainLines)}',
      NoteBlockConversion.heading2 => '## ${_singleLine(plainLines)}',
      NoteBlockConversion.bulletedList => plainLines
          .where((line) => line.isNotEmpty)
          .map((line) => '- $line')
          .join('\n'),
      NoteBlockConversion.checklist => plainLines
          .where((line) => line.isNotEmpty)
          .map((line) => '- [ ] $line')
          .join('\n'),
      NoteBlockConversion.quote => plainLines
          .map((line) => line.isEmpty ? '>' : '> $line')
          .join('\n'),
    };
    return NoteBlockEditResult(
      text: source.replaceRange(current.start, current.end, replacement),
      selectionStart: current.start,
      selectionEnd: current.start + replacement.length,
    );
  }

  static NoteBlockReference? _findIn(
    List<NoteBlockReference> blocks,
    int sourceLength,
    int offset,
  ) {
    if (blocks.isEmpty) {
      return null;
    }
    final safeOffset = offset.clamp(0, sourceLength).toInt();
    var low = 0;
    var high = blocks.length - 1;

    while (low <= high) {
      final middle = low + ((high - low) >> 1);
      final block = blocks[middle];
      if (safeOffset < block.start) {
        high = middle - 1;
      } else if (safeOffset > block.end) {
        low = middle + 1;
      } else {
        return block;
      }
    }

    final previous = high >= 0 ? blocks[high] : null;
    final next = low < blocks.length ? blocks[low] : null;
    if (previous == null) {
      return next;
    }
    if (next == null) {
      return previous;
    }
    return safeOffset - previous.end <= next.start - safeOffset
        ? previous
        : next;
  }

  static bool _startsIndependentBlock(String text) {
    final trimmed = text.trim();
    return ScientificReferenceSyntax.isTableMarkerLine(text) ||
        _columnsStart.hasMatch(text) ||
        _fenceStart.hasMatch(text) ||
        trimmed == r'\[' ||
        _heading.hasMatch(text) ||
        _divider.hasMatch(text) ||
        _isWholeLineImage(text) ||
        _checklist.hasMatch(text) ||
        _list.hasMatch(text) ||
        _quote.hasMatch(text);
  }

  static bool _isWholeLineImage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final image = NoteImageSyntax.first(trimmed);
    return image != null && image.start == 0 && image.end == trimmed.length;
  }

  static int _consumeList(
    List<_LineSpan> lines,
    int firstLine, {
    required bool checklist,
  }) {
    var endLine = firstLine;
    while (endLine + 1 < lines.length) {
      final next = lines[endLine + 1].text;
      if (next.trim().isEmpty) {
        break;
      }
      final isExpectedItem =
          checklist ? _checklist.hasMatch(next) : _list.hasMatch(next);
      final isIndentedContinuation = RegExp(r'^(?: {2,}|\t)').hasMatch(next);
      if (!isExpectedItem && !isIndentedContinuation) {
        break;
      }
      endLine += 1;
    }
    return endLine;
  }

  static bool _isFenceEnd(String text, String marker, int minimumLength) {
    final trimmed = text.trimLeft();
    var count = 0;
    while (count < trimmed.length && trimmed[count] == marker) {
      count += 1;
    }
    return count >= minimumLength && trimmed.substring(count).trim().isEmpty;
  }

  static List<String> _plainTextLines(String raw) {
    return raw.split('\n').map((line) {
      var value = line.trimRight().trimLeft();
      value = value.replaceFirst(RegExp(r'^#{1,6}\s+'), '');
      value = value.replaceFirst(RegExp(r'^[-*+]\s+\[[ xX]\]\s+'), '');
      value = value.replaceFirst(RegExp(r'^(?:[-*+]\s+|\d+[.)]\s+)'), '');
      value = value.replaceFirst(RegExp(r'^>\s?'), '');
      return value;
    }).toList();
  }

  static String _singleLine(List<String> lines) {
    return lines.where((line) => line.isNotEmpty).join(' ').trim();
  }
}

class _LineSpan {
  const _LineSpan({
    required this.start,
    required this.contentEnd,
    required this.text,
  });

  final int start;
  final int contentEnd;
  final String text;

  static List<_LineSpan> parse(String source) {
    final result = <_LineSpan>[];
    var start = 0;
    while (start < source.length) {
      final newline = source.indexOf('\n', start);
      final contentEnd = newline == -1 ? source.length : newline;
      result.add(
        _LineSpan(
          start: start,
          contentEnd: contentEnd,
          text: source.substring(start, contentEnd),
        ),
      );
      if (newline == -1) {
        break;
      }
      start = newline + 1;
    }
    return result;
  }
}
