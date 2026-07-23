import 'package:flutter/material.dart';

import 'custom_note_template_file_service.dart';
import 'custom_note_template_library.dart';
import 'note_templates.dart';

class CustomNoteTemplateDraft {
  const CustomNoteTemplateDraft({
    required this.title,
    required this.icon,
    required this.category,
    required this.noteType,
    required this.content,
    required this.defaultTags,
  });

  final String title;
  final String icon;
  final String category;
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
typedef CustomNoteTemplateDelete = Future<void> Function(NoteTemplate template);
typedef CustomNoteTemplateDuplicate =
    Future<NoteTemplate> Function(NoteTemplate template);
typedef CustomNoteTemplateImport =
    Future<List<NoteTemplate>> Function(List<NoteTemplate> templates);

class CustomNoteTemplateEditorDialog extends StatefulWidget {
  const CustomNoteTemplateEditorDialog({
    super.key,
    this.template,
    this.initialTitle = '',
    this.initialIcon = '📝',
    this.initialCategory = '',
    this.initialNoteType = 'note',
    this.initialContent = '',
    this.initialTags = const <String>[],
  });

  final NoteTemplate? template;
  final String initialTitle;
  final String initialIcon;
  final String initialCategory;
  final String initialNoteType;
  final String initialContent;
  final List<String> initialTags;

