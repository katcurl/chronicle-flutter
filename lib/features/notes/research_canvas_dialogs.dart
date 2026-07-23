import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import 'research_canvas_models.dart';

class ResearchCanvasBoardDraft {
  const ResearchCanvasBoardDraft({
    required this.name,
    required this.emoji,
    required this.projectId,
  });

  final String name;
  final String emoji;
  final String? projectId;
}

class ResearchCanvasBoardDialog extends StatefulWidget {
  const ResearchCanvasBoardDialog({
    super.key,
    required this.projects,
    this.initial,
  });

  final List<Project> projects;
  final ResearchCanvas? initial;

  static Future<ResearchCanvasBoardDraft?> show(
    BuildContext context, {
    required List<Project> projects,
    ResearchCanvas? initial,
  }) {
    return showDialog<ResearchCanvasBoardDraft>(
      context: context,
      builder:
          (context) =>
              ResearchCanvasBoardDialog(projects: projects, initial: initial),
    );
  }

  @override
  State<ResearchCanvasBoardDialog> createState() =>
      _ResearchCanvasBoardDialogState();
}

class _ResearchCanvasBoardDialogState extends State<ResearchCanvasBoardDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _emojiController;
  String? _projectId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initial?.name ?? 'Исследование',
    );
    _emojiController = TextEditingController(
      text: widget.initial?.emoji ?? '🧭',
    );
    _projectId = widget.initial?.projectId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Новая карта' : 'Настроить карту'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 86,
                  child: TextField(
                    controller: _emojiController,
                    maxLength: 8,
                    decoration: const InputDecoration(
                      labelText: 'Значок',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    autofocus: true,
                    maxLength: 64,
                    decoration: const InputDecoration(
                      labelText: 'Название карты',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: _projectId,
              decoration: const InputDecoration(
                labelText: 'Проект по умолчанию',
                helperText:
                    'Используется как фильтр в окне добавления заметок.',
              ),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Все проекты'),
                ),
                for (final project in widget.projects)
                  DropdownMenuItem<String?>(
                    value: project.id,
                    child: Text('${project.emoji} ${project.title}'),
                  ),
              ],
              onChanged: (value) => setState(() => _projectId = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Сохранить')),
      ],
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      ResearchCanvasBoardDraft(
        name: name,
        emoji:
            _emojiController.text.trim().isEmpty
                ? '🧭'
                : _emojiController.text.trim(),
        projectId: _projectId,
      ),
    );
  }
}

class ResearchCanvasItemDraft {
  const ResearchCanvasItemDraft({
    required this.title,
    required this.body,
    required this.colorValue,
  });

  final String title;
  final String body;
  final int colorValue;
}

class ResearchCanvasItemDialog extends StatefulWidget {
  const ResearchCanvasItemDialog({super.key, required this.type, this.initial});

  final ResearchCanvasItemType type;
  final ResearchCanvasItem? initial;

  static Future<ResearchCanvasItemDraft?> show(
    BuildContext context, {
    required ResearchCanvasItemType type,
    ResearchCanvasItem? initial,
  }) {
    return showDialog<ResearchCanvasItemDraft>(
      context: context,
      builder:
          (context) => ResearchCanvasItemDialog(type: type, initial: initial),
    );
  }

  @override
  State<ResearchCanvasItemDialog> createState() =>
      _ResearchCanvasItemDialogState();
}

