part of 'notes_screen.dart';

class _NotePropertiesSheet extends StatefulWidget {
  const _NotePropertiesSheet({required this.projects, required this.metadata});

  final List<Project> projects;
  final _NoteMetadata metadata;

  static Future<_NoteMetadata?> show(
    BuildContext context, {
    required List<Project> projects,
    required _NoteMetadata metadata,
  }) {
    return showModalBottomSheet<_NoteMetadata>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 700),
      builder:
          (_) => _NotePropertiesSheet(projects: projects, metadata: metadata),
    );
  }

  @override
  State<_NotePropertiesSheet> createState() => _NotePropertiesSheetState();
}

class _NotePropertiesSheetState extends State<_NotePropertiesSheet> {
  late String projectId;
  late String status;
  late String noteType;
  late bool pinned;
  late final TextEditingController folderController;
  late final TextEditingController tagsController;
  late final TextEditingController propertiesController;

  @override
  void initState() {
    super.initState();
    projectId = widget.metadata.projectId;
    status = widget.metadata.status;
    noteType = widget.metadata.noteType;
    pinned = widget.metadata.pinned;
    folderController = TextEditingController(text: widget.metadata.folderPath);
    tagsController = TextEditingController(
      text: widget.metadata.tags.join(', '),
    );
    propertiesController = TextEditingController(
      text: widget.metadata.properties.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('\n'),
    );
  }

  @override
  void dispose() {
    folderController.dispose();
    tagsController.dispose();
    propertiesController.dispose();
    super.dispose();
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
                'Свойства заметки',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: projectId,
                decoration: const InputDecoration(labelText: 'Проект'),
                items:
                    widget.projects
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
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: noteType,
                      decoration: const InputDecoration(labelText: 'Тип'),
                      items: const [
                        DropdownMenuItem(value: 'note', child: Text('Заметка')),
                        DropdownMenuItem(
                          value: 'lecture',
                          child: Text('Лекция'),
                        ),
                        DropdownMenuItem(
                          value: 'research',
                          child: Text('Исследование'),
                        ),
                        DropdownMenuItem(
                          value: 'literature',
                          child: Text('Источник'),
                        ),
                        DropdownMenuItem(
                          value: 'meeting',
                          child: Text('Встреча'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => noteType = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Статус'),
                      items: const [
                        DropdownMenuItem(
                          value: 'draft',
                          child: Text('Черновик'),
                        ),
                        DropdownMenuItem(
                          value: 'review',
                          child: Text('Проверка'),
                        ),
                        DropdownMenuItem(value: 'ready', child: Text('Готово')),
                        DropdownMenuItem(
                          value: 'archived',
                          child: Text('Архив'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => status = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: folderController,
                decoration: const InputDecoration(
                  labelText: 'Папка',
                  hintText: 'Лекции/Химия',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tagsController,
                decoration: const InputDecoration(
                  labelText: 'Теги через запятую',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: propertiesController,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Дополнительные YAML-свойства',
                  hintText: 'audience=8 класс\ndoi=10.1000/example',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: pinned,
                title: const Text('Закрепить заметку'),
                onChanged: (value) => setState(() => pinned = value),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Применить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    final properties = <String, String>{};
    for (final rawLine in propertiesController.text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final separator = line.indexOf('=');
      if (separator <= 0) continue;
      properties[line.substring(0, separator).trim()] =
          line.substring(separator + 1).trim();
    }
    Navigator.pop(
      context,
      _NoteMetadata(
        projectId: projectId,
        status: status,
        folderPath: folderController.text.trim(),
        noteType: noteType,
        tags: NoteDocument.parseTags(tagsController.text),
        properties: properties,
        pinned: pinned,
      ),
    );
  }
}

class _NoteMetadata {
  const _NoteMetadata({
    required this.projectId,
    required this.status,
    required this.folderPath,
    required this.noteType,
    required this.tags,
    required this.properties,
    required this.pinned,
  });

  final String projectId;
  final String status;
  final String folderPath;
  final String noteType;
  final List<String> tags;
  final Map<String, String> properties;
  final bool pinned;
}
