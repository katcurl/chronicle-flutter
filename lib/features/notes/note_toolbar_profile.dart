enum NoteToolbarActionGroup {
  templates(id: 'templates', label: 'Шаблоны'),
  writing(id: 'writing', label: 'Текст и структура'),
  links(id: 'links', label: 'Ссылки и источники'),
  data(id: 'data', label: 'Данные и научные объекты'),
  media(id: 'media', label: 'Вложения и макет');

  const NoteToolbarActionGroup({required this.id, required this.label});

  final String id;
  final String label;
}

enum NoteToolbarAction {
  applyTemplate(
    id: 'apply_template',
    label: 'Применить шаблон',
    description: 'Вставить встроенный или пользовательский шаблон.',
    group: NoteToolbarActionGroup.templates,
  ),
  saveAsTemplate(
    id: 'save_as_template',
    label: 'Сохранить как шаблон',
    description: 'Создать шаблон из текущей заметки.',
    group: NoteToolbarActionGroup.templates,
  ),
  manageTemplates(
    id: 'manage_templates',
    label: 'Библиотека шаблонов',
    description: 'Открыть пользовательскую библиотеку шаблонов.',
    group: NoteToolbarActionGroup.templates,
  ),
  heading(
    id: 'heading',
    label: 'Заголовок',
    description: 'Вставить заголовок первого уровня.',
    group: NoteToolbarActionGroup.writing,
  ),
  bold(
    id: 'bold',
    label: 'Жирный текст',
    description: 'Обернуть выделение в двойные звёздочки.',
    group: NoteToolbarActionGroup.writing,
  ),
  italic(
    id: 'italic',
    label: 'Курсив',
    description: 'Обернуть выделение в символы подчёркивания.',
    group: NoteToolbarActionGroup.writing,
  ),
  bulletedList(
    id: 'bulleted_list',
    label: 'Маркированный список',
    description: 'Начать строку маркированного списка.',
    group: NoteToolbarActionGroup.writing,
  ),
  checklist(
    id: 'checklist',
    label: 'Чек-лист',
    description: 'Начать строку с невыполненной задачей.',
    group: NoteToolbarActionGroup.writing,
  ),
  inlineMath(
    id: 'inline_math',
    label: 'Формула в строке',
    description: 'Обернуть выделение в знаки доллара.',
    group: NoteToolbarActionGroup.writing,
  ),
  displayMath(
    id: 'display_math',
    label: 'Блочная формула',
    description: 'Вставить отдельный LaTeX-блок.',
    group: NoteToolbarActionGroup.writing,
  ),
  codeBlock(
    id: 'code_block',
    label: 'Блок кода',
    description: 'Обернуть выделение в fenced code block.',
    group: NoteToolbarActionGroup.writing,
  ),
  noteLink(
    id: 'note_link',
    label: 'Ссылка на заметку',
    description: 'Вставить устойчивую ссылку по ID.',
    group: NoteToolbarActionGroup.links,
  ),
  citation(
    id: 'citation',
    label: 'Научная цитата',
    description: 'Вставить ссылку на источник.',
    group: NoteToolbarActionGroup.links,
  ),
  bibliography(
    id: 'bibliography',
    label: 'Библиография',
    description: 'Вставить блок списка литературы.',
    group: NoteToolbarActionGroup.links,
  ),
  scientificReference(
    id: 'scientific_reference',
    label: 'Ссылка на рисунок или таблицу',
    description: 'Вставить перекрёстную ссылку на научный объект.',
    group: NoteToolbarActionGroup.links,
  ),
  importData(
    id: 'import_data',
    label: 'Импорт данных',
    description: 'Добавить CSV, TSV, изображения или набор файлов.',
    group: NoteToolbarActionGroup.data,
  ),
  exportNote(
    id: 'export_note',
    label: 'Экспорт заметки',
    description: 'Экспортировать Markdown, HTML или ZIP.',
    group: NoteToolbarActionGroup.data,
  ),
  scientificTable(
    id: 'scientific_table',
    label: 'Научная таблица',
    description: 'Создать или отредактировать Markdown-таблицу.',
    group: NoteToolbarActionGroup.data,
  ),
  inspectScientificObjects(
    id: 'inspect_scientific_objects',
    label: 'Проверить научные объекты',
    description: 'Проверить рисунки, таблицы и ссылки.',
    group: NoteToolbarActionGroup.data,
  ),
  attach(
    id: 'attach',
    label: 'Добавить вложение',
    description: 'Выбрать локальный файл и сохранить в Attachments.',
    group: NoteToolbarActionGroup.media,
  ),
  pasteImage(
    id: 'paste_image',
    label: 'Изображение из буфера',
    description: 'Вставить изображение из системного буфера.',
    group: NoteToolbarActionGroup.media,
  ),
  configureImage(
    id: 'configure_image',
    label: 'Настроить изображение',
    description: 'Изменить размер, выравнивание и подпись.',
    group: NoteToolbarActionGroup.media,
  ),
  columns(
    id: 'columns',
    label: 'Колонки',
    description: 'Создать или настроить многоколоночный блок.',
    group: NoteToolbarActionGroup.media,
  ),
  imageSyntax(
    id: 'image_syntax',
    label: 'Markdown-изображение',
    description: 'Вставить пустой Markdown-синтаксис изображения.',
    group: NoteToolbarActionGroup.media,
  );

