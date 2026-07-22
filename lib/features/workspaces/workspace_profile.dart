import '../../navigation/app_section.dart';

enum WorkspacePanel {
  timer(
    id: 'timer',
    label: 'Таймер',
    description: 'Текущая рабочая сессия и быстрый запуск таймера.',
  ),
  metrics(
    id: 'metrics',
    label: 'Метрики',
    description: 'Время за сегодня и число активных задач.',
  ),
  recentSessions(
    id: 'recent-sessions',
    label: 'Последние сессии',
    description: 'Недавние завершённые рабочие интервалы.',
  ),
  shortcuts(
    id: 'shortcuts',
    label: 'Быстрые клавиши',
    description: 'Подсказки по основным сочетаниям клавиш.',
  ),
  localFirst(
    id: 'local-first',
    label: 'Local-first',
    description: 'Напоминание о локальном хранении данных.',
  );

  const WorkspacePanel({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;

  static WorkspacePanel? fromId(Object? raw) {
    final id = raw?.toString();
    for (final panel in values) {
      if (panel.id == id) return panel;
    }
    return null;
  }
}

class WorkspaceProfile {
  const WorkspaceProfile({
    required this.id,
    required this.name,
    required this.emoji,
    required this.startSection,
    required this.showContextPanel,
    required this.extendedNavigation,
    required this.panelOrder,
    required this.visiblePanels,
  });

  static const int maxProfiles = 12;
  static const int maxNameLength = 48;
  static const int maxEmojiLength = 8;

  final String id;
  final String name;
  final String emoji;
  final AppSection startSection;
  final bool showContextPanel;
  final bool extendedNavigation;
  final List<WorkspacePanel> panelOrder;
  final Set<WorkspacePanel> visiblePanels;

  static List<WorkspaceProfile> defaults() => <WorkspaceProfile>[
    WorkspaceProfile(
      id: 'overview',
      name: 'Обзор',
      emoji: '🧭',
      startSection: AppSection.today,
      showContextPanel: true,
      extendedNavigation: true,
      panelOrder: List<WorkspacePanel>.unmodifiable(WorkspacePanel.values),
      visiblePanels: Set<WorkspacePanel>.unmodifiable(WorkspacePanel.values),
    ),
    const WorkspaceProfile(
      id: 'laboratory',
      name: 'Лаборатория',
      emoji: '🧪',
      startSection: AppSection.notes,
      showContextPanel: true,
      extendedNavigation: true,
      panelOrder: <WorkspacePanel>[
        WorkspacePanel.timer,
        WorkspacePanel.recentSessions,
        WorkspacePanel.metrics,
        WorkspacePanel.shortcuts,
        WorkspacePanel.localFirst,
      ],
      visiblePanels: <WorkspacePanel>{
        WorkspacePanel.timer,
        WorkspacePanel.recentSessions,
        WorkspacePanel.metrics,
      },
    ),
    WorkspaceProfile(
      id: 'focus',
      name: 'Фокус',
      emoji: '✍️',
      startSection: AppSection.notes,
      showContextPanel: false,
      extendedNavigation: false,
      panelOrder: List<WorkspacePanel>.unmodifiable(WorkspacePanel.values),
      visiblePanels: const <WorkspacePanel>{},
    ),
  ];

  WorkspaceProfile copyWith({
    String? id,
    String? name,
    String? emoji,
    AppSection? startSection,
    bool? showContextPanel,
    bool? extendedNavigation,
    List<WorkspacePanel>? panelOrder,
    Set<WorkspacePanel>? visiblePanels,
  }) {
    return WorkspaceProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      startSection: startSection ?? this.startSection,
      showContextPanel: showContextPanel ?? this.showContextPanel,
      extendedNavigation: extendedNavigation ?? this.extendedNavigation,
      panelOrder: List<WorkspacePanel>.unmodifiable(
        panelOrder ?? this.panelOrder,
      ),
      visiblePanels: Set<WorkspacePanel>.unmodifiable(
        visiblePanels ?? this.visiblePanels,
      ),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'emoji': emoji,
    'startSection': startSection.name,
    'showContextPanel': showContextPanel,
    'extendedNavigation': extendedNavigation,
    'panelOrder': panelOrder.map((panel) => panel.id).toList(growable: false),
    'visiblePanels': panelOrder
        .where(visiblePanels.contains)
        .map((panel) => panel.id)
        .toList(growable: false),
  };

  static WorkspaceProfile? fromJson(Map<String, Object?> json) {
    final id = _trimmed(json['id'], 80);
    if (id.isEmpty) return null;
    final name = _trimmed(json['name'], maxNameLength);
    final emoji = _trimmed(json['emoji'], maxEmojiLength);
    final section = _sectionFromName(json['startSection']);
    final order = _decodePanelOrder(json['panelOrder']);
    final visible = _decodeVisiblePanels(json['visiblePanels']);
    return WorkspaceProfile(
      id: id,
      name: name.isEmpty ? 'Рабочее пространство' : name,
      emoji: emoji.isEmpty ? '◫' : emoji,
      startSection: section ?? AppSection.notes,
      showContextPanel: json['showContextPanel'] is bool
          ? json['showContextPanel'] as bool
          : true,
      extendedNavigation: json['extendedNavigation'] is bool
          ? json['extendedNavigation'] as bool
          : true,
      panelOrder: List<WorkspacePanel>.unmodifiable(order),
      visiblePanels: Set<WorkspacePanel>.unmodifiable(visible),
    );
  }

  static String _trimmed(Object? value, int maxLength) {
    final text = value?.toString().trim() ?? '';
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength);
  }

  static AppSection? _sectionFromName(Object? raw) {
    final name = raw?.toString();
    for (final section in AppSection.values) {
      if (section.name == name) return section;
    }
    return null;
  }

  static List<WorkspacePanel> _decodePanelOrder(Object? raw) {
    final result = <WorkspacePanel>[];
    final seen = <WorkspacePanel>{};
    if (raw is List) {
      for (final item in raw) {
        final panel = WorkspacePanel.fromId(item);
        if (panel != null && seen.add(panel)) result.add(panel);
      }
    }
    for (final panel in WorkspacePanel.values) {
      if (seen.add(panel)) result.add(panel);
    }
    return result;
  }

  static Set<WorkspacePanel> _decodeVisiblePanels(Object? raw) {
    if (raw is! List) return Set<WorkspacePanel>.from(WorkspacePanel.values);
    final panels = <WorkspacePanel>{};
    for (final item in raw) {
      final panel = WorkspacePanel.fromId(item);
      if (panel != null) panels.add(panel);
    }
    return panels;
  }
}

class WorkspacePreferences {
  const WorkspacePreferences({
    required this.activeWorkspaceId,
    required this.profiles,
  });

