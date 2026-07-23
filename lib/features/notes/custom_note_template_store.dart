import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'note_templates.dart';

class CustomNoteTemplateStore {
  static const String preferencesKey = 'chronicle_custom_note_templates_v1';
  static const String exportFormat = 'chronicle.custom-note-templates';
  static const int exportVersion = 1;
  static const int maxTemplateCount = 100;
  static const int maxContentLength = 500000;
  static const int maxCategoryLength = 80;

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
    return jsonEncode(_safeTemplateJson(templates));
  }

  static List<NoteTemplate> decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const <NoteTemplate>[];
    }
    try {
      final decoded = jsonDecode(raw);
      return _decodeTemplateList(decoded);
    } on Object {
      return const <NoteTemplate>[];
    }
  }

  static String encodeExportBundle(List<NoteTemplate> templates) {
    final bundle = <String, Object?>{
      'format': exportFormat,
      'version': exportVersion,
      'templates': _safeTemplateJson(templates),
    };
    return const JsonEncoder.withIndent('  ').convert(bundle);
  }

  static List<NoteTemplate> decodeImportBundle(String raw) {
    if (raw.trim().isEmpty) {
      throw const FormatException('Файл шаблонов пуст.');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('Файл не является корректным JSON.');
    }

    if (decoded is List) {
      final legacyTemplates = _decodeTemplateList(decoded);
      if (legacyTemplates.isEmpty && decoded.isNotEmpty) {
        throw const FormatException(
          'В файле нет корректных пользовательских шаблонов.',
        );
      }
      return legacyTemplates;
    }
    if (decoded is! Map) {
      throw const FormatException('Неизвестный формат файла шаблонов.');
    }

    final normalized = <String, Object?>{
      for (final entry in decoded.entries)
        entry.key.toString(): entry.value,
    };
    if (normalized['format'] != exportFormat) {
      throw const FormatException('Файл создан не библиотекой шаблонов Chronicle.');
    }
    if (normalized['version'] != exportVersion) {
      throw const FormatException('Версия файла шаблонов не поддерживается.');
    }
    final rawTemplates = normalized['templates'];
    if (rawTemplates is! List) {
      throw const FormatException('В файле отсутствует список шаблонов.');
    }
    final templates = _decodeTemplateList(rawTemplates);
    if (templates.isEmpty && rawTemplates.isNotEmpty) {
      throw const FormatException(
        'В файле нет корректных пользовательских шаблонов.',
      );
    }
    return templates;
  }

  static List<Map<String, Object?>> _safeTemplateJson(
    Iterable<NoteTemplate> templates,
  ) {
    return templates
        .where(isValid)
        .take(maxTemplateCount)
        .map((template) => template.toJson())
        .toList(growable: false);
  }

  static List<NoteTemplate> _decodeTemplateList(Object? decoded) {
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
  }

  static bool isValid(NoteTemplate template) {
    return template.isCustom &&
        template.id.startsWith('custom_') &&
        template.id.length <= 160 &&
        template.title.trim().isNotEmpty &&
        template.title.length <= 120 &&
        template.icon.trim().isNotEmpty &&
        template.icon.length <= 16 &&
        template.category.length <= maxCategoryLength &&
        template.noteType.trim().isNotEmpty &&
        template.noteType.length <= 80 &&
        template.content.trim().isNotEmpty &&
        template.content.length <= maxContentLength &&
        template.defaultTags.length <= 40 &&
        template.defaultProperties.length <= 40;
  }
}
