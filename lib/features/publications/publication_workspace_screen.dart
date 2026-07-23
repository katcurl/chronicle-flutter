import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:uuid/uuid.dart';

import '../../models/app_models.dart';
import '../../services/app_store.dart';
import '../notes/note_document.dart';
import '../notes/note_export.dart';
import '../notes/note_export_dialog.dart';
import '../notes/note_export_file_service.dart';
import 'publication_workspace.dart';

class PublicationWorkspaceScreen extends StatefulWidget {
  const PublicationWorkspaceScreen({
    super.key,
    required this.store,
    required this.project,
    this.publication,
    this.readOnly = false,
  });

  final AppStore store;
  final Project project;
  final Note? publication;
  final bool readOnly;

  static Future<bool?> show(
    BuildContext context, {
    required AppStore store,
    required Project project,
    Note? publication,
    bool readOnly = false,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PublicationWorkspaceScreen(
          store: store,
          project: project,
          publication: publication,
          readOnly: readOnly,
        ),
      ),
    );
  }

  @override
  State<PublicationWorkspaceScreen> createState() =>
      _PublicationWorkspaceScreenState();
}

class _PublicationWorkspaceScreenState
    extends State<PublicationWorkspaceScreen> {
  static const Uuid _uuid = Uuid();

  late final TextEditingController _titleController;
  late PublicationWorkspace _workspace;
  Note? _publication;

  @override
  void initState() {
    super.initState();
    _publication = widget.publication;
    _titleController = TextEditingController(
      text: widget.publication?.title ?? '${widget.project.title} — отчёт',
    );
    _workspace = widget.publication == null
        ? PublicationWorkspaceTemplates.create(
            PublicationKind.report,
            idFactory: _uuid.v4,
          )
        : PublicationWorkspaceCodec.read(
            widget.publication!,
            idFactory: _uuid.v4,
          );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  List<Note> get _sourceNotes {
    final notes = widget.store.data.notes
        .where(
          (note) =>
              note.projectId == widget.project.id &&
              !PublicationWorkspaceCodec.isPublication(note),
        )
        .toList()
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return notes;
  }

  PublicationAssembly get _assembly => assemblePublication(
        title: _titleController.text,
        workspace: _workspace,
        notes: _sourceNotes,
        sources: widget.store.data.citationSources,
      );

  @override
  Widget build(BuildContext context) {
    final assembly = _assembly;
    final notesById = <String, Note>{
      for (final note in _sourceNotes) note.id: note,
    };
    final issueFragmentIds = <String>{
      for (final issue in assembly.issues) issue.fragmentId,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _publication == null
              ? 'Новый документ'
              : _titleController.text.trim().isEmpty
                  ? 'Документ'
                  : _titleController.text.trim(),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Предпросмотр',
            onPressed: _showPreview,
            icon: const Icon(Icons.visibility_outlined),
          ),
          IconButton(
            tooltip: 'Экспортировать собранный документ',
            onPressed: _export,
            icon: const Icon(Icons.download_outlined),
          ),
          if (!widget.readOnly)
            IconButton(
              tooltip: 'Сохранить',
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1060),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 120),
            children: [
              _DocumentIdentityCard(
                titleController: _titleController,
                workspace: _workspace,
                readOnly: widget.readOnly,
                onTitleChanged: () => setState(() {}),
                onKindChanged: _changeKind,
              ),
              const SizedBox(height: 14),
              _AssemblyMetrics(assembly: assembly),
              if (assembly.issues.isNotEmpty) ...[
                const SizedBox(height: 14),
                _AssemblyIssuesCard(issues: assembly.issues),
              ],
              const SizedBox(height: 14),
              _AssemblySettingsCard(
                workspace: _workspace,
                readOnly: widget.readOnly,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Структура документа',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  if (!widget.readOnly)
                    FilledButton.tonalIcon(
                      onPressed: _addSection,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Раздел'),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Собственный текст хранится здесь. Живые фрагменты остаются '
                'связаны с исходными заметками и обновляются при предпросмотре '
                'или экспорте.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (var index = 0;
                  index < _workspace.sections.length;
                  index += 1) ...[
                _PublicationSectionCard(
                  key: ValueKey<String>(_workspace.sections[index].id),
                  section: _workspace.sections[index],
                  sectionIndex: index,
                  sectionCount: _workspace.sections.length,
                  notesById: notesById,
                  issueFragmentIds: issueFragmentIds,
                  readOnly: widget.readOnly,
                  onChanged: () => setState(() {}),
                  onMoveUp: index == 0
                      ? null
                      : () => _moveSection(index, index - 1),
                  onMoveDown: index == _workspace.sections.length - 1
                      ? null
                      : () => _moveSection(index, index + 1),
                  onDelete: () => _deleteSection(index),
                  onAddFragment: () => _addFragment(index),
                  onMoveFragment: (from, to) =>
                      _moveFragment(index, from, to),
                  onDeleteFragment: (fragmentIndex) =>
                      _deleteFragment(index, fragmentIndex),
                ),
                const SizedBox(height: 12),
              ],
              if (_workspace.sections.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.view_agenda_outlined, size: 42),
                        const SizedBox(height: 10),
                        const Text('В документе пока нет разделов.'),
                        if (!widget.readOnly) ...[
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _addSection,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Добавить первый раздел'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _changeKind(PublicationKind kind) {
    if (widget.readOnly || kind == _workspace.kind) return;
    final hasContent = _workspace.sections.any(
      (section) =>
          section.text.trim().isNotEmpty || section.fragments.isNotEmpty,
    );
    setState(() {
      if (!hasContent) {
        _workspace = PublicationWorkspaceTemplates.create(
          kind,
          idFactory: _uuid.v4,
        );
      } else {
        _workspace.kind = kind;
      }
    });
  }

  void _addSection() {
    setState(() {
      _workspace.sections.add(
        PublicationSection(id: _uuid.v4(), title: 'Новый раздел'),
      );
    });
  }

  void _moveSection(int from, int to) {
    setState(() {
      final section = _workspace.sections.removeAt(from);
      _workspace.sections.insert(to, section);
    });
  }

  Future<void> _deleteSection(int index) async {
    if (widget.readOnly) return;
    final section = _workspace.sections[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить раздел?'),
        content: Text(
          '«${section.title}» и его привязки будут удалены из документа. '
          'Исходные заметки не изменятся.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _workspace.sections.removeAt(index));
  }

  Future<void> _addFragment(int sectionIndex) async {
    if (_sourceNotes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Сначала создай обычную заметку в этом проекте — её можно будет '
            'подключить целиком или по заголовку.',
          ),
        ),
      );
      return;
    }
    final selection = await PublicationFragmentPickerSheet.show(
      context,
      notes: _sourceNotes,
    );
    if (selection == null || !mounted) return;
    setState(() {
      _workspace.sections[sectionIndex].fragments.add(
        PublicationFragment(
          id: _uuid.v4(),
          noteId: selection.note.id,
          heading: selection.heading,
        ),
      );
    });
  }

  void _moveFragment(int sectionIndex, int from, int to) {
    setState(() {
      final fragments = _workspace.sections[sectionIndex].fragments;
      final fragment = fragments.removeAt(from);
      fragments.insert(to, fragment);
    });
  }

  void _deleteFragment(int sectionIndex, int fragmentIndex) {
    setState(() {
      _workspace.sections[sectionIndex].fragments.removeAt(fragmentIndex);
    });
  }

  Future<void> _showPreview() async {
    final assembly = _assembly;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 920,
          height: 720,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Предпросмотр собранного документа',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Закрыть',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (assembly.issues.isNotEmpty)
                MaterialBanner(
                  content: Text(
                    'Не удалось собрать живых фрагментов: '
                    '${assembly.issues.length}. Они отмечены в рабочем пространстве.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Проверить'),
                    ),
                  ],
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 48),
                  child: SelectionArea(
                    child: MarkdownBody(data: assembly.markdown),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _export() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showMessage('Перед экспортом укажи название документа.');
      return;
    }
    final format = await NoteExportDialog.show(
      context,
      subjectLabel: title,
      isProject: false,
    );
    if (format == null || !mounted) return;

    final assembly = _assembly;
    final temporary = Note(
      id: _publication?.id ?? _uuid.v4(),
      title: title,
      projectId: widget.project.id,
      body: '',
      status: 'draft',
      folderPath: 'Публикации и отчёты',
      noteType: _workspace.kind.name,
      properties: const <String, String>{},
    );
    temporary.body = NoteDocument.serialize(temporary, assembly.markdown);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final payload = await NoteExportComposer(
        readAttachment: widget.store.readManagedAttachment,
      ).exportNote(
        note: temporary,
        projectTitle: widget.project.title,
        format: format,
      );
      final savedPath = await const NoteExportFileService().save(payload);
      if (savedPath == null || !mounted) return;
      final issueSuffix = assembly.issues.isEmpty
          ? ''
          : '; пропущено живых фрагментов: ${assembly.issues.length}';
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Документ экспортирован: ${payload.fileName}$issueSuffix',
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось экспортировать документ: $error')),
      );
    }
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showMessage('Укажи название документа.');
      return;
    }
    if (_workspace.sections.isEmpty) {
      _showMessage('Добавь хотя бы один раздел.');
      return;
    }

    final existing = _publication;
    if (existing == null) {
      final note = Note(
        id: _uuid.v4(),
        title: title,
        projectId: widget.project.id,
        body: '',
        status: 'draft',
        folderPath: 'Публикации и отчёты',
        noteType: 'publication',
        tags: const <String>['publication'],
      );
      PublicationWorkspaceCodec.write(note, _workspace, _sourceNotes);
      widget.store.addNote(note);
      _publication = note;
    } else {
      widget.store.addNoteVersion(
        NoteVersion(
          id: _uuid.v4(),
          noteId: existing.id,
          title: existing.title,
          body: existing.body,
          tags: List<String>.from(existing.tags),
          status: existing.status,
          folderPath: existing.folderPath,
          noteType: existing.noteType,
          properties: Map<String, String>.from(existing.properties),
          reason: 'Перед изменением пространства публикации',
        ),
      );
      existing.title = title;
      PublicationWorkspaceCodec.write(existing, _workspace, _sourceNotes);
      widget.store.updateNote(existing);
    }
    Navigator.pop(context, true);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _DocumentIdentityCard extends StatelessWidget {
  const _DocumentIdentityCard({
    required this.titleController,
    required this.workspace,
    required this.readOnly,
    required this.onTitleChanged,
    required this.onKindChanged,
  });

  final TextEditingController titleController;
  final PublicationWorkspace workspace;
  final bool readOnly;
  final VoidCallback onTitleChanged;
  final ValueChanged<PublicationKind> onKindChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: titleController,
              enabled: !readOnly,
              decoration: const InputDecoration(
                labelText: 'Название документа',
                prefixIcon: Icon(Icons.description_outlined),
              ),
              onChanged: (_) => onTitleChanged(),
            ),
            const SizedBox(height: 16),
            Text(
              'Формат результата',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<PublicationKind>(
                segments: <ButtonSegment<PublicationKind>>[
                  for (final kind in PublicationKind.values)
                    ButtonSegment<PublicationKind>(
                      value: kind,
                      icon: Text(kind.emoji),
                      label: Text(kind.label),
                    ),
                ],
                selected: <PublicationKind>{workspace.kind},
                onSelectionChanged: readOnly
                    ? null
                    : (selection) => onKindChanged(selection.first),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              workspace.kind.description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _AssemblyMetrics extends StatelessWidget {
  const _AssemblyMetrics({required this.assembly});

  final PublicationAssembly assembly;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MetricChip(
              icon: Icons.notes_rounded,
              label: '${assembly.wordCount} слов',
            ),
            _MetricChip(
              icon: Icons.link_rounded,
              label: '${assembly.liveFragmentCount} живых фрагментов',
            ),
            _MetricChip(
              icon: Icons.image_outlined,
              label: '${assembly.figureCount} рисунков',
            ),
            _MetricChip(
              icon: Icons.table_chart_outlined,
              label: '${assembly.tableCount} таблиц',
            ),
            _MetricChip(
              icon: Icons.short_text_rounded,
              label: '${assembly.abbreviations.length} сокращений',
            ),
            if (assembly.issues.isNotEmpty)
              _MetricChip(
                icon: Icons.warning_amber_rounded,
                label: '${assembly.issues.length} требуют внимания',
                error: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    this.error = false,
  });

  final IconData icon;
  final String label;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(
        icon,
        size: 18,
        color: error ? colorScheme.error : colorScheme.primary,
      ),
      label: Text(label),
      backgroundColor: error ? colorScheme.errorContainer : null,
    );
  }
}