  final String activeWorkspaceId;
  final List<WorkspaceProfile> profiles;

  factory WorkspacePreferences.defaults() {
    final profiles = WorkspaceProfile.defaults();
    return WorkspacePreferences(
      activeWorkspaceId: profiles.first.id,
      profiles: List<WorkspaceProfile>.unmodifiable(profiles),
    );
  }

  WorkspaceProfile get activeProfile {
    for (final profile in profiles) {
      if (profile.id == activeWorkspaceId) return profile;
    }
    return profiles.first;
  }

  WorkspacePreferences copyWith({
    String? activeWorkspaceId,
    List<WorkspaceProfile>? profiles,
  }) {
    return WorkspacePreferences.normalized(
      activeWorkspaceId: activeWorkspaceId ?? this.activeWorkspaceId,
      profiles: profiles ?? this.profiles,
    );
  }

  factory WorkspacePreferences.normalized({
    required String activeWorkspaceId,
    required Iterable<WorkspaceProfile> profiles,
  }) {
    final safeProfiles = <WorkspaceProfile>[];
    final ids = <String>{};
    for (final profile in profiles.take(WorkspaceProfile.maxProfiles)) {
      if (profile.id.trim().isEmpty || !ids.add(profile.id)) continue;
      safeProfiles.add(profile);
    }
    if (safeProfiles.isEmpty) {
      return WorkspacePreferences.defaults();
    }
    final safeActive = ids.contains(activeWorkspaceId)
        ? activeWorkspaceId
        : safeProfiles.first.id;
    return WorkspacePreferences(
      activeWorkspaceId: safeActive,
      profiles: List<WorkspaceProfile>.unmodifiable(safeProfiles),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'activeWorkspaceId': activeWorkspaceId,
    'profiles': profiles.map((profile) => profile.toJson()).toList(),
  };

  static WorkspacePreferences fromJson(Map<String, Object?> json) {
    final rawProfiles = json['profiles'];
    final profiles = <WorkspaceProfile>[];
    if (rawProfiles is List) {
      for (final raw in rawProfiles) {
        if (raw is! Map) continue;
        final normalized = <String, Object?>{
          for (final entry in raw.entries)
            entry.key.toString(): entry.value,
        };
        final profile = WorkspaceProfile.fromJson(normalized);
        if (profile != null) profiles.add(profile);
      }
    }
    return WorkspacePreferences.normalized(
      activeWorkspaceId: json['activeWorkspaceId']?.toString() ?? '',
      profiles: profiles,
    );
  }
}
