import 'dart:math' as math;

class NoteWikiTarget {
  const NoteWikiTarget({
    required this.noteTitle,
    this.projectTitle,
  });

  final String noteTitle;
  final String? projectTitle;

  bool get isQualified => projectTitle != null;

  static NoteWikiTarget parse(String raw) {
    final normalized = raw.trim();
    final separator = normalized.indexOf('::');
    if (separator > 0 && separator < normalized.length - 2) {
      final project = normalized.substring(0, separator).trim();
      final title = normalized.substring(separator + 2).trim();
      if (project.isNotEmpty && title.isNotEmpty) {
        return NoteWikiTarget(
          projectTitle: project,
          noteTitle: title,
        );
      }
    }
    return NoteWikiTarget(noteTitle: normalized);
  }

  static String qualified({
    required String projectTitle,
    required String noteTitle,
  }) {
    return '${projectTitle.trim()} :: ${noteTitle.trim()}';
  }
}

class NoteWikiLinkReference {
  const NoteWikiLinkReference({
    required this.target,
    required this.start,
    required this.end,
    this.label,
  });

  final String target;
  final String? label;
  final int start;
  final int end;

  String get visibleLabel {
    final explicit = label?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    return NoteWikiTarget.parse(target).noteTitle;
  }
}

class NoteWikiAutocompleteQuery {
  const NoteWikiAutocompleteQuery({
    required this.start,
    required this.end,
    required this.query,
  });

  final int start;
  final int end;
  final String query;
}

class NoteWikiCompletionResult {
  const NoteWikiCompletionResult({required this.text, required this.cursor});

  final String text;
  final int cursor;
}

class NoteWikiLinkSyntax {
  const NoteWikiLinkSyntax._();

  static final RegExp _pattern = RegExp(
    r'\[\[([^\]|#]+)(?:#[^\]|]+)?(?:\|([^\]]+))?\]\]',
  );

  static Iterable<NoteWikiLinkReference> all(String markdown) sync* {
    for (final match in _pattern.allMatches(markdown)) {
      final target = match.group(1)?.trim() ?? '';
      if (target.isEmpty) {
        continue;
      }
      yield NoteWikiLinkReference(
        target: target,
        label: match.group(2)?.trim(),
        start: match.start,
        end: match.end,
      );
    }
  }

  static Set<String> targets(String markdown) {
    return all(markdown).map((link) => link.target).toSet();
  }

  static String convertToMarkdown(String markdown) {
    return markdown.replaceAllMapped(_pattern, (match) {
      final target = match.group(1)?.trim() ?? '';
      final label = match.group(2)?.trim();
      final shown =
          label == null || label.isEmpty
              ? NoteWikiTarget.parse(target).noteTitle
              : label;
      return '[$shown](chronicle://note/${Uri.encodeComponent(target)})';
    });
  }

  static NoteWikiAutocompleteQuery? autocompleteAt(
    String text,
    int cursor,
  ) {
    if (cursor < 2 || cursor > text.length) {
      return null;
    }
    final searchStart = math.max(0, cursor - 122);
    final window = text.substring(searchStart, cursor);
    final relativeOpen = window.lastIndexOf('[[');
    if (relativeOpen < 0) {
      return null;
    }
    final open = searchStart + relativeOpen;
    final queryStart = open + 2;
    final rawQuery = text.substring(queryStart, cursor);
    if (rawQuery.length > 120 ||
        rawQuery.contains('\n') ||
        rawQuery.contains('\r') ||
        rawQuery.contains(']') ||
        rawQuery.contains('|') ||
        rawQuery.contains('#')) {
      return null;
    }
    return NoteWikiAutocompleteQuery(
      start: queryStart,
      end: cursor,
      query: rawQuery.trim(),
    );
  }

  static NoteWikiCompletionResult complete(
    String text,
    NoteWikiAutocompleteQuery query,
    String target,
  ) {
    final replacement = '${target.trim()}]]';
    return NoteWikiCompletionResult(
      text: text.replaceRange(query.start, query.end, replacement),
      cursor: query.start + replacement.length,
    );
  }

  static String snippetForTarget(
    String markdown,
    String target, {
    int radius = 72,
  }) {
    final normalizedTarget = _normalize(target);
    NoteWikiLinkReference? reference;
    for (final link in all(markdown)) {
      if (_normalize(link.target) == normalizedTarget) {
        reference = link;
        break;
      }
    }
    if (reference == null) {
      return '';
    }

    final start = math.max(0, reference.start - radius);
    final end = math.min(markdown.length, reference.end + radius);
    var excerpt = markdown.substring(start, end);
    for (final link in all(excerpt).toList().reversed) {
      excerpt = excerpt.replaceRange(link.start, link.end, link.visibleLabel);
    }
    excerpt = excerpt
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
        .replaceAll(RegExp(r'[#>*_`~]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (start > 0 && excerpt.isNotEmpty) {
      excerpt = '…$excerpt';
    }
    if (end < markdown.length && excerpt.isNotEmpty) {
      excerpt = '$excerpt…';
    }
    return excerpt;
  }

  static String _normalize(String value) => value.trim().toLowerCase();
}
