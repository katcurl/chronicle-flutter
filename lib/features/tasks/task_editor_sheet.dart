import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/app_models.dart';
import 'task_metadata.dart';

class TaskEditorSheet extends StatefulWidget {
  const TaskEditorSheet({
    super.key,
    required this.projects,
    required this.tasks,
    this.task,
    this.initialProjectId,
    this.initialParentTaskId,
    this.initialNoteId,
  });

  final List<Project> projects;
  final List<WorkTask> tasks;
  final WorkTask? task;
  final String? initialProjectId;
  final String? initialParentTaskId;
  final String? initialNoteId;

  static Future<WorkTask?> show(
    BuildContext context, {
    required List<Project> projects,
    required List<WorkTask> tasks,
    WorkTask? task,
    String? initialProjectId,
    String? initialParentTaskId,
    String? initialNoteId,
  }) {
    return showModalBottomSheet<WorkTask>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 680),
      builder:
          (_) => TaskEditorSheet(
            projects: projects,
            tasks: tasks,
            task: task,
            initialProjectId: initialProjectId,
            initialParentTaskId: initialParentTaskId,
            initialNoteId: initialNoteId,
          ),
    );
  }

  @override
  State<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<TaskEditorSheet> {
  late final TextEditingController titleController;
  late final TextEditingController descriptionController;
  late final TextEditingController estimateController;
  late String projectId;
  late String status;
  late int priority;
  String? parentTaskId;
  DateTime? dueAt;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    titleController = TextEditingController(text: task?.title ?? '');
    descriptionController = TextEditingController(
      text: task?.description ?? '',
    );
    estimateController = TextEditingController(
      text: (task?.estimateMinutes ?? 30).toString(),
    );
    projectId =
        task?.projectId ?? widget.initialProjectId ?? widget.projects.first.id;
    status = task?.status ?? 'next';
    priority = task?.priority ?? 1;
    parentTaskId = task?.parentTaskId ?? widget.initialParentTaskId;
    dueAt = task?.dueAt;
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    estimateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parentCandidates =
        widget.tasks
            .where(
              (item) =>
                  item.projectId == projectId &&
                  item.id != widget.task?.id &&
                  item.parentTaskId == null,
            )
            .toList();

    if (parentTaskId != null &&
        !parentCandidates.any((item) => item.id == parentTaskId)) {
      parentTaskId = null;
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.task == null ? 'Новая задача' : 'Редактировать задачу',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: titleController,
                autofocus: widget.task == null,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Описание или ожидаемый результат',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: projectId,
                decoration: const InputDecoration(labelText: 'Проект'),
                items:
                    widget.projects
                        .map(
                          (project) => DropdownMenuItem<String>(
                            value: project.id,
                            child: Text('${project.emoji} ${project.title}'),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    projectId = value;
                    parentTaskId = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Статус'),
                      items:
                          taskStatuses
                              .map(
                                (item) => DropdownMenuItem<String>(
                                  value: item.$1,
                                  child: Text(item.$2),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => status = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: priority,
                      decoration: const InputDecoration(labelText: 'Приоритет'),
                      items:
                          taskPriorities
                              .map(
                                (item) => DropdownMenuItem<int>(
                                  value: item.$1,
                                  child: Text(item.$2),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => priority = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: estimateController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Оценка, минуты',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDueDate,
                      icon: const Icon(Icons.event_rounded),
                      label: Text(shortDate(dueAt)),
                    ),
                  ),
                ],
              ),
              if (dueAt != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() => dueAt = null),
                    child: const Text('Убрать срок'),
                  ),
                ),
              if (parentCandidates.isNotEmpty) ...[
                const SizedBox(height: 4),
                DropdownButtonFormField<String?>(
                  initialValue: parentTaskId,
                  decoration: const InputDecoration(
                    labelText: 'Родительская задача',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Нет — самостоятельная задача'),
                    ),
                    ...parentCandidates.map(
                      (task) => DropdownMenuItem<String?>(
                        value: task.id,
                        child: Text(task.title),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => parentTaskId = value),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(widget.task == null ? 'Создать' : 'Сохранить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: dueAt ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (selected != null) setState(() => dueAt = selected);
  }

  void _save() {
    final title = titleController.text.trim();
    if (title.isEmpty) return;

    final estimate = int.tryParse(estimateController.text.trim()) ?? 30;
    final existing = widget.task;
    final now = DateTime.now();

    Navigator.pop(
      context,
      WorkTask(
        id: existing?.id ?? const Uuid().v4(),
        title: title,
        projectId: projectId,
        description: descriptionController.text.trim(),
        parentTaskId: parentTaskId,
        noteId: existing?.noteId ?? widget.initialNoteId,
        status: status,
        priority: priority,
        estimateMinutes: estimate.clamp(1, 100000).toInt(),
        sortOrder: existing?.sortOrder ?? 0,
        dueAt: dueAt,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        completedAt: status == 'done' ? existing?.completedAt ?? now : null,
        deletedAt: existing?.deletedAt,
      ),
    );
  }
}
