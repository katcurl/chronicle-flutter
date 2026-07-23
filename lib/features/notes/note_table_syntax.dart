import 'scientific_reference_syntax.dart';

enum NoteTableAlignment { left, center, right }

class NoteTableModel {
  NoteTableModel({
    required this.id,
    required this.caption,
    required List<String> headers,
    required List<List<String>> rows,
    List<NoteTableAlignment>? alignments,
  })  : headers = List<String>.from(headers),
        rows = [for (final row in rows) List<String>.from(row)],
        alignments = List<NoteTableAlignment>.from(
          alignments ??
              List<NoteTableAlignment>.filled(
                headers.length,
                NoteTableAlignment.left,
              ),
        ) {
    _normalizeShape();
  }

  final String id;
  final String caption;
  final List<String> headers;
  final List<List<String>> rows;
  final List<NoteTableAlignment> alignments;

  int get columnCount => headers.length;
  int get rowCount => rows.length;

  NoteTableModel copyWith({
    String? id,
    String? caption,
    List<String>? headers,
    List<List<String>>? rows,
    List<NoteTableAlignment>? alignments,
  }) {
    return NoteTableModel(
      id: id ?? this.id,
      caption: caption ?? this.caption,
      headers: headers ?? this.headers,
      rows: rows ?? this.rows,
      alignments: alignments ?? this.alignments,
    );
  }

  String toMarkdown() {
    final marker = ScientificReferenceSyntax.tableMarker(
      id: id,
      caption: caption,
    );
    final headerLine = NoteTableSyntax.renderRow(headers);
    final separatorLine = NoteTableSyntax.renderSeparator(alignments);
    final body = [for (final row in rows) NoteTableSyntax.renderRow(row)];
    return [marker, headerLine, separatorLine, ...body].join('\n');
  }

  void _normalizeShape() {
    if (headers.length < NoteTableSyntax.minColumns) {
      while (headers.length < NoteTableSyntax.minColumns) {
        headers.add('Столбец ${headers.length + 1}');
      }
    }
    if (headers.length > NoteTableSyntax.maxColumns) {
      headers.removeRange(NoteTableSyntax.maxColumns, headers.length);
    }
    while (alignments.length < headers.length) {
      alignments.add(NoteTableAlignment.left);
    }
    if (alignments.length > headers.length) {
      alignments.removeRange(headers.length, alignments.length);
    }
    if (rows.isEmpty) {
      rows.add(List<String>.filled(headers.length, ''));
    }
    if (rows.length > NoteTableSyntax.maxRows) {
      rows.removeRange(NoteTableSyntax.maxRows, rows.length);
    }
    for (final row in rows) {
      while (row.length < headers.length) {
        row.add('');
      }
      if (row.length > headers.length) {
        row.removeRange(headers.length, row.length);
      }
    }
  }
}

class ClipboardTableData {
  const ClipboardTableData({required this.rows});

  final List<List<String>> rows;

  int get columnCount =>
      rows.fold<int>(0, (maximum, row) => row.length > maximum ? row.length : maximum);

  bool get isEmpty => rows.isEmpty || columnCount == 0;
}

class NoteTableSyntax {
  const NoteTableSyntax._();

  static const int minColumns = 2;
  static const int maxColumns = 8;
  static const int minRows = 1;
  static const int maxRows = 40;

  static NoteTableModel? parseReference(ScientificTableReference reference) {
    final lines = reference.raw.replaceAll('\r\n', '\n').split('\n');
    if (lines.length < 3) {
      return null;
    }
    final headers = parseRow(lines[1]);
    final separators = parseRow(lines[2]);
    if (headers.length < minColumns ||
        headers.length > maxColumns ||
        separators.length != headers.length) {
      return null;
    }
    final alignments = <NoteTableAlignment>[];
    for (final cell in separators) {
      final normalized = cell.trim();
      if (!RegExp(r'^:?-{3,}:?$').hasMatch(normalized)) {
        return null;
      }
      alignments.add(
        normalized.startsWith(':') && normalized.endsWith(':')
            ? NoteTableAlignment.center
            : normalized.endsWith(':')
                ? NoteTableAlignment.right
                : NoteTableAlignment.left,
      );
    }
    final rows = <List<String>>[];
    for (final line in lines.skip(3)) {
      if (line.trim().isEmpty) {
        continue;
      }
      final cells = parseRow(line);
      if (cells.length != headers.length || rows.length >= maxRows) {
        return null;
      }
      rows.add(cells);
    }
    return NoteTableModel(
      id: reference.id,
      caption: reference.caption,
      headers: headers,
      rows: rows,
      alignments: alignments,
    );
  }

