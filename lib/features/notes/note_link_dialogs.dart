import 'package:flutter/material.dart';

import 'note_link_tools.dart';

class NoteLinkPickerResult {
  const NoteLinkPickerResult({
    required this.targets,
    required this.style,
  });

  final List<NoteLinkTarget> targets;
  final NoteLinkInsertStyle style;
}

class NoteLinkPickerDialog extends StatefulWidget {
  const NoteLinkPickerDialog({
    super.key,
    required this.targets,
    required this.sourceProjectTitle,
  });

  final List<NoteLinkTarget> targets;
  final String sourceProjectTitle;

  static Future<NoteLinkPickerResult?> show(
    BuildContext context, {
    required List<NoteLinkTarget> targets,
    required String sourceProjectTitle,
  }) {
    return showDialog<NoteLinkPickerResult>(
      context: context,
      builder: (context) => NoteLinkPickerDialog(
        targets: targets,
        sourceProjectTitle: sourceProjectTitle,
      ),
    );
  }

  @override
  State<NoteLinkPickerDialog> createState() => _NoteLinkPickerDialogState();
}

class _NoteLinkPickerDialogState extends State<NoteLinkPickerDialog> {
  String _query = '';
  bool _sameProjectOnly = false;
  NoteLinkInsertStyle _style = NoteLinkInsertStyle.inline;
  final List<String> _selectedIds = <String>[];

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _query.trim().toLowerCase();
    final sourceProject = widget.sourceProjectTitle.trim().toLowerCase();
    final visible = widget.targets.where((target) {
      if (_sameProjectOnly &&
          target.projectTitle.trim().toLowerCase() != sourceProject) {
        return false;
      }
      return normalizedQuery.isEmpty ||
          target.searchableText.contains(normalizedQuery);
    }).toList();
    visible.sort((left, right) {
      int rank(NoteLinkTarget target) {
        final title = target.title.toLowerCase();
        final prefix = normalizedQuery.isNotEmpty &&
            title.startsWith(normalizedQuery);
        final sameProject = target.projectTitle.trim().toLowerCase() ==
            sourceProject;
        if (sameProject && prefix) return 0;
        if (sameProject) return 1;
        if (prefix) return 2;
        return 3;
      }

      final rankCompare = rank(left).compareTo(rank(right));
      if (rankCompare != 0) return rankCompare;
      final titleCompare = left.title.toLowerCase().compareTo(
        right.title.toLowerCase(),
      );
      if (titleCompare != 0) return titleCompare;
      return left.projectTitle.toLowerCase().compareTo(
        right.projectTitle.toLowerCase(),
      );
    });

    return AlertDialog(
      title: const Text('Вставить устойчивые ссылки'),
      content: SizedBox(
        width: 660,
        height: 590,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Название, проект, папка, тип или тег',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (widget.sourceProjectTitle.trim().isNotEmpty)
                  FilterChip(
                    selected: _sameProjectOnly,
                    label: const Text('Только текущий проект'),
                    onSelected: (value) {
                      setState(() => _sameProjectOnly = value);
                    },
                  ),
                SegmentedButton<NoteLinkInsertStyle>(
                  segments: const [
                    ButtonSegment(
                      value: NoteLinkInsertStyle.inline,
                      icon: Icon(Icons.short_text_rounded),
                      label: Text('В строку'),
                    ),
                    ButtonSegment(
                      value: NoteLinkInsertStyle.bulleted,
                      icon: Icon(Icons.format_list_bulleted_rounded),
                      label: Text('Списком'),
                    ),
                  ],
                  selected: <NoteLinkInsertStyle>{_style},
                  onSelectionChanged: (selection) {
                    setState(() => _style = selection.single);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _selectedIds.isEmpty
                  ? 'Выбери одну или несколько заметок.'
                  : 'Выбрано: ${_selectedIds.length}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Expanded(
              child: visible.isEmpty
                  ? const Center(child: Text('Подходящих заметок не найдено.'))
                  : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final target = visible[index];
                        final selected = _selectedIds.contains(target.id);
                        final location = <String>[
                          target.projectTitle,
                          if (target.folderPath.trim().isNotEmpty)
                            target.folderPath.trim(),
                          if (target.tags.isNotEmpty)
                            target.tags.map((tag) => '#$tag').join(' '),
                        ].where((value) => value.trim().isNotEmpty).join(' · ');
                        return CheckboxListTile(
                          value: selected,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.trailing,
                          secondary: const Icon(Icons.description_outlined),
                          title: Text(target.title),
                          subtitle: location.isEmpty ? null : Text(location),
                          onChanged: (value) => _toggle(target.id, value == true),
                        );
                      },
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
        FilledButton.icon(
          onPressed: _selectedIds.isEmpty ? null : _submit,
          icon: const Icon(Icons.link_rounded),
          label: const Text('Вставить'),
        ),
      ],
    );
  }

