import 'package:flutter/material.dart';

import 'note_templates.dart';

class CustomNoteTemplateDraft {
  const CustomNoteTemplateDraft({
    required this.title,
    required this.icon,
    required this.noteType,
    required this.content,
    required this.defaultTags,
  });

  final String title;
  final String icon;
  final String noteType;
  final String content;
  final List<String> defaultTags;
}

typedef CustomNoteTemplateCreate =
    Future<NoteTemplate> Function(CustomNoteTemplateDraft draft);
typedef CustomNoteTemplateUpdate =
    Future<NoteTemplate> Function(
      NoteTemplate template,
      CustomNoteTemplateDraft draft,
    );
typedef CustomNoteTemplateDelete =
    Future<void> Function(NoteTemplate template);

class CustomNoteTemplateEditorDialog extends StatefulWidget {
  const CustomNoteTemplateEditorDialog({
    super.key,
    this.template,
    this.initialTitle = '',
    this.initialIcon = '📝',
    this.initialNoteType = 'note',
    this.initialContent = '',
    this.initialTags = const <String>[],
  });

  final NoteTemplate? template;
  final String initialTitle;
  final String initialIcon;
  final String initialNoteType;
  final String initialContent;
  final List<String> initialTags;

  static Future<CustomNoteTemplateDraft?> show(
    BuildContext context, {
    NoteTemplate? template,
    String initialTitle = '',
    String initialIcon = '📝',
    String initialNoteType = 'note',
    String initialContent = '',
    List<String> initialTags = const <String>[],
  }) {
    return showDialog<CustomNoteTemplateDraft>(
      context: context,
      builder:
          (_) => CustomNoteTemplateEditorDialog(
            template: template,
            initialTitle: initialTitle,
            initialIcon: initialIcon,
            initialNoteType: initialNoteType,
            initialContent: initialContent,
            initialTags: initialTags,
          ),
    );
  }

  @override
  State<CustomNoteTemplateEditorDialog> createState() =>
      _CustomNoteTemplateEditorDialogState();
}

