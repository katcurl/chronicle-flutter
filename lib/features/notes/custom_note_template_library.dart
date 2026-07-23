import 'note_templates.dart';

class CustomNoteTemplateLibrary {
  const CustomNoteTemplateLibrary._();

  static const String uncategorizedKey = '__uncategorized__';
  static const String uncategorizedLabel = 'Без категории';

  static String normalizedCategory(String category) => category.trim();

  static String categoryKey(NoteTemplate template) {
    final category = normalizedCategory(template.category);
    return category.isEmpty ? uncategorizedKey : category.toLowerCase();
  }

  static String categoryLabel(NoteTemplate template) {
    final category = normalizedCategory(template.category);
    return category.isEmpty ? uncategorizedLabel : category;
  }

  static List<String> categories(Iterable<NoteTemplate> templates) {
    final categoriesByKey = <String, String>{};
    var hasUncategorized = false;
    for (final template in templates) {
      final category = normalizedCategory(template.category);
      if (category.isEmpty) {
        hasUncategorized = true;
      } else {
        categoriesByKey.putIfAbsent(category.toLowerCase(), () => category);
      }
    }
    final sorted =
        categoriesByKey.values.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return <String>[if (hasUncategorized) uncategorizedKey, ...sorted];
  }

  static List<NoteTemplate> filter(
    Iterable<NoteTemplate> templates, {
    String query = '',
    String? category,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final normalizedCategory = category?.trim().toLowerCase();
    final result = templates
        .where((template) {
          if (normalizedCategory != null && normalizedCategory.isNotEmpty) {
            if (normalizedCategory == uncategorizedKey) {
              if (template.category.trim().isNotEmpty) return false;
            } else if (template.category.trim().toLowerCase() !=
                normalizedCategory) {
              return false;
            }
          }
          if (normalizedQuery.isEmpty) return true;
          final haystack =
              <String>[
                template.title,
                template.category,
                template.noteType,
                ...template.defaultTags,
                ...template.defaultProperties.keys,
                ...template.defaultProperties.values,
              ].join('\n').toLowerCase();
          return haystack.contains(normalizedQuery);
        })
        .toList(growable: false);
    result.sort((a, b) {
      final categoryCompare = categoryLabel(
        a,
      ).toLowerCase().compareTo(categoryLabel(b).toLowerCase());
      if (categoryCompare != 0) return categoryCompare;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return List<NoteTemplate>.unmodifiable(result);
  }

  static bool equivalent(NoteTemplate a, NoteTemplate b) {
    return a.title.trim().toLowerCase() == b.title.trim().toLowerCase() &&
        a.icon.trim() == b.icon.trim() &&
        a.category.trim().toLowerCase() == b.category.trim().toLowerCase() &&
        a.noteType.trim() == b.noteType.trim() &&
        a.content.trimRight() == b.content.trimRight() &&
        _sameList(a.defaultTags, b.defaultTags) &&
        _sameMap(a.defaultProperties, b.defaultProperties);
  }

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }

  static bool _sameMap(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}
