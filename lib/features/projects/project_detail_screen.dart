import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../../models/app_models.dart';
import '../../services/app_store.dart';
import '../../widgets/common.dart';
import '../appearance/app_appearance.dart';
import '../notes/note_export.dart';
import '../intelligence/local_intelligence_screen.dart';
import '../notes/note_export_dialog.dart';
import '../notes/note_export_file_service.dart';
import '../publications/publication_workspace.dart';
import '../publications/publication_workspace_screen.dart';
import '../tasks/task_editor_sheet.dart';
import '../tasks/task_metadata.dart';
import 'project_appearance_store.dart';
import 'project_appearance_widgets.dart';
import 'project_editor_sheet.dart';
import 'project_research.dart';
import 'project_research_dialog.dart';

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({
    super.key,
    required this.store,
    required this.projectId,
    required this.appearanceController,
    required this.globalAppearance,
  });

  final AppStore store;
  final String projectId;
  final ProjectAppearanceController appearanceController;
  final AppAppearancePreferences globalAppearance;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final project = widget.store.projectById(widget.projectId);
    if (project == null) {
      return const Scaffold(body: Center(child: Text('Проект не найден')));
    }

    final tasks = widget.store.data.tasks
        .where((task) => task.projectId == project.id)
        .toList()
      ..sort((a, b) {
        final priority = b.priority.compareTo(a.priority);
        if (priority != 0) return priority;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    final rootTasks = tasks.where((task) => task.parentTaskId == null).toList();
    final notes = widget.store.data.notes
        .where((note) => note.projectId == project.id)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final publicationNotes = notes
        .where(PublicationWorkspaceCodec.isPublication)
        .toList(growable: false);
    final sourceNotes = notes
        .where((note) => !PublicationWorkspaceCodec.isPublication(note))
        .toList(growable: false);
    final linkedSourceIds = project.linkedSourceIds.toSet();
    final sources = widget.store.data.citationSources
        .where((source) => linkedSourceIds.contains(source.id))
        .toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    final pinnedIds = project.pinnedNoteIds.toSet();
    final pinnedNotes = sourceNotes
        .where((note) => pinnedIds.contains(note.id))
        .toList(growable: false);
    final attachmentPaths = projectAttachmentPaths(sourceNotes);
    final sourceFiles = sources
        .map((source) => source.pdfPath.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final files = <String>{...attachmentPaths, ...sourceFiles}.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final entries = widget.store.data.entries
        .where((entry) => entry.projectId == project.id)
        .toList();
    final seconds = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.durationSeconds,
    );
    final done = tasks.where((task) => task.status == 'done').length;
    final progress = tasks.isEmpty ? 0.0 : done / tasks.length;
    final timeline = _projectTimeline(project, notes, tasks, entries);

    return ProjectAppearanceScope(
      projectId: project.id,
      controller: widget.appearanceController,
      globalAppearance: widget.globalAppearance,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              ProjectAvatar(
                project: project,
                controller: widget.appearanceController,
                size: 30,
                borderRadius: 8,
                emojiFontSize: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(project.title, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Исследовательская страница',
              onPressed: project.archived
                  ? null
                  : () => _editResearch(project, sourceNotes),
              icon: const Icon(Icons.science_outlined),
            ),
            IconButton(
              tooltip: 'Редактировать проект',
              onPressed: () => _editProject(project),
              icon: const Icon(Icons.edit_outlined),
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'export') {
                  await _exportProject(project, notes, tasks);
                  return;
                }
                if (value == 'archive') {
                  widget.store.setProjectArchived(project, !project.archived);
                  setState(() {});
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem<String>(
                  value: 'export',
                  child: ListTile(
                    leading: Icon(Icons.download_outlined),
                    title: Text('Экспортировать проект'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'archive',
                  child: Text(
                    project.archived ? 'Вернуть из архива' : 'Архивировать',
                  ),
                ),
              ],
            ),
          ],
        ),
        floatingActionButton: project.archived
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _addTask(project),
                icon: const Icon(Icons.add_task_rounded),
                label: const Text('Задача'),
              ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            _ProjectHero(
              project: project,
              appearanceController: widget.appearanceController,
              progress: progress,
              done: done,
              total: tasks.length,
              seconds: seconds,
            ),
            const SizedBox(height: 14),
            _ResearchBriefCard(
              project: project,
              onEdit: project.archived
                  ? null
                  : () => _editResearch(project, sourceNotes),
            ),
            const SizedBox(height: 14),
            _ProjectMetrics(
              taskCount: tasks.length,
              noteCount: sourceNotes.length,
              sourceCount: sources.length,
              fileCount: files.length,
            ),
            const SizedBox(height: 22),
            _KnowledgeStatusSection(
              knownFindings: project.knownFindings,
              openChecks: project.openChecks,
              onEdit: project.archived
                  ? null
                  : () => _editResearch(project, sourceNotes),
            ),
            const SizedBox(height: 22),
            _PinnedResultsSection(
              notes: pinnedNotes,
              onEdit: project.archived
                  ? null
                  : () => _editResearch(project, sourceNotes),
            ),
            const SizedBox(height: 22),
            _LocalIntelligenceCard(
              noteCount: sourceNotes.length,
              onOpen: () => LocalIntelligenceScreen.show(
                context, store: widget.store, project: project),
            ),
            const SizedBox(height: 22),
            _PublicationOutputsSection(
              publications: publicationNotes,
              readOnly: project.archived,
              onCreate: () => _createPublication(project),
              onOpen: (publication) =>
                  _openPublication(project, publication),
            ),
            const SizedBox(height: 22),
            _ProjectMaterialsSection(
              notes: sourceNotes,
              sources: sources,
              files: files,
            ),
            const SizedBox(height: 22),
            _ProjectTimelineSection(items: timeline),
            const SizedBox(height: 22),
            SectionTitle('Задачи проекта', trailing: Text('${tasks.length}')),
            const SizedBox(height: 6),
            if (rootTasks.isEmpty)
              const _EmptyProjectTasks()
            else
              for (var index = 0; index < rootTasks.length; index++) ...[
                _ProjectTaskCard(
                  task: rootTasks[index],
                  children: tasks
                      .where((item) => item.parentTaskId == rootTasks[index].id)
                      .toList(),
                  onToggle: (value) {
                    widget.store.updateTaskStatus(
                      rootTasks[index],
                      value ? 'done' : 'next',
                    );
                    setState(() {});
                  },
                  onEdit: () => _editTask(rootTasks[index]),
                  onAddSubtask: () => _addSubtask(rootTasks[index]),
                  onDelete: () => _deleteTask(rootTasks[index]),
                  onChildToggle: (child, value) {
                    widget.store.updateTaskStatus(
                      child,
                      value ? 'done' : 'next',
                    );
                    setState(() {});
                  },
                  onChildEdit: _editTask,
                ),
                if (index != rootTasks.length - 1) const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }

  Future<void> _exportProject(
    Project project,
    List<Note> notes,
    List<WorkTask> tasks,
  ) async {
    final format = await NoteExportDialog.show(
      context,
      subjectLabel: project.title,
      isProject: true,
    );
    if (format == null || !mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      final payload = await NoteExportComposer(
        readAttachment: widget.store.readManagedAttachment,
      ).exportProject(
        project: project,
        notes: notes,
        tasks: tasks,
        format: format,
      );
      final savedPath = await const NoteExportFileService().save(payload);
      if (savedPath == null || !mounted) {
        return;
      }
      final missingSuffix =
          payload.missingAttachments.isEmpty
              ? ''
              : '; не найдено вложений: '
                  '${payload.missingAttachments.length}';
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Проект экспортирован: ${payload.fileName}; '
            'вложений: ${payload.assetCount}$missingSuffix',
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось экспортировать проект: $error')),
      );
    }
  }

  Future<void> _editProject(Project project) async {
    final result = await ProjectEditorSheet.show(
      context,
      project: project,
      appearanceController: widget.appearanceController,
      globalAppearance: widget.globalAppearance,
    );
    if (result == null) return;
    widget.store.updateProject(result.project);
    try {
      await widget.appearanceController.saveProjectAppearance(
        result.project.id,
        result.appearance,
        icon: result.icon,
        removeIcon: result.removeIcon,
        background: result.background,
        removeBackground: result.removeBackground,
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить оформление: $error')),
      );
    }
    if (mounted) setState(() {});
  }

  Future<void> _editResearch(Project project, List<Note> notes) async {
    final result = await ProjectResearchEditorSheet.show(
      context,
      project: project,
      notes: notes,
      sources: widget.store.data.citationSources,
    );
    if (result == null) return;
    project.researchGoal = result.researchGoal;
    project.researchQuestions = result.researchQuestions;
    project.knownFindings = result.knownFindings;
    project.openChecks = result.openChecks;
    project.pinnedNoteIds = result.pinnedNoteIds;
    project.linkedSourceIds = result.linkedSourceIds;
    widget.store.updateProject(project);
    if (mounted) setState(() {});
  }

  Future<void> _createPublication(Project project) async {
    final changed = await PublicationWorkspaceScreen.show(
      context,
      store: widget.store,
      project: project,
    );
    if (changed == true && mounted) setState(() {});
  }

  Future<void> _openPublication(Project project, Note publication) async {
    final changed = await PublicationWorkspaceScreen.show(
      context,
      store: widget.store,
      project: project,
      publication: publication,
      readOnly: project.archived,
    );
    if (changed == true && mounted) setState(() {});
  }

  Future<void> _addTask(Project project) async {
    final task = await TaskEditorSheet.show(
      context,
      projects: widget.store.activeProjects,
      tasks: widget.store.data.tasks,
      initialProjectId: project.id,
    );
    if (task == null) return;
    widget.store.addTask(task);
    setState(() {});
  }

  Future<void> _addSubtask(WorkTask parent) async {
    final task = await TaskEditorSheet.show(
      context,
      projects: widget.store.activeProjects,
      tasks: widget.store.data.tasks,
      initialProjectId: parent.projectId,
      initialParentTaskId: parent.id,
    );
    if (task == null) return;
    widget.store.addTask(task);
    setState(() {});
  }

  Future<void> _editTask(WorkTask task) async {
    final edited = await TaskEditorSheet.show(
      context,
      projects: widget.store.activeProjects,
      tasks: widget.store.data.tasks,
      task: task,
    );
    if (edited == null) return;
    final index = widget.store.data.tasks.indexWhere(
      (item) => item.id == task.id,
    );
    if (index >= 0) widget.store.data.tasks[index] = edited;
    widget.store.updateTask(edited);
    setState(() {});
  }

  Future<void> _deleteTask(WorkTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Удалить задачу?'),
            content: Text('«${task.title}» будет перемещена в корзину.'),
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
    if (confirmed != true) return;
    widget.store.deleteTask(task.id);
    setState(() {});
  }
}

class _ResearchBriefCard extends StatelessWidget {
  const _ResearchBriefCard({required this.project, required this.onEdit});

  final Project project;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final hasGoal = project.researchGoal.trim().isNotEmpty;
    final questions = project.researchQuestions;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.science_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Цель и исследовательские вопросы',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'Редактировать',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_note_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              hasGoal
                  ? project.researchGoal
                  : 'Цель пока не сформулирована. Можно оставить проект полностью свободным или описать, что именно здесь исследуется.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (questions.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final question in questions)
                    Chip(
                      avatar: const Icon(Icons.help_outline_rounded, size: 17),
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Text(question),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProjectMetrics extends StatelessWidget {
  const _ProjectMetrics({
    required this.taskCount,
    required this.noteCount,
    required this.sourceCount,
    required this.fileCount,
  });

  final int taskCount;
  final int noteCount;
  final int sourceCount;
  final int fileCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 800 ? 4 : 2;
        final gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        final metrics = <Widget>[
          MetricCard(
            icon: Icons.checklist_rounded,
            label: 'Задачи',
            value: '$taskCount',
          ),
          MetricCard(
            icon: Icons.menu_book_rounded,
            label: 'Заметки',
            value: '$noteCount',
          ),
          MetricCard(
            icon: Icons.library_books_outlined,
            label: 'Источники',
            value: '$sourceCount',
          ),
          MetricCard(
            icon: Icons.attach_file_rounded,
            label: 'Файлы',
            value: '$fileCount',
          ),
        ];
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final metric in metrics) SizedBox(width: width, child: metric)],
        );
      },
    );
  }
}

