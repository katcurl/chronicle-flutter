enum NoteHomeSection {
  continueWork(
    id: 'continue_work',
    label: 'Продолжить работу',
    description: 'Активная заметка и записи, связанные с незавершёнными задачами.',
  ),
  pinned(
    id: 'pinned',
    label: 'Закреплённые',
    description: 'Заметки, которые всегда должны быть под рукой.',
  ),
  recent(
    id: 'recent',
    label: 'Недавние',
    description: 'Последние изменённые записи из всех проектов.',
  ),
  projects(
    id: 'projects',
    label: 'Проекты',
    description: 'Быстрый переход к заметкам активного проекта.',
  ),
  folders(
    id: 'folders',
    label: 'Папки',
    description: 'Навигация по используемым путям папок.',
  ),
  templates(
    id: 'templates',
    label: 'Шаблоны',
    description: 'Создание новой записи из готовой структуры.',
  );

  const NoteHomeSection({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;

  static NoteHomeSection? fromId(Object? raw) {
    final id = raw?.toString();
    for (final section in values) {
      if (section.id == id) return section;
    }
    return null;
  }
}

class NoteHomePreferences {
  const NoteHomePreferences({
    required this.sectionIds,
    required this.hiddenSectionIds,
    required this.itemLimit,
    required this.compactCards,
    required this.openOnHome,
  });

  static const int minItemLimit = 2;
  static const int maxItemLimit = 8;

  final List<String> sectionIds;
  final Set<String> hiddenSectionIds;
  final int itemLimit;
  final bool compactCards;
  final bool openOnHome;

  factory NoteHomePreferences.defaults() {
    return NoteHomePreferences(
      sectionIds: List<String>.unmodifiable(
        NoteHomeSection.values.map((section) => section.id),
      ),
      hiddenSectionIds: const <String>{},
      itemLimit: 4,
      compactCards: false,
      openOnHome: true,
    );
  }

  List<NoteHomeSection> get orderedSections => List<NoteHomeSection>.unmodifiable(
    sectionIds.map(NoteHomeSection.fromId).whereType<NoteHomeSection>(),
  );

  bool isVisible(NoteHomeSection section) {
    return !hiddenSectionIds.contains(section.id);
  }

  NoteHomePreferences copyWith({
    Iterable<String>? sectionIds,
    Iterable<String>? hiddenSectionIds,
    int? itemLimit,
    bool? compactCards,
    bool? openOnHome,
  }) {
    return NoteHomePreferences.normalized(
      sectionIds: sectionIds ?? this.sectionIds,
      hiddenSectionIds: hiddenSectionIds ?? this.hiddenSectionIds,
      itemLimit: itemLimit ?? this.itemLimit,
      compactCards: compactCards ?? this.compactCards,
      openOnHome: openOnHome ?? this.openOnHome,
    );
  }

  factory NoteHomePreferences.normalized({
    required Iterable<String> sectionIds,
    required Iterable<String> hiddenSectionIds,
    required int itemLimit,
    required bool compactCards,
    required bool openOnHome,
  }) {
    final normalizedSections = <String>[];
    final seen = <String>{};
    for (final rawId in sectionIds) {
      final section = NoteHomeSection.fromId(rawId);
      if (section == null || !seen.add(section.id)) continue;
      normalizedSections.add(section.id);
    }
    for (final section in NoteHomeSection.values) {
      if (seen.add(section.id)) normalizedSections.add(section.id);
    }

    final hidden = <String>{};
    for (final rawId in hiddenSectionIds) {
      final section = NoteHomeSection.fromId(rawId);
      if (section != null) hidden.add(section.id);
    }

    return NoteHomePreferences(
      sectionIds: List<String>.unmodifiable(normalizedSections),
      hiddenSectionIds: Set<String>.unmodifiable(hidden),
      itemLimit: itemLimit.clamp(minItemLimit, maxItemLimit).toInt(),
      compactCards: compactCards,
      openOnHome: openOnHome,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'sectionIds': sectionIds,
    'hiddenSectionIds': hiddenSectionIds.toList(),
    'itemLimit': itemLimit,
    'compactCards': compactCards,
    'openOnHome': openOnHome,
  };

  static NoteHomePreferences fromJson(Map<String, Object?> json) {
    final rawSections = json['sectionIds'];
    final rawHidden = json['hiddenSectionIds'];
    return NoteHomePreferences.normalized(
      sectionIds: rawSections is List
          ? rawSections.map((value) => value.toString())
          : const <String>[],
      hiddenSectionIds: rawHidden is List
          ? rawHidden.map((value) => value.toString())
          : const <String>[],
      itemLimit: _readInt(json['itemLimit'], fallback: 4),
      compactCards: _readBool(json['compactCards']),
      openOnHome: _readBool(json['openOnHome'], fallback: true),
    );
  }

  static int _readInt(Object? value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static bool _readBool(Object? value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase();
    if (text == 'true') return true;
    if (text == 'false') return false;
    return fallback;
  }
}