class _ResearchCanvasItemDialogState extends State<ResearchCanvasItemDialog> {
  static const List<int> _colors = <int>[
    0xFF6750A4,
    0xFF006A6A,
    0xFF7D5260,
    0xFF386A20,
    0xFF8C5000,
    0xFF455A64,
  ];

  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late int _colorValue;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text:
          widget.initial?.title ??
          (widget.type == ResearchCanvasItemType.group
              ? 'Смысловая область'
              : 'Гипотеза'),
    );
    _bodyController = TextEditingController(text: widget.initial?.body ?? '');
    _colorValue = widget.initial?.colorValue ?? _colors.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGroup = widget.type == ResearchCanvasItemType.group;
    return AlertDialog(
      title: Text(
        widget.initial == null
            ? (isGroup ? 'Новая область' : 'Новая текстовая карточка')
            : (isGroup ? 'Изменить область' : 'Изменить карточку'),
      ),
      content: SizedBox(
        width: 580,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Заголовок'),
            ),
            TextField(
              controller: _bodyController,
              minLines: isGroup ? 2 : 4,
              maxLines: isGroup ? 5 : 10,
              maxLength: 4000,
              decoration: InputDecoration(
                labelText: isGroup ? 'Описание области' : 'Текст',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            Text('Цвет', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              children: [
                for (final value in _colors)
                  ChoiceChip(
                    selected: _colorValue == value,
                    label: const SizedBox(width: 18, height: 18),
                    avatar: CircleAvatar(backgroundColor: Color(value)),
                    onSelected: (_) => setState(() => _colorValue = value),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Сохранить')),
      ],
    );
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(
      context,
      ResearchCanvasItemDraft(
        title: title,
        body: _bodyController.text.trim(),
        colorValue: _colorValue,
      ),
    );
  }
}

class ResearchCanvasNotePickerDialog extends StatefulWidget {
  const ResearchCanvasNotePickerDialog({
    super.key,
    required this.notes,
    required this.projects,
    required this.excludedNoteIds,
    this.initialProjectId,
  });

  final List<Note> notes;
  final List<Project> projects;
  final Set<String> excludedNoteIds;
  final String? initialProjectId;

  static Future<List<Note>?> show(
    BuildContext context, {
    required List<Note> notes,
    required List<Project> projects,
    required Set<String> excludedNoteIds,
    String? initialProjectId,
  }) {
    return showDialog<List<Note>>(
      context: context,
      builder:
          (context) => ResearchCanvasNotePickerDialog(
            notes: notes,
            projects: projects,
            excludedNoteIds: excludedNoteIds,
            initialProjectId: initialProjectId,
          ),
    );
  }

  @override
  State<ResearchCanvasNotePickerDialog> createState() =>
      _ResearchCanvasNotePickerDialogState();
}

class _ResearchCanvasNotePickerDialogState
    extends State<ResearchCanvasNotePickerDialog> {
  String _query = '';
  String? _projectId;
  final Set<String> _selectedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _projectId = widget.initialProjectId;
  }

  @override
  Widget build(BuildContext context) {
    final projectsById = <String, Project>{
      for (final project in widget.projects) project.id: project,
    };
    final normalized = _query.trim().toLowerCase();
    final visible =
        widget.notes.where((note) {
            if (widget.excludedNoteIds.contains(note.id)) return false;
            if (_projectId != null && note.projectId != _projectId) {
              return false;
            }
            if (normalized.isEmpty) return true;
            final project = projectsById[note.projectId];
            return note.title.toLowerCase().contains(normalized) ||
                note.folderPath.toLowerCase().contains(normalized) ||
                note.noteType.toLowerCase().contains(normalized) ||
                note.tags.any(
                  (tag) => tag.toLowerCase().contains(normalized),
                ) ||
                (project?.title.toLowerCase().contains(normalized) ?? false);
          }).toList()
          ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));

    return AlertDialog(
      title: const Text('Добавить заметки на карту'),
      content: SizedBox(
        width: 700,
        height: 600,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Название, проект, папка, тип или тег',
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _projectId,
                    decoration: const InputDecoration(labelText: 'Проект'),
                    items: <DropdownMenuItem<String?>>[
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Все проекты'),
                      ),
                      for (final project in widget.projects)
                        DropdownMenuItem<String?>(
                          value: project.id,
                          child: Text('${project.emoji} ${project.title}'),
                        ),
                    ],
                    onChanged: (value) => setState(() => _projectId = value),
                  ),
                ),
                const SizedBox(width: 14),
                Text('Выбрано: ${_selectedIds.length}'),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child:
                  visible.isEmpty
                      ? const Center(child: Text('Подходящих заметок нет.'))
                      : ListView.builder(
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final note = visible[index];
                          final project = projectsById[note.projectId];
                          return CheckboxListTile(
                            dense: true,
                            value: _selectedIds.contains(note.id),
                            title: Text(note.title),
                            subtitle: Text(
                              <String>[
                                if (project != null)
                                  '${project.emoji} ${project.title}',
                                if (note.folderPath.trim().isNotEmpty)
                                  note.folderPath.trim(),
                                if (note.tags.isNotEmpty)
                                  note.tags.map((tag) => '#$tag').join(' '),
                              ].join(' · '),
                            ),
                            secondary: const Icon(Icons.description_outlined),
                            onChanged: (selected) {
                              setState(() {
                                if (selected == true &&
                                    _selectedIds.length < 24) {
                                  _selectedIds.add(note.id);
                                } else {
                                  _selectedIds.remove(note.id);
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
          onPressed:
              _selectedIds.isEmpty
                  ? null
                  : () {
                    final selected = <Note>[
                      for (final note in widget.notes)
                        if (_selectedIds.contains(note.id)) note,
                    ];
                    Navigator.pop(context, selected);
                  },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Добавить'),
        ),
      ],
    );
  }
}
