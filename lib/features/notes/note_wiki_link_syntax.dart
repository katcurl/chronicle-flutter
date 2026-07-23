import 'dart:math' as math;

class NoteWikiTarget {
  const NoteWikiTarget({
    required this.noteTitle,
    this.projectTitle,
    this.noteId,
  });

  final String noteTitle;
  final String? projectTitle;
  final String? noteId;

  bool get isQualified => projectTitle != null;
  bool get isExactId => noteId != null;

  static NoteWikiTarget parse(String raw) {
    final withAnchor = raw.trim();
    final anchorIndex = withAnchor.indexOf('#');
    final normalized =
        anchorIndex < 0
            ? withAnchor
            : withAnchor.substring(0, anchorIndex).trim();
    if (normalized.toLowerCase().startsWith('id:')) {
      final id = normalized.substring(3).trim();
      if (id.isNotEmpty) {
        return NoteWikiTarget(noteTitle: '', noteId: id);
      }
    }

    final separator = normalized.indexOf('::');
    if (separator > 0 && separator < normalized.length - 2) {
      final project = normalized.substring(0, separator).trim();
      final title = normalized.substring(separator + 2).trim();
      if (project.isNotEmpty && title.isNotEmpty) {
        return NoteWikiTarget(projectTitle: project, noteTitle: title);
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

  static String exactId(String noteId) => 'id:${noteId.trim()}';
}

class NoteWikiLinkReference {
  const NoteWikiLinkReference({
    required this.target,
    required this.start,
    required this.end,
    this.anchor,
    this.label,
  });

  final String target;
  final String? anchor;
  final String? label;
  final int start;
  final int end;

  String get visibleLabel {
    final explicit = label?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    final parsed = NoteWikiTarget.parse(target);
    if (parsed.noteTitle.isNotEmpty) {
      return parsed.noteTitle;
    }
    return target;
  }

  String toMarkdown({required String target, String? label}) {
    final cleanTarget = target.trim();
    final cleanAnchor = anchor?.trim() ?? '';
    final cleanLabel = label?.trim();
    if (cleanLabel == null || cleanLabel.isEmpty) {
      return '[[$cleanTarget$cleanAnchor]]';
    }
    return '[[$cleanTarget$cleanAnchor|$cleanLabel]]';
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
    r'\[\[([^\]|#]+)(#[^\]|]+)?(?:\|([^\]]+))?\]\]',
  );

  static Iterable<NoteWikiLinkReference> all(String markdown) sync* {
    for (final match in _pattern.allMatches(markdown)) {
      final target = match.group(1)?.trim() ?? '';
      if (target.isEmpty) {
        continue;
      }
      yield NoteWikiLinkReference(
        target: target,
        anchor: match.group(2)?.trim(),
        label: match.group(3)?.trim(),
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
      final anchor = match.group(2)?.trim() ?? '';
      final label = match.group(3)?.trim();
      final parsed = NoteWikiTarget.parse(target);
      final shown =
          label == null || label.isEmpty
              ? parsed.noteTitle.isEmpty
                  ? target
                  : parsed.noteTitle
              : label;
      final destination = '$target$anchor';
      return '[$shown](chronicle://note/${Uri.encodeComponent(destination)})';
    });
  }

  static NoteWikiAutocompleteQuery? autocompleteAt(String text, int cursor) {
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
    String target, {
    String? label,
  }) {
    final cleanTarget = target.trim();
    final cleanLabel = label?.trim();
    final replacement =
        cleanLabel == null || cleanLabel.isEmpty
            ? '$cleanTarget]]'
            : '$cleanTarget|$cleanLabel]]';
    return NoteWikiCompletionResult(
      text: text.replaceRange(query.start, query.end, replacement),
      cursor: query.start + replacement.length,
    );
  }

  static String replaceTarget(
    String markdown,
    NoteWikiLinkReference reference, {
    required String target,
    String? label,
  }) {
    if (reference.start < 0 ||
        reference.end > markdown.length ||
        reference.start >= reference.end) {
      return markdown;
    }
    return markdown.replaceRange(
      reference.start,
      reference.end,
      reference.toMarkdown(target: target, label: label),
    );
  }

  static String snippetForReference(
    String markdown,
    NoteWikiLinkReference reference, {
    int radius = 72,
  }) {
    final start = math.max(0, reference.start - radius);
    final end = math.min(markdown.length, reference.end + radius);
    var excerpt = markdown.substring(start, end);
    for (final link in all(excerpt).toList().reversed) {
      excerpt = excerpt.replaceRange(link.start, link.end, link.visibleLabel);
    }
    excerpt =
        excerpt
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
    return snippetForReference(markdown, reference, radius: radius);
  }

  static String _normalize(String value) => value.trim().toLowerCase();
}
