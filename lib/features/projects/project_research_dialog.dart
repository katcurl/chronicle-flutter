import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import 'project_research.dart';

class ProjectResearchUpdate {
  const ProjectResearchUpdate({
    required this.researchGoal,
    required this.researchQuestions,
    required this.knownFindings,
    required this.openChecks,
    required this.pinnedNoteIds,
    required this.linkedSourceIds,
  });

  final String researchGoal;
  final List<String> researchQuestions;
  final List<String> knownFindings;
  final List<String> openChecks;
  final List<String> pinnedNoteIds;
  final List<String> linkedSourceIds;
}

class ProjectResearchEditorSheet extends StatefulWidget {
  const ProjectResearchEditorSheet({
    super.key,
    required this.project,
    required this.notes,
    required this.sources,
  });

  final Project project;
  final List<Note> notes;
  final List<CitationSource> sources;

  static Future<ProjectResearchUpdate?> show(
    BuildContext context, {
    required Project project,
    required List<Note> notes,
    required List<CitationSource> sources,
  }) {
    return showModalBottomSheet<ProjectResearchUpdate>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 760),
      builder: (_) => ProjectResearchEditorSheet(
        project: project,
        notes: notes,
        sources: sources,
      ),
    );
  }

  @override
  State<ProjectResearchEditorSheet> createState() =>
      _ProjectResearchEditorSheetState();
}

class _ProjectResearchEditorSheetState
    extends State<ProjectResearchEditorSheet> {
  late final TextEditingController goalController;
  late final TextEditingController questionsController;
  late final TextEditingController knownController;
  late final TextEditingController checksController;
  late final Set<String> pinnedNoteIds;
  late final Set<String> linkedSourceIds;

  @override
  void initState() {
    super.initState();
    goalController = TextEditingController(text: widget.project.researchGoal);
    questionsController = TextEditingController(
      text: projectResearchLinesText(widget.project.researchQuestions),
    );
    knownController = TextEditingController(
      text: projectResearchLinesText(widget.project.knownFindings),
    );
    checksController = TextEditingController(
      text: projectResearchLinesText(widget.project.openChecks),
    );
    pinnedNoteIds = widget.project.pinnedNoteIds.toSet();
    linkedSourceIds = widget.project.linkedSourceIds.toSet();
  }

  @override
  void dispose() {
    goalController.dispose();
    questionsController.dispose();
    knownController.dispose();
    checksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final notes = List<Note>.from(widget.notes)
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    final sources = List<CitationSource>.from(widget.sources)
      ..sort((left, right) => left.title.toLowerCase().compareTo(
            right.title.toLowerCase(),
          ));

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Исследовательская страница',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Chronicle хранит твою структуру, но не навязывает этапы или тип лабораторного процесса.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: goalController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Цель проекта',
                  hintText: 'Что должно стать понятнее, доказано или собрано?',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              _linesField(
                controller: questionsController,
                label: 'Исследовательские вопросы',
                hint: 'Один вопрос на строку',
              ),
              const SizedBox(height: 14),
              _linesField(
                controller: knownController,
                label: 'Что уже известно',
                hint: 'Одно утверждение или результат на строку',
              ),
              const SizedBox(height: 14),
              _linesField(
                controller: checksController,
                label: 'Что ещё нужно проверить',
                hint: 'Одна проверка или неопределённость на строку',
              ),
              const SizedBox(height: 18),
              _selectionSection(
                title: 'Закреплённые результаты',
                subtitle: 'Выбери заметки, которые должны оставаться на главной странице проекта.',
                emptyLabel: 'В проекте пока нет заметок.',
                children: [
                  for (final note in notes)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: pinnedNoteIds.contains(note.id),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            pinnedNoteIds.add(note.id);
                          } else {
                            pinnedNoteIds.remove(note.id);
                          }
                        });
                      },
                      title: Text(note.title),
                      subtitle: Text(note.noteType),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _selectionSection(
                title: 'Связанные источники',
                subtitle: 'Отметь источники из общей библиотеки, относящиеся к этому проекту.',
                emptyLabel: 'Библиотека источников пока пуста.',
                children: [
                  for (final source in sources)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: linkedSourceIds.contains(source.id),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            linkedSourceIds.add(source.id);
                          } else {
                            linkedSourceIds.remove(source.id);
                          }
                        });
                      },
                      title: Text(source.title),
                      subtitle: Text(_sourceSubtitle(source)),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Сохранить исследовательскую страницу'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linesField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      minLines: 3,
      maxLines: 8,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: true,
      ),
    );
  }

  Widget _selectionSection({
    required String title,
    required String subtitle,
    required String emptyLabel,
    required List<Widget> children,
  }) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Text(title),
      subtitle: Text(subtitle),
      children: children.isEmpty
          ? <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(emptyLabel),
                ),
              ),
            ]
          : children,
    );
  }

  String _sourceSubtitle(CitationSource source) {
    final parts = <String>[];
    if (source.authors.isNotEmpty) parts.add(source.authors.first);
    if (source.year != null) parts.add('${source.year}');
    if (source.citationKey.trim().isNotEmpty) parts.add(source.citationKey);
    return parts.isEmpty ? source.sourceType : parts.join(' · ');
  }

  void _save() {
    final validNoteIds = widget.notes.map((note) => note.id).toSet();
    final validSourceIds = widget.sources.map((source) => source.id).toSet();
    Navigator.pop(
      context,
      ProjectResearchUpdate(
        researchGoal: goalController.text.trim(),
        researchQuestions: projectResearchLines(questionsController.text),
        knownFindings: projectResearchLines(knownController.text),
        openChecks: projectResearchLines(checksController.text),
        pinnedNoteIds: pinnedNoteIds
            .where(validNoteIds.contains)
            .toList(growable: false),
        linkedSourceIds: linkedSourceIds
            .where(validSourceIds.contains)
            .toList(growable: false),
      ),
    );
  }
}

class ProjectTemplateSelection {
  const ProjectTemplateSelection({required this.template, required this.title});

  final ProjectResearchTemplate template;
  final String title;
}

class ProjectTemplatePickerSheet extends StatefulWidget {
  const ProjectTemplatePickerSheet({super.key});

  static Future<ProjectTemplateSelection?> show(BuildContext context) {
    return showModalBottomSheet<ProjectTemplateSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 680),
      builder: (_) => const ProjectTemplatePickerSheet(),
    );
  }

  @override
  State<ProjectTemplatePickerSheet> createState() =>
      _ProjectTemplatePickerSheetState();
}

class _ProjectTemplatePickerSheetState extends State<ProjectTemplatePickerSheet> {
  ProjectResearchTemplate? selected;
  late final TextEditingController titleController;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController();
  }

  @override
  void dispose() {
    titleController.dispose();
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
                'Создать из шаблона',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              const Text('Шаблон только задаёт стартовые вопросы. Его можно полностью переписать.'),
              const SizedBox(height: 16),
              for (final template in projectResearchTemplates) ...[
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: RadioListTile<ProjectResearchTemplate>(
                    value: template,
                    groupValue: selected,
                    onChanged: (value) {
                      setState(() {
                        selected = value;
                        if (titleController.text.trim().isEmpty && value != null) {
                          titleController.text = value.title;
                        }
                      });
                    },
                    title: Text('${template.emoji}  ${template.title}'),
                    subtitle: Text(template.description),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Название проекта'),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: selected == null ? null : _save,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Создать проект'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    final template = selected;
    final title = titleController.text.trim();
    if (template == null || title.isEmpty) return;
    Navigator.pop(
      context,
      ProjectTemplateSelection(template: template, title: title),
    );
  }
}
