import 'package:flutter/material.dart';

import '../../navigation/app_section.dart';
import 'workspace_profile.dart';

class WorkspaceManagerDialog extends StatefulWidget {
  const WorkspaceManagerDialog({
    super.key,
    required this.initialPreferences,
  });

  final WorkspacePreferences initialPreferences;

  static Future<WorkspacePreferences?> show(
    BuildContext context, {
    required WorkspacePreferences preferences,
  }) {
    return showDialog<WorkspacePreferences>(
      context: context,
      builder: (context) => WorkspaceManagerDialog(
        initialPreferences: preferences,
      ),
    );
  }

  @override
  State<WorkspaceManagerDialog> createState() =>
      _WorkspaceManagerDialogState();
}

class _WorkspaceManagerDialogState extends State<WorkspaceManagerDialog> {
  late List<WorkspaceProfile> profiles;
  late String activeWorkspaceId;
  late int selectedIndex;
  final nameController = TextEditingController();
  final emojiController = TextEditingController();

  WorkspaceProfile get selected => profiles[selectedIndex];

  @override
  void initState() {
    super.initState();
    profiles = List<WorkspaceProfile>.from(widget.initialPreferences.profiles);
    activeWorkspaceId = widget.initialPreferences.activeWorkspaceId;
    selectedIndex = profiles.indexWhere(
      (profile) => profile.id == activeWorkspaceId,
    );
    if (selectedIndex < 0) selectedIndex = 0;
    _syncControllers();
  }

  @override
  void dispose() {
    nameController.dispose();
    emojiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.all(20),
      title: const Text('Рабочие пространства'),
      content: SizedBox(
        width: 900,
        height: 610,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 720) {
              return Column(
                children: [
                  _buildCompactSelector(),
                  const SizedBox(height: 12),
                  Expanded(child: _buildEditor()),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 250, child: _buildWorkspaceList()),
                const VerticalDivider(width: 28),
                Expanded(child: _buildEditor()),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }

  Widget _buildCompactSelector() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            key: ValueKey(selected.id),
            initialValue: selected.id,
            decoration: const InputDecoration(labelText: 'Пространство'),
            items: [
              for (final profile in profiles)
                DropdownMenuItem<String>(
                  value: profile.id,
                  child: Text('${profile.emoji} ${profile.name}'),
                ),
            ],
            onChanged: (id) {
              if (id == null) return;
              final index = profiles.indexWhere((profile) => profile.id == id);
              if (index >= 0) _select(index);
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Новое пространство',
          onPressed: profiles.length >= WorkspaceProfile.maxProfiles
              ? null
              : _create,
          icon: const Icon(Icons.add_rounded),
        ),
        IconButton(
          tooltip: 'Дублировать',
          onPressed: profiles.length >= WorkspaceProfile.maxProfiles
              ? null
              : _duplicate,
          icon: const Icon(Icons.copy_outlined),
        ),
        IconButton(
          tooltip: 'Удалить',
          onPressed: profiles.length <= 1 ? null : _delete,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ],
    );
  }