  const NoteToolbarAction({
    required this.id,
    required this.label,
    required this.description,
    required this.group,
  });

  final String id;
  final String label;
  final String description;
  final NoteToolbarActionGroup group;

  static NoteToolbarAction? fromId(Object? raw) {
    final id = raw?.toString();
    for (final action in values) {
      if (action.id == id) return action;
    }
    return null;
  }
}

class NoteToolbarProfile {
  const NoteToolbarProfile({
    required this.id,
    required this.name,
    required this.emoji,
    required this.actionIds,
  });

  static const int maxProfiles = 12;
  static const int maxActions = 24;
  static const int maxNameLength = 48;
  static const int maxEmojiLength = 8;

  final String id;
  final String name;
  final String emoji;
  final List<String> actionIds;

  List<NoteToolbarAction> get actions => List<NoteToolbarAction>.unmodifiable(
    actionIds.map(NoteToolbarAction.fromId).whereType<NoteToolbarAction>(),
  );

  static List<NoteToolbarProfile> defaults() => <NoteToolbarProfile>[
    NoteToolbarProfile(
      id: 'laboratory',
      name: 'Лаборатория',
      emoji: '🧪',
      actionIds: _ids(const <NoteToolbarAction>[
        NoteToolbarAction.applyTemplate,
        NoteToolbarAction.scientificTable,
        NoteToolbarAction.importData,
        NoteToolbarAction.pasteImage,
        NoteToolbarAction.configureImage,
        NoteToolbarAction.columns,
        NoteToolbarAction.scientificReference,
        NoteToolbarAction.inspectScientificObjects,
        NoteToolbarAction.attach,
        NoteToolbarAction.noteLink,
        NoteToolbarAction.citation,
        NoteToolbarAction.bibliography,
        NoteToolbarAction.exportNote,
      ]),
    ),
    NoteToolbarProfile(
      id: 'study',
      name: 'Учёба',
      emoji: '📚',
      actionIds: _ids(const <NoteToolbarAction>[
        NoteToolbarAction.heading,
        NoteToolbarAction.bold,
        NoteToolbarAction.italic,
        NoteToolbarAction.bulletedList,
        NoteToolbarAction.checklist,
        NoteToolbarAction.noteLink,
        NoteToolbarAction.citation,
        NoteToolbarAction.bibliography,
        NoteToolbarAction.inlineMath,
        NoteToolbarAction.displayMath,
        NoteToolbarAction.codeBlock,
        NoteToolbarAction.attach,
        NoteToolbarAction.pasteImage,
      ]),
    ),
    NoteToolbarProfile(
      id: 'minimal',
      name: 'Минимальная',
      emoji: '✦',
      actionIds: _ids(const <NoteToolbarAction>[
        NoteToolbarAction.heading,
        NoteToolbarAction.bold,
        NoteToolbarAction.italic,
        NoteToolbarAction.bulletedList,
        NoteToolbarAction.noteLink,
        NoteToolbarAction.attach,
        NoteToolbarAction.pasteImage,
        NoteToolbarAction.codeBlock,
      ]),
    ),
  ];

