import 'package:uuid/uuid.dart';

import '../../models/app_models.dart';

class BibTexParseResult {
  const BibTexParseResult({required this.sources, required this.errors});

  final List<CitationSource> sources;
  final List<String> errors;
}

class BibTexCodec {
  BibTexCodec._();

  static const Uuid _uuid = Uuid();

  static BibTexParseResult decode(String raw) {
    final records = _scanRecords(raw);
    final sources = <CitationSource>[];
    final errors = <String>[];

    for (final record in records) {
      try {
        final fields = _parseFields(record.body);
        final title = _cleanValue(fields['title'] ?? '');
        if (record.key.trim().isEmpty || title.isEmpty) {
          errors.add(
            'Пропущена запись ${record.key.isEmpty ? '(без ключа)' : record.key}: '
            'нужны citation key и title.',
          );
          continue;
        }
        final authors = _cleanValue(fields['author'] ?? '')
            .split(RegExp(r'\s+and\s+', caseSensitive: false))
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList();
        final yearText = _cleanValue(fields['year'] ?? '');
        final yearMatch = RegExp(r'\d{4}').firstMatch(yearText);
        final archivePrefix = _cleanValue(fields['archiveprefix'] ?? '');
        final eprint = _cleanValue(fields['eprint'] ?? '');
        final keywords = _cleanValue(fields['keywords'] ?? '')
            .split(RegExp(r'[,;]'))
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList();

        sources.add(
          CitationSource(
            id: _uuid.v4(),
            citationKey: record.key.trim(),
            title: title,
            sourceType: _normalizeType(record.type),
            authors: authors,
            year: yearMatch == null ? null : int.tryParse(yearMatch.group(0)!),
            containerTitle: _cleanValue(
              fields['journal'] ?? fields['booktitle'] ?? fields['publisher'] ?? '',
            ),
            doi: _cleanValue(fields['doi'] ?? ''),
            pmid: _cleanValue(fields['pmid'] ?? ''),
            arxivId:
                archivePrefix.toLowerCase() == 'arxiv'
                    ? eprint
                    : _cleanValue(fields['arxiv'] ?? ''),
            url: _cleanValue(fields['url'] ?? ''),
            pdfPath: _cleanValue(fields['file'] ?? ''),
            tags: keywords,
            note: _cleanValue(fields['note'] ?? fields['abstract'] ?? ''),
          ),
        );
      } on Object catch (error) {
        errors.add('Не удалось прочитать @${record.type}{${record.key}}: $error');
      }
    }

    if (records.isEmpty && raw.trim().isNotEmpty) {
      errors.add('BibTeX-записи не найдены. Ожидается формат @article{key, ...}.');
    }
    return BibTexParseResult(sources: sources, errors: errors);
  }

  static String encode(Iterable<CitationSource> sources) {
    final buffer = StringBuffer();
    var first = true;
    for (final source in sources) {
      if (!first) buffer.writeln();
      first = false;
      buffer.writeln('@${_bibType(source.sourceType)}{${source.citationKey},');
      _writeField(buffer, 'title', source.title);
      if (source.authors.isNotEmpty) {
        _writeField(buffer, 'author', source.authors.join(' and '));
      }
      if (source.year != null) {
        _writeField(buffer, 'year', source.year.toString());
      }
      _writeField(buffer, 'journal', source.containerTitle);
      _writeField(buffer, 'doi', source.normalizedDoi);
      _writeField(buffer, 'pmid', source.pmid);
      if (source.arxivId.trim().isNotEmpty) {
        _writeField(buffer, 'archivePrefix', 'arXiv');
        _writeField(buffer, 'eprint', source.arxivId);
      }
      _writeField(buffer, 'url', source.url);
      _writeField(buffer, 'file', source.pdfPath);
      if (source.tags.isNotEmpty) {
        _writeField(buffer, 'keywords', source.tags.join(', '));
      }
      _writeField(buffer, 'note', source.note);
      buffer.writeln('}');
    }
    return buffer.toString();
  }

