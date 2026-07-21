import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'note_templates.dart';

class CustomNoteTemplateStore {
  static const String preferencesKey = 'chronicle_custom_note_templates_v1';
  static const int maxTemplateCount = 100;
  static const int maxContentLength = 500000;

  Future<List<NoteTemplate>> load() async {
    final preferences = await SharedPreferences.getInstance();
    return decode(preferences.getString(preferencesKey));
  }

  Future<void> save(List<NoteTemplate> templates) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      preferencesKey,
      encode(templates),
    );
    if (!saved) {
      throw StateError('Не удалось сохранить пользовательские шаблоны.');
    }
  }

  static String encode(List<NoteTemplate> templates) {
    final safeTemplates = templates
        .where((template) => isValid(template))
        .take(maxTemplateCount)
        .map((template) => template.toJson())
        .toList(growable: false);
    return jsonEncode(safeTemplates);
  }

  static List<NoteTemplate> decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const <NoteTemplate>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <NoteTemplate>[];
      }
      final templates = <NoteTemplate>[];
      final seenIds = <String>{};
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }
        final normalized = <String, Object?>{
          for (final entry in item.entries)
            entry.key.toString(): entry.value,
        };
        final template = NoteTemplate.fromJson(normalized);
        if (!isValid(template) || !seenIds.add(template.id)) {
          continue;
        }
        templates.add(template);
        if (templates.length == maxTemplateCount) {
          break;
        }
      }
      return List<NoteTemplate>.unmodifiable(templates);
    } on Object {
      return const <NoteTemplate>[];
    }
  }

  static bool isValid(NoteTemplate template) {
    return template.isCustom &&
        template.id.startsWith('custom_') &&
        template.id.length <= 160 &&
        template.title.trim().isNotEmpty &&
        template.title.length <= 120 &&
        template.icon.trim().isNotEmpty &&
        template.icon.length <= 16 &&
        template.noteType.trim().isNotEmpty &&
        template.noteType.length <= 80 &&
        template.content.trim().isNotEmpty &&
        template.content.length <= maxContentLength &&
        template.defaultTags.length <= 40 &&
        template.defaultProperties.length <= 40;
  }
}