class _AssemblyIssuesCard extends StatelessWidget {
  const _AssemblyIssuesCard({required this.issues});

  final List<PublicationAssemblyIssue> issues;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.link_off_rounded, color: colorScheme.error),
                const SizedBox(width: 10),
                Text(
                  'Проверка живых связей',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final issue in issues)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• ${issue.message}'),
              ),
          ],
        ),
      ),
    );
  }
}

class _AssemblySettingsCard extends StatelessWidget {
  const _AssemblySettingsCard({
    required this.workspace,
    required this.readOnly,
    required this.onChanged,
  });

  final PublicationWorkspace workspace;
  final bool readOnly;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.tune_rounded),
        title: const Text('Сборка и автоматическая проверка'),
        subtitle: const Text(
          'Нумерация, список сокращений и библиография формируются только '
          'в собранном документе.',
        ),
        children: [
          SwitchListTile(
            value: workspace.numberFigures,
            onChanged: readOnly
                ? null
                : (value) {
                    workspace.numberFigures = value;
                    onChanged();
                  },
            title: const Text('Автоматическая нумерация рисунков'),
          ),
          SwitchListTile(
            value: workspace.numberTables,
            onChanged: readOnly
                ? null
                : (value) {
                    workspace.numberTables = value;
                    onChanged();
                  },
            title: const Text('Автоматическая нумерация таблиц'),
          ),
          SwitchListTile(
            value: workspace.includeAbbreviations,
            onChanged: readOnly
                ? null
                : (value) {
                    workspace.includeAbbreviations = value;
                    onChanged();
                  },
            title: const Text('Добавлять распознанный список сокращений'),
            subtitle: const Text('Формат распознавания: полное название (ABC).'),
          ),
          SwitchListTile(
            value: workspace.includeBibliography,
            onChanged: readOnly
                ? null
                : (value) {
                    workspace.includeBibliography = value;
                    onChanged();
                  },
            title: const Text('Добавлять библиографию по цитатам'),
            subtitle: const Text('Используются существующие ссылки вида [@key].'),
          ),
        ],
      ),
    );
  }
}