  static List<String> parseRow(String line) {
    var source = line.trim();
    if (source.startsWith('|')) {
      source = source.substring(1);
    }
    if (_endsWithUnescapedPipe(source)) {
      source = source.substring(0, source.length - 1);
    }

    final cells = <String>[];
    final buffer = StringBuffer();
    for (var index = 0; index < source.length; index += 1) {
      final character = source[index];
      if (character == '\\' && index + 1 < source.length) {
        final next = source[index + 1];
        if (next == '|' || next == '\\') {
          buffer.write(next);
          index += 1;
          continue;
        }
      }
      if (character == '|') {
        cells.add(_decodeCell(buffer.toString()));
        buffer.clear();
        continue;
      }
      buffer.write(character);
    }
    cells.add(_decodeCell(buffer.toString()));
    return cells;
  }

  static String renderRow(List<String> cells) {
    return '| ${cells.map(_encodeCell).join(' | ')} |';
  }

  static String renderSeparator(List<NoteTableAlignment> alignments) {
    final cells = [
      for (final alignment in alignments)
        switch (alignment) {
          NoteTableAlignment.left => ':---',
          NoteTableAlignment.center => ':---:',
          NoteTableAlignment.right => '---:',
        },
    ];
    return '| ${cells.join(' | ')} |';
  }

  static ClipboardTableData parseClipboard(String text) {
    var normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    normalized = normalized.replaceFirst(RegExp(r'^(?:[ \t]*\n)+'), '');
    normalized = normalized.replaceFirst(RegExp(r'(?:\n[ \t]*)+$'), '');
    if (normalized.trim().isEmpty) {
      return const ClipboardTableData(rows: []);
    }
    final lines = normalized.split('\n');
    final delimiter = _detectDelimiter(lines);
    final rows = <List<String>>[];
    for (final line in lines) {
      if (line.isEmpty && rows.isNotEmpty) {
        rows.add(['']);
        continue;
      }
      rows.add(_parseDelimitedLine(line, delimiter));
    }
    final width = rows.fold<int>(0, (maximum, row) => row.length > maximum ? row.length : maximum);
    if (width == 0) {
      return const ClipboardTableData(rows: []);
    }
    final safeWidth = width.clamp(minColumns, maxColumns).toInt();
    final safeRows = rows.take(maxRows + 1).map((row) {
      final cells = row.take(safeWidth).toList();
      while (cells.length < safeWidth) {
        cells.add('');
      }
      return cells;
    }).toList();
    return ClipboardTableData(rows: safeRows);
  }

  static String _detectDelimiter(List<String> lines) {
    final sample = lines.take(8).join('\n');
    if (sample.contains('\t')) {
      return '\t';
    }
    final semicolons = ';'.allMatches(sample).length;
    final commas = ','.allMatches(sample).length;
    if (semicolons > 0 && semicolons >= commas) {
      return ';';
    }
    if (commas > 0) {
      return ',';
    }
    return '\t';
  }

  static List<String> _parseDelimitedLine(String line, String delimiter) {
    if (!line.contains(delimiter)) {
      return [line.trim()];
    }
    final cells = <String>[];
    final buffer = StringBuffer();
    var quoted = false;
    for (var index = 0; index < line.length; index += 1) {
      final character = line[index];
      if (character == '"') {
        if (quoted && index + 1 < line.length && line[index + 1] == '"') {
          buffer.write('"');
          index += 1;
        } else {
          quoted = !quoted;
        }
        continue;
      }
      if (!quoted && character == delimiter) {
        cells.add(buffer.toString().trim());
        buffer.clear();
        continue;
      }
      buffer.write(character);
    }
    cells.add(buffer.toString().trim());
    return cells;
  }

  static String _encodeCell(String value) {
    final normalized = value
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\\', r'\\')
        .replaceAll('|', r'\|')
        .replaceAll('\n', '<br>')
        .trim();
    return normalized.isEmpty ? ' ' : normalized;
  }

  static String _decodeCell(String value) {
    return value.trim().replaceAll('<br>', '\n');
  }

  static bool _endsWithUnescapedPipe(String value) {
    if (!value.endsWith('|')) {
      return false;
    }
    var backslashes = 0;
    for (var index = value.length - 2; index >= 0 && value[index] == '\\'; index -= 1) {
      backslashes += 1;
    }
    return backslashes.isEven;
  }
}
