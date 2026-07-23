import 'package:flutter/material.dart';

import 'note_toolbar_profile.dart';

class NoteToolbarProfileDialog extends StatefulWidget {
  const NoteToolbarProfileDialog({super.key, required this.initialPreferences});

  final NoteToolbarPreferences initialPreferences;

  static Future<NoteToolbarPreferences?> show(
    BuildContext context, {
    required NoteToolbarPreferences preferences,
  }) {
    return showDialog<NoteToolbarPreferences>(
      context: context,
      builder:
          (context) =>
              NoteToolbarProfileDialog(initialPreferences: preferences),
    );
  }

  @override
  State<NoteToolbarProfileDialog> createState() =>
      _NoteToolbarProfileDialogState();
}

class _NoteToolbarProfileDialogState extends State<NoteToolbarProfileDialog> {
  late List<NoteToolbarProfile> profiles;
  late String activeProfileId;
  late int selectedIndex;
  final nameController = TextEditingController();
  final emojiController = TextEditingController();
  final searchController = TextEditingController();
  String actionQuery = '';

  NoteToolbarProfile get selected => profiles[selectedIndex];

  @override
  void initState() {
    super.initState();
    profiles = List<NoteToolbarProfile>.from(
      widget.initialPreferences.profiles,
    );
    activeProfileId = widget.initialPreferences.activeProfileId;
    selectedIndex = profiles.indexWhere(
      (profile) => profile.id == activeProfileId,
    );
    if (selectedIndex < 0) selectedIndex = 0;
    _syncControllers();
  }

  @override
  void dispose() {
    nameController.dispose();
    emojiController.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.all(20),
      title: const Text('Панели быстрых действий'),
      content: SizedBox(
        width: 1040,
        height: 700,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 780) {
              return Column(
                children: [
                  _compactProfileSelector(),
                  const SizedBox(height: 12),
                  Expanded(child: _profileEditor()),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 250, child: _profileList()),
                const VerticalDivider(width: 28),
                Expanded(child: _profileEditor()),
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
        FilledButton(onPressed: _save, child: const Text('Сохранить')),
      ],
    );
  }

