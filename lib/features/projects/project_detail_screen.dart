import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../services/app_store.dart';
import '../../widgets/common.dart';
import '../appearance/app_appearance.dart';
import '../notes/note_export.dart';
import '../notes/note_export_dialog.dart';
import '../notes/note_export_file_service.dart';
import '../tasks/task_editor_sheet.dart';
import '../tasks/task_metadata.dart';
import 'project_appearance_store.dart';
import 'project_appearance_widgets.dart';
import 'project_editor_sheet.dart';

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

    final tasks =
        widget.store.data.tasks
            .where((task) => task.projectId == project.id)
            .toList()
          ..sort((a, b) {
            final priority = b.priority.compareTo(a.priority);
            if (priority != 0) return priority;
            return b.updatedAt.compareTo(a.updatedAt);
          });
    final rootTasks = tasks.where((task) => task.parentTaskId == null).toList();
    final notes =
        widget.store.data.notes
            .where((note) => note.projectId == project.id)
            .toList();
    final entries =
        widget.store.data.entries
            .where((entry) => entry.projectId == project.id)
            .toList();
    final seconds = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.durationSeconds,
    );
    final done = tasks.where((task) => task.status == 'done').length;
    final progress = tasks.isEmpty ? 0.0 : done / tasks.length;

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
              tooltip: 'Редактировать',
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
        body: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverToBoxAdapter(
                child: _ProjectHero(
                  project: project,
                  appearanceController: widget.appearanceController,
                  progress: progress,
                  done: done,
                  total: tasks.length,
                  seconds: seconds,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        icon: Icons.checklist_rounded,
                        label: 'Задачи',
                        value: '$done / ${tasks.length}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricCard(
                        icon: Icons.menu_book_rounded,
                        label: 'Заметки',
                        value: '${notes.length}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 22)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: SectionTitle(
                  'Задачи проекта',
                  trailing: Text('${tasks.length}'),
                ),
              ),
            ),
            if (rootTasks.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 6, 16, 120),
                sliver: SliverToBoxAdapter(child: _EmptyProjectTasks()),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, rawIndex) {
                    if (rawIndex.isOdd) return const SizedBox(height: 10);
                    final index = rawIndex ~/ 2;
                    final task = rootTasks[index];
                    final children = tasks
                        .where((item) => item.parentTaskId == task.id)
                        .toList();
                    return _ProjectTaskCard(
                      task: task,
                      children: children,
                      onToggle: (value) {
                        widget.store.updateTaskStatus(
                          task,
                          value ? 'done' : 'next',
                        );
                        setState(() {});
                      },
                      onEdit: () => _editTask(task),
                      onAddSubtask: () => _addSubtask(task),
                      onDelete: () => _deleteTask(task),
                      onChildToggle: (child, value) {
                        widget.store.updateTaskStatus(
                          child,
                          value ? 'done' : 'next',
                        );
                        setState(() {});
                      },
                      onChildEdit: _editTask,
                    );
                  }, childCount: rootTasks.length * 2 - 1),
                ),
              ),
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
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить оформление: $error')),
      );
    }
    if (mounted) setState(() {});
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