class _CustomNoteTemplateEditorDialogState
    extends State<CustomNoteTemplateEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _iconController;
  late final TextEditingController _tagsController;
  late final TextEditingController _contentController;
  late String _noteType;

  bool get _editing => widget.template != null;

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    _titleController = TextEditingController(
      text: template?.title ?? widget.initialTitle,
    );
    _iconController = TextEditingController(
      text: template?.icon ?? widget.initialIcon,
    );
    _tagsController = TextEditingController(
      text: (template?.defaultTags ?? widget.initialTags).join(', '),
    );
    _contentController = TextEditingController(
      text: template?.content ?? widget.initialContent,
    );
    final initialType = template?.noteType ?? widget.initialNoteType;
    _noteType = _knownNoteTypes.contains(initialType) ? initialType : 'note';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _iconController.dispose();
    _tagsController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final width = (mediaSize.width - 48).clamp(360.0, 760.0).toDouble();
    final height = (mediaSize.height - 48).clamp(480.0, 760.0).toDouble();

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        height: height,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
                child: Row(
                  children: [
                    const Icon(Icons.dashboard_customize_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _editing ? 'Редактировать шаблон' : 'Новый шаблон',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Закрыть',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 92,
                            child: TextFormField(
                              controller: _iconController,
                              decoration: const InputDecoration(
                                labelText: 'Значок',
                                hintText: '📝',
                              ),
                              validator: (value) {
                                final icon = value?.trim() ?? '';
                                if (icon.isEmpty) return 'Укажи значок';
                                if (icon.length > 16) return 'Слишком длинный';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _titleController,
                              autofocus: true,
                              maxLength: 120,
                              decoration: const InputDecoration(
                                labelText: 'Название шаблона',
                                hintText: 'Например: Подготовка образца',
                              ),
                              validator:
                                  (value) =>
                                      (value?.trim().isEmpty ?? true)
                                          ? 'Укажи название'
                                          : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _knownNoteTypes.contains(_noteType)
                            ? _noteType
                            : 'note',
                        decoration: const InputDecoration(
                          labelText: 'Тип новой заметки',
                        ),
                        items: [
                          for (final type in _knownNoteTypes)
                            DropdownMenuItem<String>(
                              value: type,
                              child: Text(
                                '${noteTypeIcon(type)}  ${noteTypeLabel(type)}',
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) _noteType = value;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _tagsController,
                        decoration: const InputDecoration(
                          labelText: 'Теги по умолчанию',
                          hintText: 'лаборатория, протокол, белок',
                          helperText: 'Разделяй теги запятыми.',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Markdown шаблона',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 300,
                        child: TextFormField(
                          controller: _contentController,
                          expands: true,
                          maxLines: null,
                          minLines: null,
                          textAlignVertical: TextAlignVertical.top,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                            height: 1.5,
                          ),
                          decoration: const InputDecoration(
                            alignLabelWithHint: true,
                            hintText: '# Заголовок\n\n## Раздел',
                          ),
                          validator:
                              (value) =>
                                  (value?.trim().isEmpty ?? true)
                                      ? 'Добавь содержимое шаблона'
                                      : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Пользовательский шаблон хранится локально в настройках '
                        'Chronicle. Встроенные шаблоны не изменяются.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(_editing ? 'Сохранить' : 'Создать'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final tags = <String>[];
    final seen = <String>{};
    for (final rawTag in _tagsController.text.split(',')) {
      final tag = rawTag.trim();
      if (tag.isNotEmpty && seen.add(tag.toLowerCase())) {
        tags.add(tag);
      }
    }
    Navigator.pop(
      context,
      CustomNoteTemplateDraft(
        title: _titleController.text.trim(),
        icon: _iconController.text.trim(),
        noteType: _noteType,
        content: _contentController.text,
        defaultTags: tags,
      ),
    );
  }
}

class CustomNoteTemplateManagerDialog extends StatefulWidget {
  const CustomNoteTemplateManagerDialog({
    super.key,
    required this.templates,
    required this.onCreate,
    required this.onUpdate,
    required this.onDelete,
  });

  final List<NoteTemplate> templates;
  final CustomNoteTemplateCreate onCreate;
  final CustomNoteTemplateUpdate onUpdate;
  final CustomNoteTemplateDelete onDelete;

  static Future<void> show(
    BuildContext context, {
    required List<NoteTemplate> templates,
    required CustomNoteTemplateCreate onCreate,
    required CustomNoteTemplateUpdate onUpdate,
    required CustomNoteTemplateDelete onDelete,
  }) async {
    await showDialog<void>(
      context: context,
      builder:
          (_) => CustomNoteTemplateManagerDialog(
            templates: templates,
            onCreate: onCreate,
            onUpdate: onUpdate,
            onDelete: onDelete,
          ),
    );
  }

  @override
  State<CustomNoteTemplateManagerDialog> createState() =>
      _CustomNoteTemplateManagerDialogState();
}

class _CustomNoteTemplateManagerDialogState
    extends State<CustomNoteTemplateManagerDialog> {
  late List<NoteTemplate> _templates;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _templates = List<NoteTemplate>.from(widget.templates);
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final width = (mediaSize.width - 48).clamp(360.0, 720.0).toDouble();
    final height = (mediaSize.height - 48).clamp(420.0, 680.0).toDouble();

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
              child: Row(
                children: [
                  const Icon(Icons.dashboard_customize_outlined),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Мои шаблоны',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _busy ? null : _create,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Создать'),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Закрыть',
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child:
                  _templates.isEmpty
                      ? const _EmptyCustomTemplates()
                      : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _templates.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final template = _templates[index];
                          return Card(
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              leading: Text(
                                template.icon,
                                style: const TextStyle(fontSize: 26),
                              ),
                              title: Text(template.title),
                              subtitle: Text(
                                '${noteTypeLabel(template.noteType)} · '
                                '${template.defaultTags.length} тегов',
                              ),
                              onTap: _busy ? null : () => _edit(template),
                              trailing: PopupMenuButton<String>(
                                enabled: !_busy,
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _edit(template);
                                  } else if (value == 'delete') {
                                    _delete(template);
                                  }
                                },
                                itemBuilder:
                                    (_) => const [
                                      PopupMenuItem<String>(
                                        value: 'edit',
                                        child: ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: Icon(Icons.edit_outlined),
                                          title: Text('Редактировать'),
                                        ),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'delete',
                                        child: ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: Icon(
                                            Icons.delete_outline_rounded,
                                          ),
                                          title: Text('Удалить'),
                                        ),
                                      ),
                                    ],
                              ),
                            ),
                          );
                        },
                      ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Встроенные шаблоны остаются доступными отдельно и не '
                      'могут быть удалены.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Готово'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _create() async {
    final draft = await CustomNoteTemplateEditorDialog.show(context);
    if (draft == null || !mounted) return;
    await _run(() async {
      final created = await widget.onCreate(draft);
      _templates.add(created);
    });
  }

  Future<void> _edit(NoteTemplate template) async {
    final draft = await CustomNoteTemplateEditorDialog.show(
      context,
      template: template,
    );
    if (draft == null || !mounted) return;
    await _run(() async {
      final updated = await widget.onUpdate(template, draft);
      final index = _templates.indexWhere((item) => item.id == template.id);
      if (index >= 0) _templates[index] = updated;
    });
  }

  Future<void> _delete(NoteTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Удалить пользовательский шаблон?'),
            content: Text(
              'Шаблон «${template.title}» исчезнет из списков. Уже созданные '
              'заметки не изменятся.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await widget.onDelete(template);
      _templates.removeWhere((item) => item.id == template.id);
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) setState(() {});
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить шаблон: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _EmptyCustomTemplates extends StatelessWidget {
  const _EmptyCustomTemplates();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.dashboard_customize_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              'Пока нет своих шаблонов',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Создай шаблон вручную или сохрани как шаблон открытую заметку.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

const _knownNoteTypes = <String>[
  'note',
  'lecture',
  'research',
  'literature',
  'meeting',
  'lab_day',
  'experiment',
  'sample',
  'protein_purification',
  'nmr_experiment',
  'solution',
];