  static Future<CustomNoteTemplateDraft?> show(
    BuildContext context, {
    NoteTemplate? template,
    String initialTitle = '',
    String initialIcon = '📝',
    String initialCategory = '',
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
            initialCategory: initialCategory,
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
  late final TextEditingController _categoryController;
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
    _categoryController = TextEditingController(
      text: template?.category ?? widget.initialCategory,
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
    _categoryController.dispose();
    _tagsController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final width = (mediaSize.width - 48).clamp(360.0, 760.0).toDouble();
    final height = (mediaSize.height - 48).clamp(480.0, 780.0).toDouble();

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
                      TextFormField(
                        controller: _categoryController,
                        maxLength: 80,
                        decoration: const InputDecoration(
                          labelText: 'Категория',
                          hintText: 'Например: Лаборатория или Учёба',
                          helperText:
                              'Пустая категория попадёт в раздел «Без категории».',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue:
                            _knownNoteTypes.contains(_noteType)
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
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
        category: _categoryController.text.trim(),
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
    required this.onDuplicate,
    required this.onImport,
    this.fileService = const CustomNoteTemplateFileService(),
  });

  final List<NoteTemplate> templates;
  final CustomNoteTemplateCreate onCreate;
  final CustomNoteTemplateUpdate onUpdate;
  final CustomNoteTemplateDelete onDelete;
  final CustomNoteTemplateDuplicate onDuplicate;
  final CustomNoteTemplateImport onImport;
  final CustomNoteTemplateFileService fileService;

  static Future<void> show(
    BuildContext context, {
    required List<NoteTemplate> templates,
    required CustomNoteTemplateCreate onCreate,
    required CustomNoteTemplateUpdate onUpdate,
    required CustomNoteTemplateDelete onDelete,
    required CustomNoteTemplateDuplicate onDuplicate,
    required CustomNoteTemplateImport onImport,
  }) async {
    await showDialog<void>(
      context: context,
      builder:
          (_) => CustomNoteTemplateManagerDialog(
            templates: templates,
            onCreate: onCreate,
            onUpdate: onUpdate,
            onDelete: onDelete,
            onDuplicate: onDuplicate,
            onImport: onImport,
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
  final _searchController = TextEditingController();
  String _categoryFilter = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _templates = List<NoteTemplate>.from(widget.templates);
    _searchController.addListener(_searchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_searchChanged)
      ..dispose();
    super.dispose();
  }

  void _searchChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final width = (mediaSize.width - 48).clamp(360.0, 920.0).toDouble();
    final height = (mediaSize.height - 48).clamp(480.0, 780.0).toDouble();
    final categories = CustomNoteTemplateLibrary.categories(_templates);
    final effectiveCategoryFilter =
        _categoryFilter.isEmpty || categories.contains(_categoryFilter)
            ? _categoryFilter
            : '';
    final filtered = CustomNoteTemplateLibrary.filter(
      _templates,
      query: _searchController.text,
      category: effectiveCategoryFilter,
    );

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
                      'Библиотека шаблонов',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Импорт и экспорт',
                    enabled: !_busy,
                    icon: const Icon(Icons.import_export_rounded),
                    onSelected: (value) {
                      if (value == 'import') {
                        _import();
                      } else if (value == 'export') {
                        _exportAll();
                      }
                    },
                    itemBuilder:
                        (_) => [
                          const PopupMenuItem<String>(
                            value: 'import',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.file_download_outlined),
                              title: Text('Импортировать JSON'),
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'export',
                            enabled: _templates.isNotEmpty,
                            child: const ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.file_upload_outlined),
                              title: Text('Экспортировать все'),
                            ),
                          ),
                        ],
                  ),
                  const SizedBox(width: 4),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final searchField = TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search_rounded),
                      labelText: 'Поиск по шаблонам',
                      suffixIcon:
                          _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                tooltip: 'Очистить поиск',
                                onPressed: _searchController.clear,
                                icon: const Icon(Icons.clear_rounded),
                              ),
                    ),
                  );
                  final categoryPicker = DropdownButton<String>(
                    value: effectiveCategoryFilter,
                    onChanged:
                        _busy
                            ? null
                            : (value) =>
                                setState(() => _categoryFilter = value ?? ''),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('Все категории'),
                      ),
                      for (final category in categories)
                        DropdownMenuItem<String>(
                          value: category,
                          child: Text(
                            category ==
                                    CustomNoteTemplateLibrary.uncategorizedKey
                                ? CustomNoteTemplateLibrary.uncategorizedLabel
                                : category,
                          ),
                        ),
                    ],
                  );
                  if (constraints.maxWidth < 560) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        searchField,
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: categoryPicker,
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: searchField),
                      const SizedBox(width: 12),
                      categoryPicker,
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Найдено: ${filtered.length} из ${_templates.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            Expanded(
              child:
                  _templates.isEmpty
                      ? const _EmptyCustomTemplates()
                      : filtered.isEmpty
                      ? const _EmptyTemplateSearch()
                      : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final template = filtered[index];
                          return Card(
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              leading: Text(
                                template.icon,
                                style: const TextStyle(fontSize: 26),
                              ),
                              title: Text(template.title),
                              subtitle: Text(
                                '${CustomNoteTemplateLibrary.categoryLabel(template)} · '
                                '${noteTypeLabel(template.noteType)} · '
                                '${template.defaultTags.length} тегов',
                              ),
                              onTap: _busy ? null : () => _edit(template),
                              trailing: PopupMenuButton<String>(
                                enabled: !_busy,
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _edit(template);
                                  } else if (value == 'duplicate') {
                                    _duplicate(template);
                                  } else if (value == 'export') {
                                    _exportOne(template);
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
                                        value: 'duplicate',
                                        child: ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: Icon(Icons.copy_outlined),
                                          title: Text('Дублировать'),
                                        ),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'export',
                                        child: ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: Icon(
                                            Icons.file_upload_outlined,
                                          ),
                                          title: Text('Экспортировать'),
                                        ),
                                      ),
                                      PopupMenuDivider(),
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
                      'Импорт добавляет только отсутствующие шаблоны. '
                      'Встроенные шаблоны остаются неизменяемыми.',
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
    }, errorPrefix: 'Не удалось создать шаблон');
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
    }, errorPrefix: 'Не удалось сохранить шаблон');
  }

  Future<void> _duplicate(NoteTemplate template) async {
    await _run(() async {
      final duplicate = await widget.onDuplicate(template);
      _templates.add(duplicate);
      _showMessage('Создан шаблон «${duplicate.title}».');
    }, errorPrefix: 'Не удалось дублировать шаблон');
  }

  Future<void> _import() async {
    await _run(() async {
      final imported = await widget.fileService.importTemplates();
      if (imported == null) return;
      final added = await widget.onImport(imported);
      _templates.addAll(added);
      _showMessage(
        added.isEmpty
            ? 'Новых шаблонов нет: точные копии уже находятся в библиотеке.'
            : 'Импортировано шаблонов: ${added.length}.',
      );
    }, errorPrefix: 'Не удалось импортировать шаблоны');
  }

  Future<void> _exportAll() async {
    await _exportTemplates(_templates, 'Все шаблоны экспортированы.');
  }

  Future<void> _exportOne(NoteTemplate template) async {
    await _exportTemplates(<NoteTemplate>[
      template,
    ], 'Шаблон «${template.title}» экспортирован.');
  }

  Future<void> _exportTemplates(
    List<NoteTemplate> templates,
    String successMessage,
  ) async {
    await _run(() async {
      final path = await widget.fileService.exportTemplates(templates);
      if (path != null) _showMessage(successMessage);
    }, errorPrefix: 'Не удалось экспортировать шаблоны');
  }

  Future<void> _delete(NoteTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Удалить пользовательский шаблон?'),
            content: Text(
              'Шаблон «${template.title}» исчезнет из библиотеки. Уже созданные '
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
    }, errorPrefix: 'Не удалось удалить шаблон');
  }

  Future<void> _run(
    Future<void> Function() action, {
    required String errorPrefix,
  }) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) setState(() {});
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('$errorPrefix: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Создай шаблон вручную, импортируй библиотеку или сохрани как '
              'шаблон открытую заметку.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTemplateSearch extends StatelessWidget {
  const _EmptyTemplateSearch();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'По этому запросу шаблонов не найдено.',
          textAlign: TextAlign.center,
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
