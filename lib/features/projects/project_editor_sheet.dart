import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/app_models.dart';

class ProjectEditorSheet extends StatefulWidget {
  const ProjectEditorSheet({super.key, this.project});

  final Project? project;

  static Future<Project?> show(BuildContext context, {Project? project}) {
    return showModalBottomSheet<Project>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => ProjectEditorSheet(project: project),
    );
  }

  @override
  State<ProjectEditorSheet> createState() => _ProjectEditorSheetState();
}

class _ProjectEditorSheetState extends State<ProjectEditorSheet> {
  static const colors = <int>[
    0xFF6750A4,
    0xFF386A20,
    0xFF006A6A,
    0xFF7D5260,
    0xFF8C5000,
    0xFF405D91,
  ];

  late final TextEditingController titleController;
  late final TextEditingController descriptionController;
  late final TextEditingController emojiController;
  late final TextEditingController budgetController;
  late int colorValue;
  DateTime? dueAt;

  @override
  void initState() {
    super.initState();
    final project = widget.project;
    titleController = TextEditingController(text: project?.title ?? '');
    descriptionController = TextEditingController(
      text: project?.description ?? '',
    );
    emojiController = TextEditingController(text: project?.emoji ?? '📁');
    budgetController = TextEditingController(
      text:
          project?.budgetMinutes == null
              ? ''
              : (project!.budgetMinutes! / 60).toStringAsFixed(1),
    );
    colorValue = project?.colorValue ?? colors.first;
    dueAt = project?.dueAt;
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    emojiController.dispose();
    budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                widget.project == null
                    ? 'Новый проект'
                    : 'Редактировать проект',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 82,
                    child: TextField(
                      controller: emojiController,
                      textAlign: TextAlign.center,
                      maxLength: 2,
                      decoration: const InputDecoration(
                        labelText: 'Значок',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: titleController,
                      autofocus: widget.project == null,
                      decoration: const InputDecoration(labelText: 'Название'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Описание'),
              ),
              const SizedBox(height: 18),
              Text('Цвет', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children:
                    colors.map((value) {
                      final selected = value == colorValue;
                      return InkWell(
                        borderRadius: BorderRadius.circular(99),
                        onTap: () => setState(() => colorValue = value),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Color(value),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  selected
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child:
                              selected
                                  ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                  )
                                  : null,
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: budgetController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Бюджет времени, часы',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDueDate,
                      icon: const Icon(Icons.event_rounded),
                      label: Text(
                        dueAt == null
                            ? 'Дедлайн'
                            : '${dueAt!.day}.${dueAt!.month}.${dueAt!.year}',
                      ),
                    ),
                  ),
                ],
              ),
              if (dueAt != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() => dueAt = null),
                    child: const Text('Убрать дедлайн'),
                  ),
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(widget.project == null ? 'Создать' : 'Сохранить'),
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

    final rawBudget = budgetController.text.trim().replaceAll(',', '.');
    final budgetHours = double.tryParse(rawBudget);
    final existing = widget.project;
    final now = DateTime.now();

    Navigator.pop(
      context,
      Project(
        id: existing?.id ?? const Uuid().v4(),
        title: title,
        emoji:
            emojiController.text.trim().isEmpty
                ? '📁'
                : emojiController.text.trim(),
        description: descriptionController.text.trim(),
        colorValue: colorValue,
        dueAt: dueAt,
        budgetMinutes:
            budgetHours == null
                ? null
                : (budgetHours * 60).round().clamp(1, 1000000).toInt(),
        archived: existing?.archived ?? false,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }
}
