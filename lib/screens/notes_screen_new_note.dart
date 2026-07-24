part of 'notes_screen.dart';

class _NewNoteSheet extends StatefulWidget {
  const _NewNoteSheet({required this.store, this.initialTemplateId});

  final AppStore store;
  final String? initialTemplateId;

  static Future<_NewNoteRequest?> show(
    BuildContext context, {
    required AppStore store,
    String? initialTemplateId,
  }) {
    return showModalBottomSheet<_NewNoteRequest>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 700),
      builder:
          (_) =>
              _NewNoteSheet(store: store, initialTemplateId: initialTemplateId),
    );
  }

  @override
  State<_NewNoteSheet> createState() => _NewNoteSheetState();
}

class _NewNoteSheetState extends State<_NewNoteSheet> {
  late String projectId;
  String templateId = 'blank';
  final titleController = TextEditingController();
  final folderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    projectId = widget.store.activeProjects.first.id;
    final requestedTemplateId = widget.initialTemplateId;
    if (requestedTemplateId != null &&
        widget.store.availableNoteTemplates.any(
          (template) => template.id == requestedTemplateId,
        )) {
      templateId = requestedTemplateId;
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    folderController.dispose();
    super.dispose();
  }

  Future<void> _manageTemplates() async {
    await _showCustomNoteTemplateManager(context, widget.store);
    if (!mounted) return;
    final availableIds =
        widget.store.availableNoteTemplates
            .map((template) => template.id)
            .toSet();
    setState(() {
      if (!availableIds.contains(templateId)) templateId = 'blank';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Новая заметка',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: projectId,
                decoration: const InputDecoration(labelText: 'Проект'),
                items:
                    widget.store.activeProjects
                        .map(
                          (project) => DropdownMenuItem(
                            value: project.id,
                            child: Text('${project.emoji} ${project.title}'),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => projectId = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: folderController,
                decoration: const InputDecoration(
                  labelText: 'Папка',
                  hintText: 'Например: Лекции/Химия',
                ),
              ),
              if (widget.store.applicableNoteTemplates.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Шаблон',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      avatar: const Text('📝'),
                      label: const Text('Пустая заметка'),
                      selected: templateId == 'blank',
                      onSelected: (_) => setState(() => templateId = 'blank'),
                    ),
                    for (final template in widget.store.applicableNoteTemplates)
                      ChoiceChip(
                        avatar: Text(template.icon),
                        label: Text(template.title),
                        selected: templateId == template.id,
                        onSelected:
                            (_) => setState(() => templateId = template.id),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _manageTemplates,
                icon: const Icon(Icons.dashboard_customize_outlined),
                label: Text(
                  widget.store.applicableNoteTemplates.isEmpty
                      ? 'Создать свой шаблон'
                      : 'Мои шаблоны',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      () => Navigator.pop(
                        context,
                        _NewNoteRequest(
                          projectId: projectId,
                          templateId: templateId,
                          title: titleController.text,
                          folderPath: folderController.text,
                        ),
                      ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Создать'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewNoteRequest {
  const _NewNoteRequest({
    required this.projectId,
    required this.templateId,
    required this.title,
    required this.folderPath,
  });

  final String projectId;
  final String templateId;
  final String title;
  final String folderPath;
}

class _EmptyNotes extends StatelessWidget {
  const _EmptyNotes({required this.hasFilters});

  final bool hasFilters;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_outlined, size: 54),
            const SizedBox(height: 12),
            Text(
              hasFilters ? 'Ничего не найдено' : 'Заметок пока нет',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              hasFilters
                  ? 'Измени поиск или фильтры.'
                  : 'Создай лекцию, конспект или исследовательскую запись.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
