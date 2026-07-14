import 'package:flutter/material.dart';

import '../features/tasks/task_editor_sheet.dart';
import '../features/tasks/task_metadata.dart';
import '../models/app_models.dart';
import '../services/app_store.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with SingleTickerProviderStateMixin {
  late final TabController tabs;
  final searchController = TextEditingController();
  String query = '';
  String? projectFilter;
  int? priorityFilter;

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: taskStatuses.length, vsync: this);
    searchController.addListener(() {
      setState(() => query = searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    tabs.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Задачи'),
        actions: [
          IconButton(
            tooltip: 'Фильтры',
            onPressed: _showFilters,
            icon: Badge(
              isLabelVisible: projectFilter != null || priorityFilter != null,
              child: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
        bottom: TabBar(
          controller: tabs,
          isScrollable: true,
          tabs:
              taskStatuses
                  .map(
                    (status) => Tab(
                      text:
                          '${status.$2} '
                          '${_tasksForStatus(status.$1).length}',
                    ),
                  )
                  .toList(),
        ),
      ),
      floatingActionButton:
          widget.store.activeProjects.isEmpty
              ? null
              : FloatingActionButton.extended(
                onPressed: _add,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Задача'),
              ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SearchBar(
              controller: searchController,
              hintText: 'Поиск по задачам',
              leading: const Icon(Icons.search_rounded),
              trailing: [
                if (query.isNotEmpty)
                  IconButton(
                    onPressed: searchController.clear,
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
          ),
          if (projectFilter != null || priorityFilter != null)
            _ActiveFilters(
              store: widget.store,
              projectId: projectFilter,
              priority: priorityFilter,
              onClearProject: () => setState(() => projectFilter = null),
              onClearPriority: () => setState(() => priorityFilter = null),
            ),
          Expanded(
            child: TabBarView(
              controller: tabs,
              children:
                  taskStatuses
                      .map((status) => _buildTaskList(status.$1))
                      .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(String status) {
    final tasks = _tasksForStatus(status);
    if (tasks.isEmpty) {
      return _EmptyTasks(status: status, filtered: _hasFilters);
    }

    final rootTasks = tasks.where((task) => task.parentTaskId == null).toList();
    final orphanSubtasks =
        tasks.where((task) {
          if (task.parentTaskId == null) return false;
          return !tasks.any((parent) => parent.id == task.parentTaskId);
        }).toList();
    final visibleRoots = [...rootTasks, ...orphanSubtasks];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      itemCount: visibleRoots.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final task = visibleRoots[index];
        final children =
            tasks.where((item) => item.parentTaskId == task.id).toList();
        return _TaskCard(
          task: task,
          children: children,
          project: widget.store.projectById(task.projectId),
          onToggle: (done) {
            widget.store.updateTaskStatus(task, done ? 'done' : 'next');
            setState(() {});
          },
          onEdit: () => _edit(task),
          onDelete: () => _delete(task),
          onStartTimer: () {
            widget.store.startTimer(
              description: task.title,
              projectId: task.projectId,
              taskId: task.id,
              noteId: task.noteId,
            );
          },
          onChildToggle: (child, done) {
            widget.store.updateTaskStatus(child, done ? 'done' : 'next');
            setState(() {});
          },
          onChildEdit: _edit,
        );
      },
    );
  }

  bool get _hasFilters =>
      query.isNotEmpty || projectFilter != null || priorityFilter != null;

  List<WorkTask> _tasksForStatus(String status) {
    final activeIds =
        widget.store.activeProjects.map((item) => item.id).toSet();
    final tasks =
        widget.store.data.tasks.where((task) {
          if (task.status != status) return false;
          if (!activeIds.contains(task.projectId)) return false;
          if (projectFilter != null && task.projectId != projectFilter)
            return false;
          if (priorityFilter != null && task.priority != priorityFilter)
            return false;
          if (query.isNotEmpty &&
              !task.title.toLowerCase().contains(query) &&
              !task.description.toLowerCase().contains(query)) {
            return false;
          }
          return true;
        }).toList();

    tasks.sort((a, b) {
      final priority = b.priority.compareTo(a.priority);
      if (priority != 0) return priority;
      final aDue = a.dueAt;
      final bDue = b.dueAt;
      if (aDue != null && bDue != null) return aDue.compareTo(bDue);
      if (aDue != null) return -1;
      if (bDue != null) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return tasks;
  }

  Future<void> _add() async {
    final task = await TaskEditorSheet.show(
      context,
      projects: widget.store.activeProjects,
      tasks: widget.store.data.tasks,
    );
    if (task == null) return;
    widget.store.addTask(task);
    setState(() {});
  }

  Future<void> _edit(WorkTask task) async {
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

  Future<void> _delete(WorkTask task) async {
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

  Future<void> _showFilters() async {
    var draftProject = projectFilter;
    var draftPriority = priorityFilter;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder:
          (sheetContext) => StatefulBuilder(
            builder:
                (context, setSheetState) => SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Фильтры задач',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 18),
                        DropdownButtonFormField<String?>(
                          initialValue: draftProject,
                          decoration: const InputDecoration(
                            labelText: 'Проект',
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Все проекты'),
                            ),
                            ...widget.store.activeProjects.map(
                              (project) => DropdownMenuItem<String?>(
                                value: project.id,
                                child: Text(
                                  '${project.emoji} ${project.title}',
                                ),
                              ),
                            ),
                          ],
                          onChanged:
                              (value) =>
                                  setSheetState(() => draftProject = value),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int?>(
                          initialValue: draftPriority,
                          decoration: const InputDecoration(
                            labelText: 'Приоритет',
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Любой приоритет'),
                            ),
                            ...taskPriorities.map(
                              (item) => DropdownMenuItem<int?>(
                                value: item.$1,
                                child: Text(item.$2),
                              ),
                            ),
                          ],
                          onChanged:
                              (value) =>
                                  setSheetState(() => draftPriority = value),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    projectFilter = null;
                                    priorityFilter = null;
                                  });
                                  Navigator.pop(sheetContext);
                                },
                                child: const Text('Сбросить'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () {
                                  setState(() {
                                    projectFilter = draftProject;
                                    priorityFilter = draftPriority;
                                  });
                                  Navigator.pop(sheetContext);
                                },
                                child: const Text('Применить'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }
}

class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({
    required this.store,
    required this.projectId,
    required this.priority,
    required this.onClearProject,
    required this.onClearPriority,
  });

  final AppStore store;
  final String? projectId;
  final int? priority;
  final VoidCallback onClearProject;
  final VoidCallback onClearPriority;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      children: [
        if (projectId != null)
          InputChip(
            label: Text(store.projectById(projectId!)?.title ?? 'Проект'),
            onDeleted: onClearProject,
          ),
        if (projectId != null && priority != null) const SizedBox(width: 8),
        if (priority != null)
          InputChip(
            label: Text(taskPriorityLabel(priority!)),
            onDeleted: onClearPriority,
          ),
      ],
    ),
  );
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.children,
    required this.project,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onStartTimer,
    required this.onChildToggle,
    required this.onChildEdit,
  });

  final WorkTask task;
  final List<WorkTask> children;
  final Project? project;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onStartTimer;
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
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (project != null)
                    Text('${project!.emoji} ${project!.title}'),
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
                  if (value == 'timer') onStartTimer();
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder:
                    (_) => const [
                      PopupMenuItem(
                        value: 'timer',
                        child: Text('Запустить таймер'),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Редактировать'),
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        taskPriorityIcon(task.priority),
                        size: 17,
                        color: priorityColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        taskPriorityLabel(task.priority),
                        style: TextStyle(color: priorityColor),
                      ),
                    ],
                  ),
                ),
              ),
            if (children.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 34),
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

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks({required this.status, required this.filtered});

  final String status;
  final bool filtered;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            filtered ? Icons.search_off_rounded : Icons.task_alt_rounded,
            size: 58,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 14),
          Text(
            filtered
                ? 'По фильтрам ничего не найдено'
                : 'Нет задач со статусом «${taskStatusLabel(status)}»',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}