class _KnowledgeStatusSection extends StatelessWidget {
  const _KnowledgeStatusSection({
    required this.knownFindings,
    required this.openChecks,
    required this.onEdit,
  });

  final List<String> knownFindings;
  final List<String> openChecks;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Карта знания',
          trailing: TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Изменить'),
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = <Widget>[
              _KnowledgeListCard(
                icon: Icons.verified_outlined,
                title: 'Уже известно',
                emptyText: 'Здесь появятся подтверждённые наблюдения и выводы.',
                items: knownFindings,
              ),
              _KnowledgeListCard(
                icon: Icons.manage_search_rounded,
                title: 'Нужно проверить',
                emptyText: 'Здесь можно держать пробелы, сомнения и следующие проверки.',
                items: openChecks,
              ),
            ];
            if (constraints.maxWidth < 720) {
              return Column(
                children: [
                  cards.first,
                  const SizedBox(height: 12),
                  cards.last,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cards.first),
                const SizedBox(width: 12),
                Expanded(child: cards.last),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _KnowledgeListCard extends StatelessWidget {
  const _KnowledgeListCard({
    required this.icon,
    required this.title,
    required this.emptyText,
    required this.items,
  });

  final IconData icon;
  final String title;
  final String emptyText;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 9),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text(emptyText, style: Theme.of(context).textTheme.bodySmall)
            else
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Icon(Icons.circle, size: 7),
                      ),
                      const SizedBox(width: 9),
                      Expanded(child: Text(item)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _PinnedResultsSection extends StatelessWidget {
  const _PinnedResultsSection({required this.notes, required this.onEdit});

  final List<Note> notes;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Закреплённые результаты',
          trailing: TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.push_pin_outlined, size: 18),
            label: const Text('Настроить'),
          ),
        ),
        const SizedBox(height: 6),
        if (notes.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(Icons.bookmark_add_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Закрепи ключевые заметки: вывод, таблицу результатов, финальный график или недельный отчёт.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final note in notes)
                SizedBox(
                  width: 320,
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.push_pin_rounded),
                      title: Text(note.title),
                      subtitle: Text(
                        '${note.noteType} · ${shortDate(note.updatedAt)}',
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _LocalIntelligenceCard extends StatelessWidget {
  const _LocalIntelligenceCard({required this.noteCount, required this.onOpen});
  final int noteCount; final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(children: [
        Icon(Icons.manage_search_rounded, size: 34, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Локальный интеллектуальный поиск', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text('Смысловой поиск, похожие заметки, возможные связи и противоречия, ответы с источниками и история эксперимента. Индекс для $noteCount заметок хранится только на этом устройстве.', style: Theme.of(context).textTheme.bodySmall),
        ])),
        const SizedBox(width: 12),
        FilledButton.tonalIcon(onPressed: onOpen, icon: const Icon(Icons.auto_awesome_outlined), label: const Text('Открыть')),
      ]),
    ),
  );
}

