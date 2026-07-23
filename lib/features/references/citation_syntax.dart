import '../../models/app_models.dart';

class CitationSyntax {
  CitationSyntax._();

  static final RegExp _groupPattern = RegExp(
    r'\[((?:\s*@[A-Za-z0-9_.:-]+\s*;?)+)\]',
  );
  static final RegExp _keyPattern = RegExp(r'@([A-Za-z0-9_.:-]+)');
  static final RegExp _fencePattern = RegExp(r'^\s*(```|~~~)');
  static const String bibliographyMarker = ':::bibliography';

  static List<String> extractKeys(String markdown) {
    if (!markdown.contains('[@')) return const <String>[];
    final keys = <String>[];
    final seen = <String>{};
    var fenced = false;
    for (final line in markdown.split('\n')) {
      if (_fencePattern.hasMatch(line)) {
        fenced = !fenced;
        continue;
      }
      if (fenced) continue;
      for (final match in _groupPattern.allMatches(line)) {
        for (final keyMatch in _keyPattern.allMatches(match.group(1)!)) {
          final key = keyMatch.group(1)!;
          final normalized = key.toLowerCase();
          if (seen.add(normalized)) keys.add(key);
        }
      }
    }
    return keys;
  }

  static int countKey(String markdown, String citationKey) {
    if (!markdown.contains('[@')) return 0;
    final normalized = citationKey.trim().toLowerCase();
    if (normalized.isEmpty) return 0;
    var count = 0;
    var fenced = false;
    for (final line in markdown.split('\n')) {
      if (_fencePattern.hasMatch(line)) {
        fenced = !fenced;
        continue;
      }
      if (fenced) continue;
      for (final match in _groupPattern.allMatches(line)) {
        for (final keyMatch in _keyPattern.allMatches(match.group(1)!)) {
          if (keyMatch.group(1)!.toLowerCase() == normalized) count += 1;
        }
      }
    }
    return count;
  }

  static String markdownFor(Iterable<CitationSource> sources) {
    final keys = <String>[];
    final seen = <String>{};
    for (final source in sources) {
      final key = source.citationKey.trim();
      if (key.isEmpty || !seen.add(key.toLowerCase())) continue;
      keys.add('@$key');
    }
    return keys.isEmpty ? '' : '[${keys.join('; ')}]';
  }

  static List<CitationSource> bibliographyFor(
    String markdown,
    Iterable<CitationSource> sources,
  ) {
    final byKey = <String, CitationSource>{
      for (final source in sources)
        source.normalizedCitationKey: source,
    };
    final result = <CitationSource>[];
    for (final key in extractKeys(markdown)) {
      final source = byKey[key.toLowerCase()];
      if (source != null) result.add(source);
    }
    return result;
  }

  static String renderMarkdownChunk(
    String markdown,
    Iterable<CitationSource> sources, {
    Iterable<CitationSource>? bibliography,
  }) {
    if (!markdown.contains('[@') &&
        !markdown.contains(bibliographyMarker)) {
      return markdown;
    }
    final byKey = <String, CitationSource>{
      for (final source in sources)
        source.normalizedCitationKey: source,
    };
    final bibliographyItems =
        bibliography?.toList(growable: false) ?? const <CitationSource>[];
    final output = <String>[];
    var fenced = false;

    for (final line in markdown.split('\n')) {
      if (_fencePattern.hasMatch(line)) {
        fenced = !fenced;
        output.add(line);
        continue;
      }
      if (!fenced && line.trim() == bibliographyMarker) {
        output.add(_bibliographyMarkdown(bibliographyItems));
        continue;
      }
      if (fenced) {
        output.add(line);
        continue;
      }
      output.add(
        line.replaceAllMapped(_groupPattern, (match) {
          final keys = [
            for (final keyMatch in _keyPattern.allMatches(match.group(1)!))
              keyMatch.group(1)!,
          ];
          final labels = <String>[];
          for (final key in keys) {
            final source = byKey[key.toLowerCase()];
            labels.add(source == null ? '@$key' : _inTextLabel(source));
          }
          return labels.every((label) => label.startsWith('@'))
              ? match.group(0)!
              : '(${labels.join('; ')})';
        }),
      );
    }
    return output.join('\n');
  }

  static String _inTextLabel(CitationSource source) {
    final author = _shortAuthor(source.authors);
    final year = source.year?.toString() ?? 'б. г.';
    if (author.isEmpty) return '${source.citationKey}, $year';
    return '$author, $year';
  }

  static String _shortAuthor(List<String> authors) {
    if (authors.isEmpty) return '';
    final surnames = authors.map(_surname).where((value) => value.isNotEmpty).toList();
    if (surnames.isEmpty) return '';
    if (surnames.length == 1) return surnames.first;
    if (surnames.length == 2) return '${surnames[0]} и ${surnames[1]}';
    return '${surnames.first} и др.';
  }

  static String _surname(String author) {
    final value = author.trim();
    if (value.isEmpty) return '';
    if (value.contains(',')) return value.split(',').first.trim();
    final words = value.split(RegExp(r'\s+'));
    return words.last;
  }

  static String _bibliographyMarkdown(List<CitationSource> sources) {
    if (sources.isEmpty) {
      return '> В этой заметке пока нет распознанных цитат.';
    }
    final lines = <String>['## Литература', ''];
    for (var index = 0; index < sources.length; index += 1) {
      final source = sources[index];
      final parts = <String>[];
      if (source.authors.isNotEmpty) {
        parts.add(_escapeMarkdown(source.authors.join(', ')));
      }
      parts.add('**${_escapeMarkdown(source.title)}**');
      if (source.containerTitle.trim().isNotEmpty) {
        parts.add('*${_escapeMarkdown(source.containerTitle.trim())}*');
      }
      if (source.year != null) parts.add(source.year.toString());
      if (source.doi.trim().isNotEmpty) {
        final doi = source.normalizedDoi;
        parts.add('[DOI: $doi](https://doi.org/$doi)');
      } else if (source.url.trim().isNotEmpty) {
        parts.add('[ссылка](${source.url.trim()})');
      } else if (source.arxivId.trim().isNotEmpty) {
        parts.add('arXiv: ${source.arxivId.trim()}');
      } else if (source.pmid.trim().isNotEmpty) {
        parts.add('PMID: ${source.pmid.trim()}');
      }
      lines.add('${index + 1}. ${parts.join('. ')}.');
    }
    return lines.join('\n');
  }

  static String _escapeMarkdown(String value) =>
      value
          .replaceAll('\\', r'\\')
          .replaceAll('*', r'\*')
          .replaceAll('_', r'\_')
          .replaceAll('[', r'\[')
          .replaceAll(']', r'\]');
}