  NoteToolbarProfile copyWith({
    String? id,
    String? name,
    String? emoji,
    Iterable<String>? actionIds,
  }) {
    final safeName = _trimmed(name ?? this.name, maxNameLength);
    final safeEmoji = _trimmed(emoji ?? this.emoji, maxEmojiLength);
    return NoteToolbarProfile(
      id: id ?? this.id,
      name: safeName.isEmpty ? 'Панель действий' : safeName,
      emoji: safeEmoji.isEmpty ? '✦' : safeEmoji,
      actionIds: _normalizeActions(actionIds ?? this.actionIds),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'emoji': emoji,
    'actionIds': actionIds,
  };

  static NoteToolbarProfile? fromJson(Map<String, Object?> json) {
    final id = _trimmed(json['id'], 80);
    if (id.isEmpty) return null;
    final name = _trimmed(json['name'], maxNameLength);
    final emoji = _trimmed(json['emoji'], maxEmojiLength);
    final rawActions = json['actionIds'];
    final actions =
        rawActions is List
            ? rawActions.map((value) => value.toString())
            : const <String>[];
    return NoteToolbarProfile(
      id: id,
      name: name.isEmpty ? 'Панель действий' : name,
      emoji: emoji.isEmpty ? '✦' : emoji,
      actionIds: _normalizeActions(actions),
    );
  }

  static List<String> _ids(Iterable<NoteToolbarAction> actions) {
    return List<String>.unmodifiable(actions.map((action) => action.id));
  }

  static List<String> _normalizeActions(Iterable<String> actionIds) {
    final result = <String>[];
    final seen = <String>{};
    for (final rawId in actionIds) {
      final action = NoteToolbarAction.fromId(rawId);
      if (action == null || !seen.add(action.id)) continue;
      result.add(action.id);
      if (result.length >= maxActions) break;
    }
    return List<String>.unmodifiable(result);
  }

  static String _trimmed(Object? value, int maxLength) {
    final text = value?.toString().trim() ?? '';
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength);
  }
}

class NoteToolbarPreferences {
  const NoteToolbarPreferences({
    required this.activeProfileId,
    required this.profiles,
  });

  final String activeProfileId;
  final List<NoteToolbarProfile> profiles;

  factory NoteToolbarPreferences.defaults() {
    final profiles = NoteToolbarProfile.defaults();
    return NoteToolbarPreferences(
      activeProfileId: profiles.first.id,
      profiles: List<NoteToolbarProfile>.unmodifiable(profiles),
    );
  }

  NoteToolbarProfile get activeProfile {
    for (final profile in profiles) {
      if (profile.id == activeProfileId) return profile;
    }
    return profiles.first;
  }

  NoteToolbarPreferences copyWith({
    String? activeProfileId,
    Iterable<NoteToolbarProfile>? profiles,
  }) {
    return NoteToolbarPreferences.normalized(
      activeProfileId: activeProfileId ?? this.activeProfileId,
      profiles: profiles ?? this.profiles,
    );
  }

  factory NoteToolbarPreferences.normalized({
    required String activeProfileId,
    required Iterable<NoteToolbarProfile> profiles,
  }) {
    final result = <NoteToolbarProfile>[];
    final ids = <String>{};
    for (final profile in profiles.take(NoteToolbarProfile.maxProfiles)) {
      if (profile.id.trim().isEmpty || !ids.add(profile.id)) continue;
      result.add(profile.copyWith());
    }
    if (result.isEmpty) return NoteToolbarPreferences.defaults();
    return NoteToolbarPreferences(
      activeProfileId:
          ids.contains(activeProfileId) ? activeProfileId : result.first.id,
      profiles: List<NoteToolbarProfile>.unmodifiable(result),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'activeProfileId': activeProfileId,
    'profiles': profiles.map((profile) => profile.toJson()).toList(),
  };

  static NoteToolbarPreferences fromJson(Map<String, Object?> json) {
    final profiles = <NoteToolbarProfile>[];
    final rawProfiles = json['profiles'];
    if (rawProfiles is List) {
      for (final raw in rawProfiles) {
        if (raw is! Map) continue;
        final normalized = <String, Object?>{
          for (final entry in raw.entries) entry.key.toString(): entry.value,
        };
        final profile = NoteToolbarProfile.fromJson(normalized);
        if (profile != null) profiles.add(profile);
      }
    }
    return NoteToolbarPreferences.normalized(
      activeProfileId: json['activeProfileId']?.toString() ?? '',
      profiles: profiles,
    );
  }
}