  static List<_BibRecord> _scanRecords(String raw) {
    final records = <_BibRecord>[];
    var index = 0;
    while (index < raw.length) {
      final at = raw.indexOf('@', index);
      if (at < 0) break;
      var cursor = at + 1;
      while (cursor < raw.length && _isWhitespace(raw.codeUnitAt(cursor))) {
        cursor += 1;
      }
      final typeStart = cursor;
      while (cursor < raw.length && _isIdentifier(raw.codeUnitAt(cursor))) {
        cursor += 1;
      }
      final type = raw.substring(typeStart, cursor).trim();
      while (cursor < raw.length && _isWhitespace(raw.codeUnitAt(cursor))) {
        cursor += 1;
      }
      if (type.isEmpty || cursor >= raw.length ||
          (raw[cursor] != '{' && raw[cursor] != '(')) {
        index = at + 1;
        continue;
      }
      final opener = raw[cursor];
      final closer = opener == '{' ? '}' : ')';
      final contentStart = cursor + 1;
      var depth = 1;
      var quoted = false;
      cursor += 1;
      while (cursor < raw.length && depth > 0) {
        final char = raw[cursor];
        final escaped = cursor > 0 && raw[cursor - 1] == '\\';
        if (char == '"' && !escaped) quoted = !quoted;
        if (!quoted) {
          if (char == opener) depth += 1;
          if (char == closer) depth -= 1;
        }
        cursor += 1;
      }
      if (depth != 0) break;
      final content = raw.substring(contentStart, cursor - 1);
      final comma = _topLevelComma(content);
      if (comma >= 0) {
        records.add(
          _BibRecord(
            type: type,
            key: content.substring(0, comma).trim(),
            body: content.substring(comma + 1),
          ),
        );
      }
      index = cursor;
    }
    return records;
  }

  static int _topLevelComma(String value) {
    var braces = 0;
    var quoted = false;
    for (var index = 0; index < value.length; index += 1) {
      final char = value[index];
      final escaped = index > 0 && value[index - 1] == '\\';
      if (char == '"' && !escaped) quoted = !quoted;
      if (quoted) continue;
      if (char == '{') braces += 1;
      if (char == '}') braces -= 1;
      if (char == ',' && braces == 0) return index;
    }
    return -1;
  }

  static Map<String, String> _parseFields(String body) {
    final fields = <String, String>{};
    var index = 0;
    while (index < body.length) {
      while (index < body.length &&
          (_isWhitespace(body.codeUnitAt(index)) || body[index] == ',')) {
        index += 1;
      }
      final nameStart = index;
      while (index < body.length && _isIdentifier(body.codeUnitAt(index))) {
        index += 1;
      }
      final name = body.substring(nameStart, index).trim().toLowerCase();
      while (index < body.length && _isWhitespace(body.codeUnitAt(index))) {
        index += 1;
      }
      if (name.isEmpty || index >= body.length || body[index] != '=') {
        while (index < body.length && body[index] != ',') index += 1;
        continue;
      }
      index += 1;
      while (index < body.length && _isWhitespace(body.codeUnitAt(index))) {
        index += 1;
      }
      if (index >= body.length) break;

      final start = index;
      if (body[index] == '{') {
        var depth = 1;
        index += 1;
        while (index < body.length && depth > 0) {
          if (body[index] == '{') depth += 1;
          if (body[index] == '}') depth -= 1;
          index += 1;
        }
      } else if (body[index] == '"') {
        index += 1;
        while (index < body.length) {
          final escaped = index > 0 && body[index - 1] == '\\';
          if (body[index] == '"' && !escaped) {
            index += 1;
            break;
          }
          index += 1;
        }
      } else {
        while (index < body.length && body[index] != ',') index += 1;
      }
      fields[name] = body.substring(start, index).trim();
      while (index < body.length && body[index] != ',') index += 1;
      if (index < body.length) index += 1;
    }
    return fields;
  }

  static String _cleanValue(String value) {
    var result = value.trim();
    while (result.length >= 2 &&
        ((result.startsWith('{') && result.endsWith('}')) ||
            (result.startsWith('"') && result.endsWith('"')))) {
      result = result.substring(1, result.length - 1).trim();
    }
    return result
        .replaceAll(RegExp(r'[{}]'), '')
        .replaceAll(r'\&', '&')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _normalizeType(String type) {
    return switch (type.toLowerCase()) {
      'book' || 'inbook' => 'book',
      'inproceedings' || 'conference' => 'conference',
      'phdthesis' || 'mastersthesis' => 'thesis',
      'misc' || 'online' => 'web',
      _ => 'article',
    };
  }

  static String _bibType(String type) {
    return switch (type) {
      'book' => 'book',
      'conference' => 'inproceedings',
      'thesis' => 'phdthesis',
      'web' => 'misc',
      _ => 'article',
    };
  }

  static void _writeField(StringBuffer buffer, String name, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final escaped = trimmed.replaceAll('{', r'\{').replaceAll('}', r'\}');
    buffer.writeln('  $name = {$escaped},');
  }

  static bool _isWhitespace(int code) =>
      code == 32 || code == 9 || code == 10 || code == 13;

  static bool _isIdentifier(int code) =>
      (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) ||
      (code >= 48 && code <= 57) ||
      code == 95 ||
      code == 45;
}

class _BibRecord {
  const _BibRecord({required this.type, required this.key, required this.body});

  final String type;
  final String key;
  final String body;
}
