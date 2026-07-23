import 'package:flutter/material.dart';

import 'note_editor_profile.dart';

class NoteEditorProfileDialog extends StatefulWidget {
  const NoteEditorProfileDialog({super.key, required this.initialPreferences});

  final NoteEditorPreferences initialPreferences;

  static Future<NoteEditorPreferences?> show(
    BuildContext context, {
    required NoteEditorPreferences preferences,
  }) {
    return showDialog<NoteEditorPreferences>(
      context: context,
      builder:
          (context) => NoteEditorProfileDialog(initialPreferences: preferences),
    );
  }

  @override
  State<NoteEditorProfileDialog> createState() =>
      _NoteEditorProfileDialogState();
}

class _NoteEditorProfileDialogState extends State<NoteEditorProfileDialog> {
  late List<NoteEditorProfile> profiles;
  late String activeProfileId;
  late int selectedIndex;
  final nameController = TextEditingController();
  final emojiController = TextEditingController();

  NoteEditorProfile get selected => profiles[selectedIndex];

  @override
  void initState() {
    super.initState();
    profiles = List<NoteEditorProfile>.from(widget.initialPreferences.profiles);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.all(20),
      title: const Text('Профили редактора'),
      content: SizedBox(
        width: 980,
        height: 680,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 760) {
              return Column(
                children: [
                  _compactSelector(),
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

  Widget _compactSelector() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            key: ValueKey(selected.id),
            initialValue: selected.id,
            decoration: const InputDecoration(labelText: 'Профиль'),
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
          tooltip: 'Новый профиль',
          onPressed:
              profiles.length >= NoteEditorProfile.maxProfiles ? null : _create,
          icon: const Icon(Icons.add_rounded),
        ),
        IconButton(
          tooltip: 'Дублировать',
          onPressed:
              profiles.length >= NoteEditorProfile.maxProfiles
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
          'Локальные пресеты',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Профиль меняет только внешний вид и поведение редактора.',
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
              final isSelected = index == selectedIndex;
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
                  subtitle: Text(
                    '${profile.font.label} · ${profile.fontSize.round()} px',
                  ),
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
              tooltip: 'Новый профиль',
              onPressed:
                  profiles.length >= NoteEditorProfile.maxProfiles
                      ? null
                      : _create,
              icon: const Icon(Icons.add_rounded),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Дублировать',
              onPressed:
                  profiles.length >= NoteEditorProfile.maxProfiles
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
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.only(right: 4),
      children: [
        Text(
          'Настройка редактора',
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
                maxLength: NoteEditorProfile.maxEmojiLength,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  labelText: 'Значок',
                  counterText: '',
                ),
                onChanged:
                    (value) =>
                        _replaceSelected(profile.copyWith(emoji: value.trim())),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: nameController,
                maxLength: NoteEditorProfile.maxNameLength,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  counterText: '',
                ),
                onChanged:
                    (value) =>
                        _replaceSelected(profile.copyWith(name: value.trim())),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<NoteEditorFont>(
                key: ValueKey('${profile.id}-${profile.font.id}'),
                initialValue: profile.font,
                decoration: const InputDecoration(labelText: 'Шрифт'),
                items: [
                  for (final font in NoteEditorFont.values)
                    DropdownMenuItem<NoteEditorFont>(
                      value: font,
                      child: Text(font.label),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  _replaceSelected(profile.copyWith(font: value));
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<NoteEditorDensity>(
                key: ValueKey('${profile.id}-${profile.density.id}'),
                initialValue: profile.density,
                decoration: const InputDecoration(labelText: 'Плотность'),
                items: [
                  for (final density in NoteEditorDensity.values)
                    DropdownMenuItem<NoteEditorDensity>(
                      value: density,
                      child: Text(density.label),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  _replaceSelected(profile.copyWith(density: value));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<NoteEditorStartMode>(
          key: ValueKey('${profile.id}-${profile.startMode.id}'),
          initialValue: profile.startMode,
          decoration: const InputDecoration(
            labelText: 'Режим при открытии заметки',
          ),
          items: [
            for (final mode in NoteEditorStartMode.values)
              DropdownMenuItem<NoteEditorStartMode>(
                value: mode,
                child: Text(mode.label),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            _replaceSelected(profile.copyWith(startMode: value));
          },
        ),
        const SizedBox(height: 18),
        _slider(
          label: 'Размер текста',
          valueLabel: '${profile.fontSize.toStringAsFixed(0)} px',
          value: profile.fontSize,
          min: 12,
          max: 24,
          divisions: 12,
          onChanged:
              (value) => _replaceSelected(profile.copyWith(fontSize: value)),
        ),
        _slider(
          label: 'Межстрочный интервал',
          valueLabel: profile.lineHeight.toStringAsFixed(2),
          value: profile.lineHeight,
          min: 1.2,
          max: 2.2,
          divisions: 20,
          onChanged:
              (value) => _replaceSelected(profile.copyWith(lineHeight: value)),
        ),
        _slider(
          label: 'Масштаб предпросмотра',
          valueLabel: '${(profile.previewScale * 100).round()}%',
          value: profile.previewScale,
          min: 0.8,
          max: 1.4,
          divisions: 12,
          onChanged:
              (value) =>
                  _replaceSelected(profile.copyWith(previewScale: value)),
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ограничивать ширину текста'),
          subtitle: Text(
            profile.contentWidth <= 0
                ? 'Редактор использует всю доступную ширину.'
                : 'Максимальная ширина: ${profile.contentWidth.round()} px.',
          ),
          value: profile.contentWidth > 0,
          onChanged:
              (value) => _replaceSelected(
                profile.copyWith(contentWidth: value ? 940 : 0),
              ),
        ),
        if (profile.contentWidth > 0)
          _slider(
            label: 'Ширина текста',
            valueLabel: '${profile.contentWidth.round()} px',
            value: profile.contentWidth,
            min: 560,
            max: 1400,
            divisions: 21,
            onChanged:
                (value) =>
                    _replaceSelected(profile.copyWith(contentWidth: value)),
          ),
        const SizedBox(height: 8),
        Text(
          'Элементы интерфейса',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        _switch(
          title: 'Поле названия',
          value: profile.showTitle,
          onChanged:
              (value) => _replaceSelected(profile.copyWith(showTitle: value)),
        ),
        _switch(
          title: 'Панель инструментов Markdown',
          value: profile.showToolbar,
          onChanged:
              (value) => _replaceSelected(profile.copyWith(showToolbar: value)),
        ),
        _switch(
          title: 'Подсказки wiki-ссылок',
          value: profile.showLinkSuggestions,
          onChanged:
              (value) => _replaceSelected(
                profile.copyWith(showLinkSuggestions: value),
              ),
        ),
        _switch(
          title: 'Контекстная панель заметки',
          subtitle: 'На узком экране она по-прежнему доступна через кнопку.',
          value: profile.showContextPanel,
          onChanged:
              (value) =>
                  _replaceSelected(profile.copyWith(showContextPanel: value)),
        ),
        _switch(
          title: 'Кнопка «Работать»',
          value: profile.showTimerButton,
          onChanged:
              (value) =>
                  _replaceSelected(profile.copyWith(showTimerButton: value)),
        ),
        const SizedBox(height: 14),
        _preview(profile, colors),
        const SizedBox(height: 10),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: activeProfileId == profile.id,
          title: const Text('Использовать этот профиль сейчас'),
          subtitle: const Text(
            'После сохранения открытая заметка сразу применит настройки.',
          ),
          onChanged: (value) {
            if (value == true) {
              setState(() => activeProfileId = profile.id);
            }
          },
        ),
      ],
    );
  }

  Widget _slider({
    required String label,
    required String valueLabel,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(valueLabel, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          divisions: divisions,
          label: valueLabel,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _switch({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _preview(NoteEditorProfile profile, ColorScheme colors) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: profile.density.horizontalPadding,
          vertical: profile.density.verticalPadding,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth:
                profile.contentWidth > 0
                    ? profile.contentWidth
                    : double.infinity,
          ),
          child: Text(
            '# ORF9b\n\nГипотеза, наблюдения и результаты эксперимента.',
            style: TextStyle(
              fontFamily: profile.fontFamily,
              fontSize: profile.fontSize,
              height: profile.lineHeight,
            ),
          ),
        ),
      ),
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

  void _replaceSelected(NoteEditorProfile profile) {
    setState(() => profiles[selectedIndex] = profile);
  }

  void _create() {
    final profile = selected.copyWith(
      id: _uniqueId('editor'),
      name: _uniqueName('Новый профиль'),
      emoji: 'Aa',
    );
    setState(() {
      profiles.add(profile);
      selectedIndex = profiles.length - 1;
      activeProfileId = profile.id;
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
      activeProfileId = profile.id;
    });
    _syncControllers();
  }

  void _delete() {
    if (profiles.length <= 1) return;
    final removed = selected;
    setState(() {
      profiles.removeAt(selectedIndex);
      if (selectedIndex >= profiles.length) selectedIndex = profiles.length - 1;
      if (activeProfileId == removed.id) {
        activeProfileId = profiles[selectedIndex].id;
      }
    });
    _syncControllers();
  }

  String _uniqueId(String seed) {
    final safe = seed
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final prefix = safe.isEmpty ? 'editor' : safe;
    var candidate = '$prefix-${DateTime.now().microsecondsSinceEpoch}';
    var suffix = 2;
    final ids = profiles.map((profile) => profile.id).toSet();
    while (ids.contains(candidate)) {
      candidate = '$prefix-${DateTime.now().microsecondsSinceEpoch}-$suffix';
      suffix += 1;
    }
    return candidate;
  }

  String _uniqueName(String base) {
    final names = profiles.map((profile) => profile.name).toSet();
    if (!names.contains(base)) return base;
    var index = 2;
    while (names.contains('$base $index')) {
      index += 1;
    }
    return '$base $index';
  }

  void _save() {
    final normalized = NoteEditorPreferences.normalized(
      activeProfileId: activeProfileId,
      profiles: profiles,
    );
    Navigator.pop(context, normalized);
  }
}