class _PublicationOutputsSection extends StatelessWidget {
  const _PublicationOutputsSection({
    required this.publications,
    required this.readOnly,
    required this.onCreate,
    required this.onOpen,
  });

  final List<Note> publications;
  final bool readOnly;
  final VoidCallback onCreate;
  final ValueChanged<Note> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Публикации и отчёты',
          trailing: FilledButton.tonalIcon(
            onPressed: readOnly ? null : onCreate,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Создать'),
          ),
        ),
        const SizedBox(height: 6),
        if (publications.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Собери результат из живых заметок',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Создай статью, отчёт или презентационный конспект. '
                          'Разделы заметок останутся связанными с оригиналами, '
                          'а Chronicle проверит потерянные связи, нумерацию и '
                          'библиографию перед экспортом.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final publication in publications)
                SizedBox(
                  width: 340,
                  child: _PublicationOutputCard(
                    publication: publication,
                    onTap: () => onOpen(publication),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _PublicationOutputCard extends StatelessWidget {
  const _PublicationOutputCard({
    required this.publication,
    required this.onTap,
  });

  final Note publication;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    var fallbackId = 0;
    final workspace = PublicationWorkspaceCodec.read(
      publication,
      idFactory: () => 'fallback-${publication.id}-${fallbackId++}',
    );
    final fragmentCount = workspace.sections.fold<int>(
      0,
      (sum, section) => sum + section.fragments.length,
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    workspace.kind.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      publication.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                workspace.kind.label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 5,
                children: [
                  Text('${workspace.sections.length} разделов'),
                  Text('$fragmentCount живых фрагментов'),
                  Text('обновлено ${shortDate(publication.updatedAt)}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectMaterialsSection extends StatelessWidget {
  const _ProjectMaterialsSection({
    required this.notes,
    required this.sources,
    required this.files,
  });

  final List<Note> notes;
  final List<CitationSource> sources;
  final List<String> files;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Связанные материалы'),
        const SizedBox(height: 6),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                _MaterialHeader(
                  icon: Icons.menu_book_outlined,
                  title: 'Заметки',
                  count: notes.length,
                ),
                if (notes.isEmpty)
                  const _MaterialEmpty('В проекте пока нет заметок.')
                else
                  for (final note in notes.take(5))
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.description_outlined),
                      title: Text(note.title),
                      subtitle: Text('${note.noteType} · ${shortDate(note.updatedAt)}'),
                    ),
                const Divider(height: 18),
                _MaterialHeader(
                  icon: Icons.library_books_outlined,
                  title: 'Источники',
                  count: sources.length,
                ),
                if (sources.isEmpty)
                  const _MaterialEmpty('Источники можно связать через исследовательскую страницу.')
                else
                  for (final source in sources.take(5))
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.article_outlined),
                      title: Text(source.title),
                      subtitle: Text(
                        [
                          if (source.authors.isNotEmpty) source.authors.first,
                          if (source.year != null) '${source.year}',
                          if (source.citationKey.isNotEmpty) source.citationKey,
                        ].join(' · '),
                      ),
                    ),
                const Divider(height: 18),
                _MaterialHeader(
                  icon: Icons.attach_file_rounded,
                  title: 'Файлы',
                  count: files.length,
                ),
                if (files.isEmpty)
                  const _MaterialEmpty('Файлы появятся из вложений заметок и PDF связанных источников.')
                else
                  for (final file in files.take(8))
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.insert_drive_file_outlined),
                      title: Text(path.basename(file)),
                      subtitle: Text(file, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MaterialHeader extends StatelessWidget {
  const _MaterialHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  final IconData icon;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
      trailing: Text('$count'),
    );
  }
}

class _MaterialEmpty extends StatelessWidget {
  const _MaterialEmpty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      );
}

