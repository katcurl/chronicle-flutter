import '../../models/app_models.dart';
import 'note_columns_syntax.dart';
import 'note_image_syntax.dart';
import 'note_wiki_link_syntax.dart';
import 'scientific_reference_syntax.dart';

class ParsedNoteDocument {
  const ParsedNoteDocument({required this.content, required this.frontMatter});

  final String content;
  final Map<String, String> frontMatter;
}

class NoteDocument {
  const NoteDocument._();

  static ParsedNoteDocument parse(String body) {
    final normalized = body.replaceAll('\r\n', '\n');
    if (!normalized.startsWith('---\n')) {
      return ParsedNoteDocument(content: normalized, frontMatter: const {});
    }

    final closing = normalized.indexOf('\n---\n', 4);
    if (closing < 0) {
      return ParsedNoteDocument(content: normalized, frontMatter: const {});
    }

    final header = normalized.substring(4, closing);
    final content = normalized
        .substring(closing + 5)
        .replaceFirst(RegExp(r'^\n'), '');
    final properties = <String, String>{};

    for (final rawLine in header.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final separator = line.indexOf(':');
      if (separator <= 0) continue;
      final key = line.substring(0, separator).trim();
      final value = line.substring(separator + 1).trim();
      if (key.isNotEmpty) properties[key] = _unquote(value);
    }

    return ParsedNoteDocument(content: content, frontMatter: properties);
  }

  static String replaceContent(String body, String content) {
    final normalized = body.replaceAll('\r\n', '\n');
    if (!normalized.startsWith('---\n')) {
      return content;
    }
    final closing = normalized.indexOf('\n---\n', 4);
    if (closing < 0) {
      return content;
    }
    final frontMatter = normalized.substring(0, closing + 5);
    return '$frontMatter\n$content';
  }

  static String serialize(Note note, String content) {
    final properties = <String, String>{
      ...note.properties,
      'type': note.noteType,
      'status': note.status,
      if (note.folderPath.trim().isNotEmpty) 'folder': note.folderPath.trim(),
      if (note.tags.isNotEmpty) 'tags': '[${note.tags.join(', ')}]',
    };

    final lines = properties.entries
        .where((entry) => entry.key.trim().isNotEmpty)
        .map((entry) => '${entry.key.trim()}: ${_quoteIfNeeded(entry.value)}')
        .join('\n');
    final trimmedContent = content.trimLeft();
    return '---\n$lines\n---\n\n$trimmedContent';
  }

  static Set<String> extractWikiTargets(String markdown) {
    return NoteWikiLinkSyntax.targets(markdown);
  }

  static String convertWikiLinksToMarkdown(String markdown) {
    return NoteWikiLinkSyntax.convertToMarkdown(markdown);
  }

  static List<String> parseTags(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    final cleaned = raw.trim().replaceAll(RegExp(r'^\[|\]$'), '');
    return cleaned
        .split(',')
        .map((tag) => tag.trim().replaceFirst(RegExp(r'^#'), ''))
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
  }

  static int wordCount(String markdown) {
    final withoutSyntax = _replaceImagesWithReadableText(
          ScientificReferenceSyntax.stripMarkersForWordCount(
            NoteColumnsSyntax.stripMarkers(markdown),
          ),
        )
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
        .replaceAll(RegExp(r'\$\$[\s\S]*?\$\$'), ' ')
        .replaceAll(RegExp(r'\\\[[\s\S]*?\\\]'), ' ')
        .replaceAll(RegExp(r'[#>*_`~\[\]()!-]'), ' ');
    return RegExp(r'[A-Za-zА-Яа-яЁё0-9]+').allMatches(withoutSyntax).length;
  }

  static int readingMinutes(String markdown) {
    final words = wordCount(markdown);
    if (words == 0) return 0;
    return (words / 180).ceil();
  }

  static String _replaceImagesWithReadableText(String markdown) {
    var result = markdown;
    final images = NoteImageSyntax.all(markdown).toList().reversed;
    for (final image in images) {
      final readable = [
        image.alt,
        image.presentation.caption,
      ].where((value) => value.trim().isNotEmpty).join(' ');
      result = result.replaceRange(image.start, image.end, ' $readable ');
    }
    return result;
  }

  static String _unquote(String value) {
    if (value.length >= 2) {
      final first = value[0];
      final last = value[value.length - 1];
      if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
        return value.substring(1, value.length - 1);
      }
    }
    return value;
  }

  static String _quoteIfNeeded(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) return trimmed;
    if (!trimmed.contains(':') && !trimmed.contains('#')) return trimmed;
    return '"${trimmed.replaceAll('"', '\\"')}"';
  }
}
