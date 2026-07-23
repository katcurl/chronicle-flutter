import 'package:flutter/material.dart';

import 'note_home_preferences.dart';

class NoteHomePreferencesDialog extends StatefulWidget {
  const NoteHomePreferencesDialog({
    super.key,
    required this.initialValue,
  });

  final NoteHomePreferences initialValue;

  static Future<NoteHomePreferences?> show(
    BuildContext context, {
    required NoteHomePreferences initialValue,
  }) {
    return showDialog<NoteHomePreferences>(
      context: context,
      builder: (_) => NoteHomePreferencesDialog(initialValue: initialValue),
    );
  }

  @override
  State<NoteHomePreferencesDialog> createState() =>
      _NoteHomePreferencesDialogState();
}

class _NoteHomePreferencesDialogState
    extends State<NoteHomePreferencesDialog> {
  late List<NoteHomeSection> sections;
  late Set<String> hiddenSectionIds;
  late int itemLimit;
  late bool compactCards;
  late bool openOnHome;

  @override
  void initState() {
    super.initState();
    sections = List<NoteHomeSection>.from(widget.initialValue.orderedSections);
    hiddenSectionIds = Set<String>.from(
      widget.initialValue.hiddenSectionIds,
    );
    itemLimit = widget.initialValue.itemLimit;
    compactCards = widget.initialValue.compactCards;
    openOnHome = widget.initialValue.openOnHome;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final availableHeight = MediaQuery.sizeOf(context).height - 180;
    final dialogHeight = availableHeight.clamp(360.0, 620.0).toDouble();
    return AlertDialog(
      title: const Text('Стартовая страница заметок'),
      content: SizedBox(
        width: 680,
        height: dialogHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Секции хранятся только в локальных настройках интерфейса. '
              'Перетаскивайте их, скрывайте лишнее и задавайте плотность обзора.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Открывать заметки с обзора'),
              subtitle: const Text(
                'Библиотека со всеми фильтрами остаётся доступна одной кнопкой.',
              ),
              value: openOnHome,
              onChanged: (value) => setState(() => openOnHome = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Компактные карточки'),
              subtitle: const Text(
                'Показывать больше элементов на небольшом экране.',
              ),
              value: compactCards,
              onChanged: (value) => setState(() => compactCards = value),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(child: Text('Элементов в каждой секции')),
                for (
                  var value = NoteHomePreferences.minItemLimit;
                  value <= NoteHomePreferences.maxItemLimit;
                  value += 2
                ) ...[
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: Text('$value'),
                    selected: itemLimit == value,
                    onSelected: (_) => setState(() => itemLimit = value),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Порядок и видимость секций',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: sections.length,
                  onReorderItem: (oldIndex, newIndex) {
                    setState(() {
                      final section = sections.removeAt(oldIndex);
                      sections.insert(newIndex, section);
                    });
                  },
                  itemBuilder: (_, index) {
                    final section = sections[index];
                    final visible = !hiddenSectionIds.contains(section.id);
                    return ListTile(
                      key: ValueKey(section.id),
                      leading: Switch(
                        value: visible,
                        onChanged: (value) {
                          setState(() {
                            if (value) {
                              hiddenSectionIds.remove(section.id);
                            } else {
                              hiddenSectionIds.add(section.id);
                            }
                          });
                        },
                      ),
                      title: Text(section.label),
                      subtitle: Text(
                        section.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.drag_handle_rounded),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () {
            final defaults = NoteHomePreferences.defaults();
            setState(() {
              sections = List<NoteHomeSection>.from(defaults.orderedSections);
              hiddenSectionIds = <String>{};
              itemLimit = defaults.itemLimit;
              compactCards = defaults.compactCards;
              openOnHome = defaults.openOnHome;
            });
          },
          child: const Text('По умолчанию'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              NoteHomePreferences.normalized(
                sectionIds: sections.map((section) => section.id),
                hiddenSectionIds: hiddenSectionIds,
                itemLimit: itemLimit,
                compactCards: compactCards,
                openOnHome: openOnHome,
              ),
            );
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