class _ProjectTimelineItem {
  const _ProjectTimelineItem({
    required this.at,
    required this.icon,
    required this.title,
    required this.detail,
  });

  final DateTime at;
  final IconData icon;
  final String title;
  final String detail;
}

List<_ProjectTimelineItem> _projectTimeline(
  Project project,
  List<Note> notes,
  List<WorkTask> tasks,
  List<TimeEntry> entries,
) {
  final result = <_ProjectTimelineItem>[
    _ProjectTimelineItem(
      at: project.createdAt,
      icon: Icons.flag_outlined,
      title: 'Проект создан',
      detail: project.title,
    ),
  ];
  for (final note in notes) {
    result.add(
      _ProjectTimelineItem(
        at: note.updatedAt,
        icon: Icons.description_outlined,
        title: note.createdAt == note.updatedAt ? 'Заметка создана' : 'Заметка обновлена',
        detail: note.title,
      ),
    );
  }
  for (final task in tasks) {
    final completedAt = task.completedAt;
    if (completedAt != null || task.status == 'done') {
      result.add(
        _ProjectTimelineItem(
          at: completedAt ?? task.updatedAt,
          icon: Icons.task_alt_rounded,
          title: 'Задача завершена',
          detail: task.title,
        ),
      );
    }
  }
  for (final entry in entries) {
    result.add(
      _ProjectTimelineItem(
        at: entry.startedAt,
        icon: Icons.timer_outlined,
        title: 'Работа над проектом',
        detail: entry.description.trim().isEmpty
            ? formatDuration(entry.durationSeconds)
            : '${entry.description} · ${formatDuration(entry.durationSeconds)}',
      ),
    );
  }
  result.sort((left, right) => right.at.compareTo(left.at));
  return result.take(16).toList(growable: false);
}