  Widget _compactProfileSelector() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            key: ValueKey(selected.id),
            initialValue: selected.id,
            decoration: const InputDecoration(labelText: 'Панель'),
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
          tooltip: 'Новая панель',
          onPressed:
              profiles.length >= NoteToolbarProfile.maxProfiles
                  ? null
                  : _create,
          icon: const Icon(Icons.add_rounded),
        ),
        IconButton(
          tooltip: 'Дублировать',
          onPressed:
              profiles.length >= NoteToolbarProfile.maxProfiles
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

  Widget _profileList() {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Локальные панели',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Панель определяет только набор быстрых кнопок после инструментов блока.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ListView.builder(
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              final profile = profiles[index];
              final isSelected = selectedIndex == index;
              final isActive = profile.id == activeProfileId;
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
                  subtitle: Text('${profile.actionIds.length} действий'),
                  trailing:
                      isActive
                          ? Icon(
                            Icons.check_circle_rounded,
                            color: colors.primary,
                          )
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
              tooltip: 'Новая панель',
              onPressed:
                  profiles.length >= NoteToolbarProfile.maxProfiles
                      ? null
                      : _create,
              icon: const Icon(Icons.add_rounded),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Дублировать',
              onPressed:
                  profiles.length >= NoteToolbarProfile.maxProfiles
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

  Widget _profileEditor() {
    final profile = selected;
    final selectedActions = profile.actions;
    final selectedIds = profile.actionIds.toSet();
    final normalizedQuery = actionQuery.trim().toLowerCase();
    final available =
        NoteToolbarAction.values.where((action) {
          if (selectedIds.contains(action.id)) return false;
          if (normalizedQuery.isEmpty) return true;
          return action.label.toLowerCase().contains(normalizedQuery) ||
              action.description.toLowerCase().contains(normalizedQuery) ||
              action.group.label.toLowerCase().contains(normalizedQuery);
        }).toList();

    return ListView(
      padding: const EdgeInsets.only(right: 4),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Настройка панели',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (profile.id == activeProfileId)
              const Chip(
                avatar: Icon(Icons.check_rounded, size: 16),
                label: Text('Активна'),
              )
            else
              FilledButton.tonalIcon(
                onPressed: () => setState(() => activeProfileId = profile.id),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Сделать активной'),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            SizedBox(
              width: 92,
              child: TextField(
                controller: emojiController,
                maxLength: NoteToolbarProfile.maxEmojiLength,
                decoration: const InputDecoration(
                  labelText: 'Значок',
                  counterText: '',
                ),
                onChanged: (_) => _updateIdentity(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: nameController,
                maxLength: NoteToolbarProfile.maxNameLength,
                decoration: const InputDecoration(
                  labelText: 'Название панели',
                  counterText: '',
                ),
                onChanged: (_) => _updateIdentity(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Выбранные действия',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Кнопки отображаются слева направо в этом порядке. Инструменты undo/redo и текущего блока остаются всегда.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        if (selectedActions.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Панель пока пустая. Добавьте действия из каталога ниже.',
              ),
            ),
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var index = 0; index < selectedActions.length; index++)
                  _selectedActionTile(
                    action: selectedActions[index],
                    index: index,
                    length: selectedActions.length,
                  ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'Добавить действие',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${profile.actionIds.length}/${NoteToolbarProfile.maxActions}',
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: searchController,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            labelText: 'Поиск по каталогу',
          ),
          onChanged: (value) => setState(() => actionQuery = value),
        ),
        const SizedBox(height: 12),
        if (available.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Text('Подходящих действий нет.'),
          )
        else
          for (final group in NoteToolbarActionGroup.values)
            if (available.any((action) => action.group == group)) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 6),
                child: Text(
                  group.label,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final action in available)
                      if (action.group == group)
                        ListTile(
                          title: Text(action.label),
                          subtitle: Text(action.description),
                          trailing: const Icon(Icons.add_rounded),
                          enabled:
                              profile.actionIds.length <
                              NoteToolbarProfile.maxActions,
                          onTap:
                              profile.actionIds.length >=
                                      NoteToolbarProfile.maxActions
                                  ? null
                                  : () => _addAction(action),
                        ),
                  ],
                ),
              ),
            ],
      ],
    );
  }

  Widget _selectedActionTile({
    required NoteToolbarAction action,
    required int index,
    required int length,
  }) {
    return Column(
      children: [
        ListTile(
          leading: CircleAvatar(radius: 16, child: Text('${index + 1}')),
          title: Text(action.label),
          subtitle: Text(action.group.label),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Переместить левее',
                onPressed: index == 0 ? null : () => _moveAction(index, -1),
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
              IconButton(
                tooltip: 'Переместить правее',
                onPressed:
                    index == length - 1 ? null : () => _moveAction(index, 1),
                icon: const Icon(Icons.arrow_downward_rounded),
              ),
              IconButton(
                tooltip: 'Убрать с панели',
                onPressed: () => _removeAction(action),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        if (index < length - 1) const Divider(height: 1),
      ],
    );
  }

  void _syncControllers() {
    nameController.text = selected.name;
    emojiController.text = selected.emoji;
    searchController.clear();
    actionQuery = '';
  }

  void _select(int index) {
    if (index < 0 || index >= profiles.length) return;
    setState(() {
      selectedIndex = index;
      _syncControllers();
    });
  }

  void _updateIdentity() {
    final profile = selected;
    profiles[selectedIndex] = profile.copyWith(
      name: nameController.text,
      emoji: emojiController.text,
    );
    setState(() {});
  }

  void _addAction(NoteToolbarAction action) {
    final profile = selected;
    profiles[selectedIndex] = profile.copyWith(
      actionIds: <String>[...profile.actionIds, action.id],
    );
    setState(() {});
  }

  void _removeAction(NoteToolbarAction action) {
    final profile = selected;
    profiles[selectedIndex] = profile.copyWith(
      actionIds: profile.actionIds.where((id) => id != action.id),
    );
    setState(() {});
  }

  void _moveAction(int index, int delta) {
    final profile = selected;
    final nextIndex = index + delta;
    if (index < 0 || nextIndex < 0 || nextIndex >= profile.actionIds.length) {
      return;
    }
    final ids = List<String>.from(profile.actionIds);
    final action = ids.removeAt(index);
    ids.insert(nextIndex, action);
    profiles[selectedIndex] = profile.copyWith(actionIds: ids);
    setState(() {});
  }

  void _create() {
    if (profiles.length >= NoteToolbarProfile.maxProfiles) return;
    final id = 'toolbar-${DateTime.now().microsecondsSinceEpoch}';
    final profile = NoteToolbarProfile(
      id: id,
      name: _uniqueName('Новая панель'),
      emoji: '✦',
      actionIds: List<String>.from(selected.actionIds),
    );
    setState(() {
      profiles.add(profile);
      selectedIndex = profiles.length - 1;
      activeProfileId = profile.id;
      _syncControllers();
    });
  }

  void _duplicate() {
    if (profiles.length >= NoteToolbarProfile.maxProfiles) return;
    final source = selected;
    final profile = source.copyWith(
      id: 'toolbar-${DateTime.now().microsecondsSinceEpoch}',
      name: _uniqueName('Копия — ${source.name}'),
    );
    setState(() {
      profiles.add(profile);
      selectedIndex = profiles.length - 1;
      activeProfileId = profile.id;
      _syncControllers();
    });
  }

  void _delete() {
    if (profiles.length <= 1) return;
    final removed = profiles.removeAt(selectedIndex);
    if (selectedIndex >= profiles.length) selectedIndex = profiles.length - 1;
    if (activeProfileId == removed.id) {
      activeProfileId = profiles[selectedIndex].id;
    }
    setState(_syncControllers);
  }

  String _uniqueName(String base) {
    final existing = profiles.map((profile) => profile.name).toSet();
    if (!existing.contains(base)) return base;
    var index = 2;
    while (existing.contains('$base $index')) {
      index += 1;
    }
    return '$base $index';
  }

  void _save() {
    _updateIdentity();
    Navigator.pop(
      context,
      NoteToolbarPreferences.normalized(
        activeProfileId: activeProfileId,
        profiles: profiles,
      ),
    );
  }
}