class _PublicationSectionCard extends StatelessWidget {
  const _PublicationSectionCard({
    super.key,
    required this.section,
    required this.sectionIndex,
    required this.sectionCount,
    required this.notesById,
    required this.issueFragmentIds,
    required this.readOnly,
    required this.onChanged,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
    required this.onAddFragment,
    required this.onMoveFragment,
    required this.onDeleteFragment,
  });

  final PublicationSection section;
  final int sectionIndex;
  final int sectionCount;
  final Map<String, Note> notesById;
  final Set<String> issueFragmentIds;
  final bool readOnly;
  final VoidCallback onChanged;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onDelete;
  final VoidCallback onAddFragment;
  final void Function(int from, int to) onMoveFragment;
  final ValueChanged<int> onDeleteFragment;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: sectionIndex < 2,
        leading: CircleAvatar(child: Text('${sectionIndex + 1}')),
        title: Text(
          section.title.trim().isEmpty ? 'Раздел' : section.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${section.fragments.length} живых фрагментов'
          '${section.text.trim().isEmpty ? '' : ' · есть собственный текст'}',
        ),
        trailing: readOnly
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Выше',
                    onPressed: onMoveUp,
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                  IconButton(
                    tooltip: 'Ниже',
                    onPressed: onMoveDown,
                    icon: const Icon(Icons.arrow_downward_rounded),
                  ),
                  IconButton(
                    tooltip: 'Удалить раздел',
                    onPressed: sectionCount == 1 ? null : onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  key: ValueKey<String>('title-${section.id}'),
                  initialValue: section.title,
                  enabled: !readOnly,
                  decoration: const InputDecoration(
                    labelText: 'Название раздела',
                  ),
                  onChanged: (value) {
                    section.title = value;
                    onChanged();
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: ValueKey<String>('text-${section.id}'),
                  initialValue: section.text,
                  enabled: !readOnly,
                  minLines: 3,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: 'Собственный связующий текст',
                    hintText:
                        'Интерпретация, переходы и формулировки, которые '
                        'принадлежат именно итоговому документу.',
                    alignLabelWithHint: true,
                  ),
                  onChanged: (value) {
                    section.text = value;
                    onChanged();
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Живые фрагменты',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    if (!readOnly)
                      TextButton.icon(
                        onPressed: onAddFragment,
                        icon: const Icon(Icons.add_link_rounded),
                        label: const Text('Подключить заметку'),
                      ),
                  ],
                ),
                if (section.fragments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'Можно оставить только собственный текст или подключить '
                      'целую заметку либо один её раздел.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                else
                  for (var index = 0;
                      index < section.fragments.length;
                      index += 1)
                    _FragmentTile(
                      fragment: section.fragments[index],
                      source: notesById[section.fragments[index].noteId],
                      hasIssue:
                          issueFragmentIds.contains(section.fragments[index].id),
                      readOnly: readOnly,
                      onMoveUp: index == 0
                          ? null
                          : () => onMoveFragment(index, index - 1),
                      onMoveDown: index == section.fragments.length - 1
                          ? null
                          : () => onMoveFragment(index, index + 1),
                      onDelete: () => onDeleteFragment(index),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FragmentTile extends StatelessWidget {
  const _FragmentTile({
    required this.fragment,
    required this.source,
    required this.hasIssue,
    required this.readOnly,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
  });

  final PublicationFragment fragment;
  final Note? source;
  final bool hasIssue;
  final bool readOnly;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final content = source == null
        ? null
        : publicationFragmentContent(source!, fragment.heading);
    final excerpt = content == null ? '' : _plainExcerpt(content);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: hasIssue
              ? colorScheme.errorContainer
              : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: Icon(
            hasIssue ? Icons.link_off_rounded : Icons.link_rounded,
            color: hasIssue ? colorScheme.error : colorScheme.primary,
          ),
          title: Text(source?.title ?? 'Исходная заметка удалена'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fragment.heading.trim().isEmpty
                    ? 'Вся заметка'
                    : 'Раздел: ${fragment.heading}',
              ),
              if (excerpt.isNotEmpty)
                Text(
                  excerpt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
          trailing: readOnly
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Выше',
                      onPressed: onMoveUp,
                      icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                    ),
                    IconButton(
                      tooltip: 'Ниже',
                      onPressed: onMoveDown,
                      icon: const Icon(Icons.arrow_downward_rounded, size: 20),
                    ),
                    IconButton(
                      tooltip: 'Убрать привязку',
                      onPressed: onDelete,
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  static String _plainExcerpt(String markdown) {
    return markdown
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
        .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), ' ')
        .replaceAllMapped(
          RegExp(r'\[([^\]]+)\]\([^)]*\)'),
          (match) => match.group(1) ?? '',
        )
        .replaceAll(RegExp(r'[#>*_`~|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class PublicationSourceSelection {
  const PublicationSourceSelection({required this.note, required this.heading});

  final Note note;
  final String heading;
}

class PublicationFragmentPickerSheet extends StatefulWidget {
  const PublicationFragmentPickerSheet({super.key, required this.notes});

  final List<Note> notes;

  static Future<PublicationSourceSelection?> show(
    BuildContext context, {
    required List<Note> notes,
  }) {
    return showModalBottomSheet<PublicationSourceSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 760),
      builder: (_) => PublicationFragmentPickerSheet(notes: notes),
    );
  }

  @override
  State<PublicationFragmentPickerSheet> createState() =>
      _PublicationFragmentPickerSheetState();
}

class _PublicationFragmentPickerSheetState
    extends State<PublicationFragmentPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  Note? _selectedNote;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 0, 18, bottom + 18),
          child: _selectedNote == null
              ? _buildNoteList(context)
              : _buildHeadingList(context, _selectedNote!),
        ),
      ),
    );
  }

  Widget _buildNoteList(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = widget.notes.where((note) {
      if (query.isEmpty) return true;
      return note.title.toLowerCase().contains(query) ||
          note.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Подключить живой фрагмент',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Выбери заметку, затем весь текст или конкретный заголовок. '
          'Chronicle сохранит ссылку, а не копию.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Поиск заметок',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('Подходящих заметок нет.'))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final note = filtered[index];
                    final headings = publicationHeadings(note);
                    return ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(note.title),
                      subtitle: Text(
                        '${note.noteType} · ${headings.length} заголовков',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => setState(() => _selectedNote = note),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHeadingList(BuildContext context, Note note) {
    final headings = publicationHeadings(note);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Назад к заметкам',
              onPressed: () => setState(() => _selectedNote = null),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const Text('Какую часть подключить?'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.notes_rounded),
                title: const Text('Вся заметка'),
                subtitle: const Text('Текст будет собираться целиком.'),
                onTap: () => Navigator.pop(
                  context,
                  PublicationSourceSelection(note: note, heading: ''),
                ),
              ),
              if (headings.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    'В заметке нет Markdown-заголовков. Её всё равно можно '
                    'подключить целиком.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              else ...[
                const Divider(),
                for (final heading in headings)
                  ListTile(
                    leading: Padding(
                      padding: EdgeInsets.only(
                        left: ((heading.level - 1) * 10).toDouble(),
                      ),
                      child: const Icon(Icons.segment_rounded),
                    ),
                    title: Text(heading.title),
                    subtitle: Text('Заголовок уровня ${heading.level}'),
                    onTap: () => Navigator.pop(
                      context,
                      PublicationSourceSelection(
                        note: note,
                        heading: heading.title,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