class _ProjectTimelineSection extends StatelessWidget {
  const _ProjectTimelineSection({required this.items});

  final List<_ProjectTimelineItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Временная шкала работы'),
        const SizedBox(height: 6),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                for (var index = 0; index < items.length; index++)
                  ListTile(
                    leading: CircleAvatar(
                      child: Icon(items[index].icon, size: 19),
                    ),
                    title: Text(items[index].title),
                    subtitle: Text(items[index].detail),
                    trailing: Text(
                      shortDate(items[index].at),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProjectHero extends StatelessWidget {
  const _ProjectHero({
    required this.project,
    required this.appearanceController,
    required this.progress,
    required this.done,
    required this.total,
    required this.seconds,
  });

  final Project project;
  final ProjectAppearanceController appearanceController;
  final double progress;
  final int done;
  final int total;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final color = Color(project.colorValue);
    final spentMinutes = seconds ~/ 60;
    final budget = project.budgetMinutes;
    final budgetProgress =
        budget == null || budget <= 0
            ? null
            : (spentMinutes / budget).clamp(0.0, 1.0);

    return ProjectSurface(
      emphasized: true,
      tint: color.withValues(alpha: 0.14),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProjectAvatar(
                  project: project,
                  controller: appearanceController,
                  size: 58,
                  borderRadius: 18,
                  backgroundColor: color,
                  emojiFontSize: 30,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (project.description.isNotEmpty)
                        Text(
                          project.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(99),
              color: color,
            ),
            const SizedBox(height: 8),
            Text('$done из $total задач завершено'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _HeroFact(
                  icon: Icons.schedule_rounded,
                  text: formatDuration(seconds),
                ),
                if (project.dueAt != null)
                  _HeroFact(
                    icon: Icons.event_rounded,
                    text: shortDate(project.dueAt),
                  ),
                if (budget != null)
                  _HeroFact(
                    icon: Icons.account_balance_wallet_outlined,
                    text: '${(budget / 60).toStringAsFixed(1)} ч бюджет',
                  ),
              ],
            ),
            if (budgetProgress != null) ...[
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: budgetProgress,
                minHeight: 5,
                borderRadius: BorderRadius.circular(99),
                color:
                    budgetProgress >= 1
                        ? Theme.of(context).colorScheme.error
                        : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeroFact extends StatelessWidget {
  const _HeroFact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [Icon(icon, size: 18), const SizedBox(width: 6), Text(text)],
  );
}

class _ProjectTaskCard extends StatelessWidget {
  const _ProjectTaskCard({
    required this.task,
    required this.children,
    required this.onToggle,
    required this.onEdit,
    required this.onAddSubtask,
    required this.onDelete,
    required this.onChildToggle,
    required this.onChildEdit,
  });

  final WorkTask task;
  final List<WorkTask> children;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onAddSubtask;
  final VoidCallback onDelete;
  final void Function(WorkTask task, bool value) onChildToggle;
  final void Function(WorkTask task) onChildEdit;

  @override
  Widget build(BuildContext context) {
    final priorityColor = taskPriorityColor(context, task.priority);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        child: Column(
          children: [
            ListTile(
              leading: Checkbox(
                value: task.status == 'done',
                onChanged: (value) => onToggle(value == true),
              ),
              title: Text(
                task.title,
                style:
                    task.status == 'done'
                        ? const TextStyle(
                          decoration: TextDecoration.lineThrough,
                        )
                        : null,
              ),
              subtitle: Wrap(
                spacing: 10,
                children: [
                  Text(taskStatusLabel(task.status)),
                  Text('${task.estimateMinutes} мин'),
                  if (task.dueAt != null)
                    Text(
                      shortDate(task.dueAt),
                      style: TextStyle(
                        color:
                            isOverdue(task.dueAt) && task.status != 'done'
                                ? Theme.of(context).colorScheme.error
                                : null,
                      ),
                    ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'subtask') onAddSubtask();
                  if (value == 'delete') onDelete();
                },
                itemBuilder:
                    (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Редактировать'),
                      ),
                      PopupMenuItem(
                        value: 'subtask',
                        child: Text('Добавить подзадачу'),
                      ),
                      PopupMenuItem(value: 'delete', child: Text('Удалить')),
                    ],
              ),
            ),
            if (task.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(58, 0, 14, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    task.description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            if (task.priority != 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(58, 0, 14, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    avatar: Icon(
                      taskPriorityIcon(task.priority),
                      size: 16,
                      color: priorityColor,
                    ),
                    label: Text(taskPriorityLabel(task.priority)),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            if (children.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Column(
                  children:
                      children
                          .map(
                            (child) => ListTile(
                              dense: true,
                              leading: Checkbox(
                                value: child.status == 'done',
                                onChanged:
                                    (value) =>
                                        onChildToggle(child, value == true),
                              ),
                              title: Text(child.title),
                              subtitle: Text(
                                '${taskStatusLabel(child.status)} · '
                                '${child.estimateMinutes} мин',
                              ),
                              trailing: IconButton(
                                tooltip: 'Редактировать',
                                onPressed: () => onChildEdit(child),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyProjectTasks extends StatelessWidget {
  const _EmptyProjectTasks();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.task_alt_rounded,
            size: 46,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          const Text('В этом проекте пока нет задач'),
        ],
      ),
    ),
  );
}
