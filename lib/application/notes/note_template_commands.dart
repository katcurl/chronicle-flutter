import 'package:uuid/uuid.dart';

import '../../features/notes/custom_note_template_library.dart';
import '../../features/notes/custom_note_template_store.dart';
import '../../features/notes/note_templates.dart';

final class NoteTemplateCommands {
  NoteTemplateCommands({
    CustomNoteTemplateStore? store,
    required void Function() notifyListeners,
    Uuid uuid = const Uuid(),
  }) : _store = store,
       _notifyListeners = notifyListeners,
       _uuid = uuid;

  final CustomNoteTemplateStore? _store;
  final void Function() _notifyListeners;
  final Uuid _uuid;

  List<NoteTemplate> customTemplates = const <NoteTemplate>[];

  NoteTemplate get blankTemplate =>
      noteTemplates.firstWhere((template) => template.id == 'blank');

  List<NoteTemplate> get availableTemplates => List<NoteTemplate>.unmodifiable(
    <NoteTemplate>[blankTemplate, ...customTemplates],
  );

  List<NoteTemplate> get applicableTemplates =>
      List<NoteTemplate>.unmodifiable(customTemplates);

  Future<void> load() async {
    final store = _store;
    customTemplates =
        store == null ? const <NoteTemplate>[] : await store.load();
  }

  Future<NoteTemplate> create({
    required String title,
    required String icon,
    required String noteType,
    required String content,
    String category = '',
    List<String> defaultTags = const <String>[],
    Map<String, String> defaultProperties = const <String, String>{},
  }) async {
    if (customTemplates.length >= CustomNoteTemplateStore.maxTemplateCount) {
      throw StateError('Достигнут лимит пользовательских шаблонов.');
    }
    final template = _normalize(
      id: 'custom_${_uuid.v4()}',
      title: title,
      icon: icon,
      noteType: noteType,
      content: content,
      category: category,
      defaultTags: defaultTags,
      defaultProperties: defaultProperties,
    );
    await _replace(<NoteTemplate>[...customTemplates, template]);
    return template;
  }

  Future<NoteTemplate> update({
    required String id,
    required String title,
    required String icon,
    required String noteType,
    required String content,
    String category = '',
    List<String> defaultTags = const <String>[],
    Map<String, String> defaultProperties = const <String, String>{},
  }) async {
    final index = customTemplates.indexWhere((template) => template.id == id);
    if (index < 0) {
      throw StateError('Пользовательский шаблон не найден.');
    }
    final template = _normalize(
      id: id,
      title: title,
      icon: icon,
      noteType: noteType,
      content: content,
      category: category,
      defaultTags: defaultTags,
      defaultProperties: defaultProperties,
    );
    final next = List<NoteTemplate>.from(customTemplates);
    next[index] = template;
    await _replace(next);
    return template;
  }

  Future<NoteTemplate> duplicate(String id) async {
    final index = customTemplates.indexWhere((template) => template.id == id);
    if (index < 0) {
      throw StateError('Пользовательский шаблон не найден.');
    }
    final source = customTemplates[index];
    return create(
      title: _copyTitle(source.title),
      icon: source.icon,
      noteType: source.noteType,
      content: source.content,
      category: source.category,
      defaultTags: source.defaultTags,
      defaultProperties: source.defaultProperties,
    );
  }

  Future<List<NoteTemplate>> importTemplates(
    List<NoteTemplate> imported,
  ) async {
    if (imported.isEmpty) {
      return const <NoteTemplate>[];
    }
    final remaining =
        CustomNoteTemplateStore.maxTemplateCount - customTemplates.length;
    if (remaining <= 0) {
      throw StateError('Достигнут лимит пользовательских шаблонов.');
    }

    final next = List<NoteTemplate>.from(customTemplates);
    final added = <NoteTemplate>[];
    for (final source in imported) {
      if (added.length >= remaining) {
        break;
      }
      if (next.any(
        (template) => CustomNoteTemplateLibrary.equivalent(template, source),
      )) {
        continue;
      }
      final importedTemplate = _normalize(
        id: 'custom_${_uuid.v4()}',
        title: source.title,
        icon: source.icon,
        noteType: source.noteType,
        content: source.content,
        category: source.category,
        defaultTags: source.defaultTags,
        defaultProperties: source.defaultProperties,
      );
      next.add(importedTemplate);
      added.add(importedTemplate);
    }
    if (added.isNotEmpty) {
      await _replace(next);
    }
    return List<NoteTemplate>.unmodifiable(added);
  }

  Future<void> delete(String id) async {
    final next = customTemplates
        .where((template) => template.id != id)
        .toList(growable: false);
    if (next.length == customTemplates.length) {
      return;
    }
    await _replace(next);
  }

  String _copyTitle(String title) {
    final normalized = title.trim();
    var index = 1;
    while (true) {
      final prefix = index == 1 ? 'Копия — ' : 'Копия $index — ';
      final maxSourceLength = 120 - prefix.length;
      final source =
          normalized.length <= maxSourceLength
              ? normalized
              : normalized.substring(0, maxSourceLength).trimRight();
      final candidate = '$prefix$source';
      final exists = customTemplates.any(
        (template) =>
            template.title.trim().toLowerCase() == candidate.toLowerCase(),
      );
      if (!exists) {
        return candidate;
      }
      index += 1;
    }
  }

  NoteTemplate _normalize({
    required String id,
    required String title,
    required String icon,
    required String noteType,
    required String content,
    required String category,
    required List<String> defaultTags,
    required Map<String, String> defaultProperties,
  }) {
    final normalizedTags = <String>[];
    final seenTags = <String>{};
    for (final rawTag in defaultTags) {
      final tag = rawTag.trim();
      if (tag.isNotEmpty && seenTags.add(tag.toLowerCase())) {
        normalizedTags.add(tag);
      }
    }
    final normalizedProperties = <String, String>{};
    for (final entry in defaultProperties.entries) {
      final key = entry.key.trim();
      if (key.isNotEmpty) {
        normalizedProperties[key] = entry.value.trim();
      }
    }
    final template = NoteTemplate(
      id: id,
      title: title.trim(),
      icon: icon.trim().isEmpty ? '📝' : icon.trim(),
      noteType: noteType.trim().isEmpty ? 'note' : noteType.trim(),
      content: '${content.trimRight()}\n',
      category: category.trim(),
      defaultTags: List<String>.unmodifiable(normalizedTags),
      defaultProperties: Map<String, String>.unmodifiable(normalizedProperties),
      isCustom: true,
    );
    if (!CustomNoteTemplateStore.isValid(template)) {
      throw ArgumentError(
        'Шаблон должен иметь название и непустое содержимое допустимого размера.',
      );
    }
    return template;
  }

  Future<void> _replace(List<NoteTemplate> next) async {
    final normalized = List<NoteTemplate>.unmodifiable(next);
    await _store?.save(normalized);
    customTemplates = normalized;
    _notifyListeners();
  }
}
