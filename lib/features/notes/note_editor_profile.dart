enum NoteEditorFont {
  monospace(
    id: 'monospace',
    label: 'Моноширинный',
    description: 'Удобен для Markdown, таблиц и команд.',
  ),
  system(
    id: 'system',
    label: 'Системный',
    description: 'Спокойный шрифт интерфейса для длинного письма.',
  ),
  serif(
    id: 'serif',
    label: 'С засечками',
    description: 'Более книжный вид для связного текста.',
  );

  const NoteEditorFont({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;

  static NoteEditorFont fromId(Object? raw) {
    final id = raw?.toString();
    for (final value in values) {
      if (value.id == id) return value;
    }
    return NoteEditorFont.monospace;
  }
}

enum NoteEditorDensity {
  compact(
    id: 'compact',
    label: 'Компактная',
    horizontalPadding: 12,
    verticalPadding: 12,
  ),
  comfortable(
    id: 'comfortable',
    label: 'Комфортная',
    horizontalPadding: 20,
    verticalPadding: 18,
  ),
  spacious(
    id: 'spacious',
    label: 'Свободная',
    horizontalPadding: 32,
    verticalPadding: 26,
  );

  const NoteEditorDensity({
    required this.id,
    required this.label,
    required this.horizontalPadding,
    required this.verticalPadding,
  });

  final String id;
  final String label;
  final double horizontalPadding;
  final double verticalPadding;

  static NoteEditorDensity fromId(Object? raw) {
    final id = raw?.toString();
    for (final value in values) {
      if (value.id == id) return value;
    }
    return NoteEditorDensity.comfortable;
  }
}

enum NoteEditorStartMode {
  editor(id: 'editor', label: 'Редактор', value: 0),
  preview(id: 'preview', label: 'Предпросмотр', value: 1),
  split(id: 'split', label: 'Разделённый режим', value: 2);

  const NoteEditorStartMode({
    required this.id,
    required this.label,
    required this.value,
  });

  final String id;
  final String label;
  final int value;

  static NoteEditorStartMode fromId(Object? raw) {
    final id = raw?.toString();
    for (final value in values) {
      if (value.id == id) return value;
    }
    return NoteEditorStartMode.editor;
  }
}

class NoteEditorProfile {
  const NoteEditorProfile({
    required this.id,
    required this.name,
    required this.emoji,
    required this.font,
    required this.fontSize,
    required this.lineHeight,
    required this.contentWidth,
    required this.previewScale,
    required this.density,
    required this.startMode,
    required this.showTitle,
    required this.showToolbar,
    required this.showLinkSuggestions,
    required this.showContextPanel,
    required this.showTimerButton,
  });

  static const int maxProfiles = 12;
  static const int maxNameLength = 48;
  static const int maxEmojiLength = 8;

  final String id;
  final String name;
  final String emoji;
  final NoteEditorFont font;
  final double fontSize;
  final double lineHeight;
  final double contentWidth;
  final double previewScale;
  final NoteEditorDensity density;
  final NoteEditorStartMode startMode;
  final bool showTitle;
  final bool showToolbar;
  final bool showLinkSuggestions;
  final bool showContextPanel;
  final bool showTimerButton;

  String? get fontFamily => switch (font) {
    NoteEditorFont.monospace => 'monospace',
    NoteEditorFont.system => null,
    NoteEditorFont.serif => 'serif',
  };

  static List<NoteEditorProfile> defaults() => const <NoteEditorProfile>[
    NoteEditorProfile(
      id: 'scientific',
      name: 'Научный',
      emoji: '🔬',
      font: NoteEditorFont.monospace,
      fontSize: 15,
      lineHeight: 1.6,
      contentWidth: 940,
      previewScale: 1,
      density: NoteEditorDensity.comfortable,
      startMode: NoteEditorStartMode.split,
      showTitle: true,
      showToolbar: true,
      showLinkSuggestions: true,
      showContextPanel: true,
      showTimerButton: true,
    ),
    NoteEditorProfile(
      id: 'focus',
      name: 'Фокус',
      emoji: '✍️',
      font: NoteEditorFont.system,
      fontSize: 17,
      lineHeight: 1.75,
      contentWidth: 760,
      previewScale: 1.05,
      density: NoteEditorDensity.spacious,
      startMode: NoteEditorStartMode.editor,
      showTitle: true,
      showToolbar: false,
      showLinkSuggestions: false,
      showContextPanel: false,
      showTimerButton: false,
    ),
    NoteEditorProfile(
      id: 'compact',
      name: 'Компактный',
      emoji: '▦',
      font: NoteEditorFont.monospace,
      fontSize: 14,
      lineHeight: 1.45,
      contentWidth: 0,
      previewScale: 0.95,
      density: NoteEditorDensity.compact,
      startMode: NoteEditorStartMode.editor,
      showTitle: true,
      showToolbar: true,
      showLinkSuggestions: true,
      showContextPanel: false,
      showTimerButton: false,
    ),
  ];

  NoteEditorProfile copyWith({
    String? id,
    String? name,
    String? emoji,
    NoteEditorFont? font,
    double? fontSize,
    double? lineHeight,
    double? contentWidth,
    double? previewScale,
    NoteEditorDensity? density,
    NoteEditorStartMode? startMode,
    bool? showTitle,
    bool? showToolbar,
    bool? showLinkSuggestions,
    bool? showContextPanel,
    bool? showTimerButton,
  }) {
    return NoteEditorProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      font: font ?? this.font,
      fontSize: _bounded(fontSize ?? this.fontSize, 12, 24),
      lineHeight: _bounded(lineHeight ?? this.lineHeight, 1.2, 2.2),
      contentWidth: _normalizeWidth(contentWidth ?? this.contentWidth),
      previewScale: _bounded(previewScale ?? this.previewScale, 0.8, 1.4),
      density: density ?? this.density,
      startMode: startMode ?? this.startMode,
      showTitle: showTitle ?? this.showTitle,
      showToolbar: showToolbar ?? this.showToolbar,
      showLinkSuggestions: showLinkSuggestions ?? this.showLinkSuggestions,
      showContextPanel: showContextPanel ?? this.showContextPanel,
      showTimerButton: showTimerButton ?? this.showTimerButton,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'emoji': emoji,
    'font': font.id,
    'fontSize': fontSize,
    'lineHeight': lineHeight,
    'contentWidth': contentWidth,
    'previewScale': previewScale,
    'density': density.id,
    'startMode': startMode.id,
    'showTitle': showTitle,
    'showToolbar': showToolbar,
    'showLinkSuggestions': showLinkSuggestions,
    'showContextPanel': showContextPanel,
    'showTimerButton': showTimerButton,
  };

  static NoteEditorProfile? fromJson(Map<String, Object?> json) {
    final id = _trimmed(json['id'], 80);
    if (id.isEmpty) return null;
    final name = _trimmed(json['name'], maxNameLength);
    final emoji = _trimmed(json['emoji'], maxEmojiLength);
    return NoteEditorProfile(
      id: id,
      name: name.isEmpty ? 'Профиль редактора' : name,
      emoji: emoji.isEmpty ? 'Aa' : emoji,
      font: NoteEditorFont.fromId(json['font']),
      fontSize: _bounded(_number(json['fontSize'], 15), 12, 24),
      lineHeight: _bounded(_number(json['lineHeight'], 1.6), 1.2, 2.2),
      contentWidth: _normalizeWidth(_number(json['contentWidth'], 940)),
      previewScale: _bounded(_number(json['previewScale'], 1), 0.8, 1.4),
      density: NoteEditorDensity.fromId(json['density']),
      startMode: NoteEditorStartMode.fromId(json['startMode']),
      showTitle: _boolean(json['showTitle'], true),
      showToolbar: _boolean(json['showToolbar'], true),
      showLinkSuggestions: _boolean(json['showLinkSuggestions'], true),
      showContextPanel: _boolean(json['showContextPanel'], true),
      showTimerButton: _boolean(json['showTimerButton'], true),
    );
  }

  static String _trimmed(Object? value, int maxLength) {
    final text = value?.toString().trim() ?? '';
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength);
  }

  static double _number(Object? value, double fallback) {
    return value is num ? value.toDouble() : fallback;
  }

  static bool _boolean(Object? value, bool fallback) {
    return value is bool ? value : fallback;
  }

  static double _bounded(double value, double minimum, double maximum) {
    return value.clamp(minimum, maximum).toDouble();
  }

  static double _normalizeWidth(double value) {
    if (value <= 0) return 0;
    return _bounded(value, 560, 1400);
  }
}

class NoteEditorPreferences {
  const NoteEditorPreferences({
    required this.activeProfileId,
    required this.profiles,
  });

  final String activeProfileId;
  final List<NoteEditorProfile> profiles;

  factory NoteEditorPreferences.defaults() {
    final profiles = NoteEditorProfile.defaults();
    return NoteEditorPreferences(
      activeProfileId: profiles.first.id,
      profiles: List<NoteEditorProfile>.unmodifiable(profiles),
    );
  }

  NoteEditorProfile get activeProfile {
    for (final profile in profiles) {
      if (profile.id == activeProfileId) return profile;
    }
    return profiles.first;
  }

  NoteEditorPreferences copyWith({
    String? activeProfileId,
    List<NoteEditorProfile>? profiles,
  }) {
    return NoteEditorPreferences.normalized(
      activeProfileId: activeProfileId ?? this.activeProfileId,
      profiles: profiles ?? this.profiles,
    );
  }

  factory NoteEditorPreferences.normalized({
    required String activeProfileId,
    required Iterable<NoteEditorProfile> profiles,
  }) {
    final safeProfiles = <NoteEditorProfile>[];
    final ids = <String>{};
    for (final profile in profiles.take(NoteEditorProfile.maxProfiles)) {
      if (profile.id.trim().isEmpty || !ids.add(profile.id)) continue;
      safeProfiles.add(profile);
    }
    if (safeProfiles.isEmpty) return NoteEditorPreferences.defaults();
    return NoteEditorPreferences(
      activeProfileId: ids.contains(activeProfileId)
          ? activeProfileId
          : safeProfiles.first.id,
      profiles: List<NoteEditorProfile>.unmodifiable(safeProfiles),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'activeProfileId': activeProfileId,
    'profiles': profiles.map((profile) => profile.toJson()).toList(),
  };

  static NoteEditorPreferences fromJson(Map<String, Object?> json) {
    final profiles = <NoteEditorProfile>[];
    final rawProfiles = json['profiles'];
    if (rawProfiles is List) {
      for (final raw in rawProfiles) {
        if (raw is! Map) continue;
        final normalized = <String, Object?>{
          for (final entry in raw.entries)
            entry.key.toString(): entry.value,
        };
        final profile = NoteEditorProfile.fromJson(normalized);
        if (profile != null) profiles.add(profile);
      }
    }
    return NoteEditorPreferences.normalized(
      activeProfileId: json['activeProfileId']?.toString() ?? '',
      profiles: profiles,
    );
  }
}
