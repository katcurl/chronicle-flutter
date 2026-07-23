import 'dart:math' as math;

import 'note_wiki_link_syntax.dart';

enum NoteLinkInsertStyle { inline, bulleted }

class NoteLinkTarget {
  const NoteLinkTarget({
    required this.id,
    required this.title,
    required this.projectTitle,
    required this.folderPath,
    required this.noteType,
    this.tags = const <String>[],
  });

  final String id;
  final String title;
  final String projectTitle;
  final String folderPath;
  final String noteType;
  final List<String> tags;

  String get searchableText => <String>[
    title,
    projectTitle,
    folderPath,
    noteType,
    ...tags,
  ].join(' ').toLowerCase();
}

class NoteLinkMention {
  const NoteLinkMention({
    required this.target,
    required this.start,
    required this.end,
    required this.matchedText,
    required this.snippet,
  });

  final NoteLinkTarget target;
  final int start;
  final int end;
  final String matchedText;
  final String snippet;
}

class NoteLinkTextEdit {
  const NoteLinkTextEdit({required this.text, required this.cursor});

  final String text;
  final int cursor;
}

class NoteLinkTools {
  const NoteLinkTools._();

  static final RegExp _fencedCode = RegExp(r'```[\s\S]*?```');
  static final RegExp _inlineCode = RegExp(r'`[^`\r\n]+`');
  static final RegExp _markdownLink = RegExp(r'!?\[[^\]\r\n]*\]\([^\)\r\n]+\)');
  static final RegExp _mentionBoundary = RegExp(
    r'[\s.,;:!?…()\[\]{}<>"«»„“”/\\|+=*&#@%^~`—–-]',
  );

  static String stableMarkdown(NoteLinkTarget target, {String? label}) {
    final id = target.id.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(target.id, 'target.id', 'ID заметки пуст.');
    }
    final prepared = _safeLabel(label ?? target.title);
    final visible = prepared.isEmpty ? 'Заметка' : prepared;
    return '[[${NoteWikiTarget.exactId(id)}|$visible]]';
  }

  static String compose(
    Iterable<NoteLinkTarget> targets, {
    required NoteLinkInsertStyle style,
  }) {
    final links = <String>[
      for (final target in targets) stableMarkdown(target),
    ];
    if (links.isEmpty) {
      return '';
    }
    return switch (style) {
      NoteLinkInsertStyle.inline => links.join(', '),
      NoteLinkInsertStyle.bulleted => links.map((link) => '- $link').join('\n'),
    };
  }

  static List<NoteLinkMention> findUnlinkedMentions(
    String markdown,
    Iterable<NoteLinkTarget> targets, {
    int limit = 80,
  }) {
    if (markdown.trim().isEmpty || limit <= 0) {
      return const <NoteLinkMention>[];
    }

    final titleCounts = <String, int>{};
    final candidates = <NoteLinkTarget>[];
    for (final target in targets) {
      final title = target.title.trim();
      if (target.id.trim().isEmpty || title.length < 3 || title.length > 160) {
        continue;
      }
      final normalized = title.toLowerCase();
      titleCounts[normalized] = (titleCounts[normalized] ?? 0) + 1;
      candidates.add(target);
    }
    candidates.removeWhere(
      (target) => titleCounts[target.title.trim().toLowerCase()] != 1,
    );
    candidates.sort((left, right) {
      final length = right.title.length.compareTo(left.title.length);
      if (length != 0) return length;
      return left.title.toLowerCase().compareTo(right.title.toLowerCase());
    });

    final blocked = <_TextRange>[
      for (final link in NoteWikiLinkSyntax.all(markdown))
        _TextRange(link.start, link.end),
      for (final match in _fencedCode.allMatches(markdown))
        _TextRange(match.start, match.end),
      for (final match in _inlineCode.allMatches(markdown))
        _TextRange(match.start, match.end),
      for (final match in _markdownLink.allMatches(markdown))
        _TextRange(match.start, match.end),
    ];
    final occupied = <_TextRange>[...blocked];
    final mentions = <NoteLinkMention>[];

    for (final target in candidates) {
      final expression = RegExp(
        RegExp.escape(target.title.trim()),
        caseSensitive: false,
      );
      for (final match in expression.allMatches(markdown)) {
        if (mentions.length >= limit) {
          break;
        }
        if (!_hasWordBoundaries(markdown, match.start, match.end) ||
            _overlapsAny(match.start, match.end, occupied)) {
          continue;
        }
        final matchedText = markdown.substring(match.start, match.end);
        mentions.add(
          NoteLinkMention(
            target: target,
            start: match.start,
            end: match.end,
            matchedText: matchedText,
            snippet: _snippet(markdown, match.start, match.end),
          ),
        );
        occupied.add(_TextRange(match.start, match.end));
      }
      if (mentions.length >= limit) {
        break;
      }
    }

    mentions.sort((left, right) => left.start.compareTo(right.start));
    return List<NoteLinkMention>.unmodifiable(mentions);
  }

  static NoteLinkTextEdit applyMentions(
    String markdown,
    Iterable<NoteLinkMention> mentions, {
    int? cursor,
  }) {
    var text = markdown;
    var nextCursor = (cursor ?? markdown.length)
        .clamp(0, markdown.length)
        .toInt();
    final sorted = mentions.toList()
      ..sort((left, right) => right.start.compareTo(left.start));
    final seen = <String>{};

    for (final mention in sorted) {
      final key = '${mention.start}:${mention.end}';
      if (!seen.add(key) ||
          mention.start < 0 ||
          mention.end > text.length ||
          mention.start >= mention.end) {
        continue;
      }
      final current = text.substring(mention.start, mention.end);
      if (current != mention.matchedText) {
        continue;
      }
      final replacement = stableMarkdown(
        mention.target,
        label: mention.matchedText,
      );
      text = text.replaceRange(mention.start, mention.end, replacement);
      final delta = replacement.length - (mention.end - mention.start);
      if (nextCursor > mention.end) {
        nextCursor += delta;
      } else if (nextCursor >= mention.start) {
        nextCursor = mention.start + replacement.length;
      }
    }

    return NoteLinkTextEdit(
      text: text,
      cursor: nextCursor.clamp(0, text.length).toInt(),
    );
  }

  static bool _hasWordBoundaries(String text, int start, int end) {
    final before = start == 0 ? null : text.substring(start - 1, start);
    final after = end >= text.length ? null : text.substring(end, end + 1);
    return (before == null || _mentionBoundary.hasMatch(before)) &&
        (after == null || _mentionBoundary.hasMatch(after));
  }

  static bool _overlapsAny(int start, int end, Iterable<_TextRange> ranges) {
    for (final range in ranges) {
      if (start < range.end && end > range.start) {
        return true;
      }
    }
    return false;
  }

  static String _safeLabel(String raw) {
    return raw
        .replaceAll(RegExp(r'[\r\n]+'), ' ')
        .replaceAll('|', '¦')
        .replaceAll(']', '›')
        .trim();
  }

  static String _snippet(String markdown, int start, int end) {
    final excerptStart = math.max(0, start - 58);
    final excerptEnd = math.min(markdown.length, end + 74);
    var excerpt = markdown
        .substring(excerptStart, excerptEnd)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (excerptStart > 0 && excerpt.isNotEmpty) {
      excerpt = '…$excerpt';
    }
    if (excerptEnd < markdown.length && excerpt.isNotEmpty) {
      excerpt = '$excerpt…';
    }
    return excerpt;
  }
}

class _TextRange {
  const _TextRange(this.start, this.end);

  final int start;
  final int end;
}