  void _toggle(String id, bool selected) {
    setState(() {
      if (selected) {
        if (!_selectedIds.contains(id) && _selectedIds.length < 24) {
          _selectedIds.add(id);
        }
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  void _submit() {
    final byId = <String, NoteLinkTarget>{
      for (final target in widget.targets) target.id: target,
    };
    Navigator.pop(
      context,
      NoteLinkPickerResult(
        targets: <NoteLinkTarget>[
          for (final id in _selectedIds)
            if (byId.containsKey(id)) byId[id]!,
        ],
        style: _style,
      ),
    );
  }
}

class NoteUnlinkedMentionsDialog extends StatefulWidget {
  const NoteUnlinkedMentionsDialog({
    super.key,
    required this.markdown,
    required this.targets,
  });

  final String markdown;
  final List<NoteLinkTarget> targets;

  static Future<List<NoteLinkMention>?> show(
    BuildContext context, {
    required String markdown,
    required List<NoteLinkTarget> targets,
  }) {
    return showDialog<List<NoteLinkMention>>(
      context: context,
      builder: (context) => NoteUnlinkedMentionsDialog(
        markdown: markdown,
        targets: targets,
      ),
    );
  }

  @override
  State<NoteUnlinkedMentionsDialog> createState() =>
      _NoteUnlinkedMentionsDialogState();
}

class _NoteUnlinkedMentionsDialogState
    extends State<NoteUnlinkedMentionsDialog> {
  late final List<NoteLinkMention> _mentions;
  final Set<int> _selectedIndexes = <int>{};

  @override
  void initState() {
    super.initState();
    _mentions = NoteLinkTools.findUnlinkedMentions(
      widget.markdown,
      widget.targets,
    );
    _selectedIndexes.addAll(
      List<int>.generate(_mentions.length, (index) => index),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Непривязанные упоминания'),
      content: SizedBox(
        width: 680,
        height: 540,
        child: _mentions.isEmpty
            ? const Center(
                child: Text(
                  'Названия других заметок вне уже созданных ссылок не найдены.',
                  textAlign: TextAlign.center,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Chronicle заменит выбранные упоминания точными '
                          'ссылками, устойчивыми к переименованию.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            if (_selectedIndexes.length == _mentions.length) {
                              _selectedIndexes.clear();
                            } else {
                              _selectedIndexes
                                ..clear()
                                ..addAll(
                                  List<int>.generate(
                                    _mentions.length,
                                    (index) => index,
                                  ),
                                );
                            }
                          });
                        },
                        child: Text(
                          _selectedIndexes.length == _mentions.length
                              ? 'Снять все'
                              : 'Выбрать все',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _mentions.length,
                      itemBuilder: (context, index) {
                        final mention = _mentions[index];
                        return CheckboxListTile(
                          value: _selectedIndexes.contains(index),
                          dense: true,
                          controlAffinity: ListTileControlAffinity.trailing,
                          secondary: const Icon(Icons.link_outlined),
                          title: Text(mention.target.title),
                          subtitle: Text(
                            mention.snippet,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedIndexes.add(index);
                              } else {
                                _selectedIndexes.remove(index);
                              }
                            });
                          },
                        );
                      },
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
        FilledButton.icon(
          onPressed: _selectedIndexes.isEmpty
              ? null
              : () => Navigator.pop(
                    context,
                    <NoteLinkMention>[
                      for (var index = 0; index < _mentions.length; index += 1)
                        if (_selectedIndexes.contains(index)) _mentions[index],
                    ],
                  ),
          icon: const Icon(Icons.auto_fix_high_rounded),
          label: Text('Связать (${_selectedIndexes.length})'),
        ),
      ],
    );
  }
}