  Widget _buildWorkspaceList() {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Профили интерфейса',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Переключение пространства меняет только расположение интерфейса.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ListView.builder(
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              final profile = profiles[index];
              final isSelected = index == selectedIndex;
              final isActive = profile.id == activeWorkspaceId;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  selected: isSelected,
                  selectedTileColor: colors.secondaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: Text(
                    profile.emoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                  title: Text(
                    profile.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(profile.startSection.label),
                  trailing: isActive
                      ? Icon(Icons.check_circle_rounded, color: colors.primary)
                      : null,
                  onTap: () => _select(index),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            IconButton.filledTonal(
              tooltip: 'Новое пространство',
              onPressed: profiles.length >= WorkspaceProfile.maxProfiles
                  ? null
                  : _create,
              icon: const Icon(Icons.add_rounded),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Дублировать',
              onPressed: profiles.length >= WorkspaceProfile.maxProfiles
                  ? null
                  : _duplicate,
              icon: const Icon(Icons.copy_outlined),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Удалить',
              onPressed: profiles.length <= 1 ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditor() {
    final profile = selected;
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.only(right: 4),
      children: [
        Text(
          'Настройка пространства',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 94,
              child: TextField(
                controller: emojiController,
                maxLength: WorkspaceProfile.maxEmojiLength,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  labelText: 'Значок',
                  counterText: '',
                ),
                onChanged: (value) => _replaceSelected(
                  profile.copyWith(emoji: value.trim()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: nameController,
                maxLength: WorkspaceProfile.maxNameLength,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  counterText: '',
                ),
                onChanged: (value) => _replaceSelected(
                  profile.copyWith(name: value.trim()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<AppSection>(
          key: ValueKey('${profile.id}-${profile.startSection.name}'),
          initialValue: profile.startSection,
          decoration: const InputDecoration(
            labelText: 'Раздел при переключении',
          ),
          items: [
            for (final section in AppSection.values)
              DropdownMenuItem<AppSection>(
                value: section,
                child: Row(
                  children: [
                    Icon(section.icon, size: 20),
                    const SizedBox(width: 10),
                    Text(section.label),
                  ],
                ),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            _replaceSelected(profile.copyWith(startSection: value));
          },
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Расширенная навигация'),
          subtitle: const Text(
            'Показывать названия разделов, когда ширины окна достаточно.',
          ),
          value: profile.extendedNavigation,
          onChanged: (value) => _replaceSelected(
            profile.copyWith(extendedNavigation: value),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Правая контекстная панель'),
          subtitle: const Text(
            'Показывать панель на широких экранах. На узких она скрывается автоматически.',
          ),
          value: profile.showContextPanel,
          onChanged: (value) => _replaceSelected(
            profile.copyWith(showContextPanel: value),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'Блоки контекстной панели',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _replaceSelected(
                profile.copyWith(
                  visiblePanels: Set<WorkspacePanel>.from(
                    WorkspacePanel.values,
                  ),
                ),
              ),
              child: const Text('Показать все'),
            ),
          ],
        ),
        Text(
          'Перетаскивай блоки, чтобы изменить порядок. Скрытые блоки сохраняют своё место.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 290,
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: profile.panelOrder.length,
            onReorder: _reorderPanels,
            itemBuilder: (context, index) {
              final panel = profile.panelOrder[index];
              final visible = profile.visiblePanels.contains(panel);
              return Card(
                key: ValueKey(panel.id),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Checkbox(
                    value: visible,
                    onChanged: (value) => _togglePanel(panel, value ?? false),
                  ),
                  title: Text(panel.label),
                  subtitle: Text(panel.description),
                  trailing: ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.drag_handle_rounded),
                    ),
                  ),
                  onTap: () => _togglePanel(panel, !visible),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: activeWorkspaceId == profile.id,
          title: const Text('Использовать это пространство сейчас'),
          subtitle: const Text(
            'После сохранения Chronicle переключится на выбранный профиль.',
          ),
          onChanged: (value) {
            if (value == true) {
              setState(() => activeWorkspaceId = profile.id);
            }
          },
        ),
      ],
    );
  }

  void _select(int index) {
    if (index == selectedIndex) return;
    setState(() => selectedIndex = index);
    _syncControllers();
  }

  void _syncControllers() {
    nameController.text = selected.name;
    emojiController.text = selected.emoji;
  }

  void _replaceSelected(WorkspaceProfile profile) {
    setState(() => profiles[selectedIndex] = profile);
  }

  void _create() {
    final id = _uniqueId('workspace');
    final profile = selected.copyWith(
      id: id,
      name: _uniqueName('Новое пространство'),
      emoji: '◫',
    );
    setState(() {
      profiles.add(profile);
      selectedIndex = profiles.length - 1;
      activeWorkspaceId = profile.id;
    });
    _syncControllers();
  }

  void _duplicate() {
    final source = selected;
    final profile = source.copyWith(
      id: _uniqueId(source.id),
      name: _uniqueName('Копия — ${source.name}'),
    );
    setState(() {
      profiles.add(profile);
      selectedIndex = profiles.length - 1;
      activeWorkspaceId = profile.id;
    });
    _syncControllers();
  }

  void _delete() {
    if (profiles.length <= 1) return;
    final removed = selected;
    setState(() {
      profiles.removeAt(selectedIndex);
      if (selectedIndex >= profiles.length) selectedIndex = profiles.length - 1;
      if (activeWorkspaceId == removed.id) {
        activeWorkspaceId = profiles[selectedIndex].id;
      }
    });
    _syncControllers();
  }

  void _togglePanel(WorkspacePanel panel, bool visible) {
    final next = Set<WorkspacePanel>.from(selected.visiblePanels);
    if (visible) {
      next.add(panel);
    } else {
      next.remove(panel);
    }
    _replaceSelected(selected.copyWith(visiblePanels: next));
  }

  void _reorderPanels(int oldIndex, int newIndex) {
    final order = List<WorkspacePanel>.from(selected.panelOrder);
    if (newIndex > oldIndex) newIndex -= 1;
    final panel = order.removeAt(oldIndex);
    order.insert(newIndex, panel);
    _replaceSelected(selected.copyWith(panelOrder: order));
  }

  String _uniqueId(String prefix) {
    final used = profiles.map((profile) => profile.id).toSet();
    var suffix = DateTime.now().microsecondsSinceEpoch;
    var candidate = '$prefix-$suffix';
    while (used.contains(candidate)) {
      suffix += 1;
      candidate = '$prefix-$suffix';
    }
    return candidate;
  }

  String _uniqueName(String base) {
    final used = profiles.map((profile) => profile.name).toSet();
    if (!used.contains(base)) return base;
    var number = 2;
    while (used.contains('$base $number')) {
      number += 1;
    }
    return '$base $number';
  }

  void _save() {
    final normalized = WorkspacePreferences.normalized(
      activeWorkspaceId: activeWorkspaceId,
      profiles: [
        for (final profile in profiles)
          profile.copyWith(
            name: profile.name.trim().isEmpty
                ? 'Рабочее пространство'
                : profile.name.trim(),
            emoji: profile.emoji.trim().isEmpty ? '◫' : profile.emoji.trim(),
          ),
      ],
    );
    Navigator.pop(context, normalized);
  }
}
