import 'package:flutter/material.dart';

import 'note_templates.dart';

enum LaboratoryTemplatePlacement { append, replace }

class LaboratoryTemplateApplication {
  const LaboratoryTemplateApplication({
    required this.template,
    required this.placement,
  });

  final NoteTemplate template;
  final LaboratoryTemplatePlacement placement;
}

String applyLaboratoryTemplateContent({
  required String currentText,
  required String templateContent,
  required LaboratoryTemplatePlacement placement,
}) {
  final normalizedTemplate = templateContent.trimRight();
  if (currentText.trim().isEmpty ||
      placement == LaboratoryTemplatePlacement.replace) {
    return '$normalizedTemplate\n';
  }
  final separator =
      currentText.endsWith('\n\n')
          ? ''
          : currentText.endsWith('\n')
          ? '\n'
          : '\n\n';
  return '$currentText$separator$normalizedTemplate\n';
}

class LaboratoryTemplateDialog extends StatefulWidget {
  const LaboratoryTemplateDialog({
    super.key,
    required this.currentText,
    this.templates = laboratoryNoteTemplates,
  });

  final String currentText;
  final List<NoteTemplate> templates;

  static Future<LaboratoryTemplateApplication?> show(
    BuildContext context, {
    required String currentText,
    List<NoteTemplate> templates = laboratoryNoteTemplates,
  }) {
    return showDialog<LaboratoryTemplateApplication>(
      context: context,
      builder:
          (_) => LaboratoryTemplateDialog(
            currentText: currentText,
            templates: templates,
          ),
    );
  }

  @override
  State<LaboratoryTemplateDialog> createState() =>
      _LaboratoryTemplateDialogState();
}

class _LaboratoryTemplateDialogState extends State<LaboratoryTemplateDialog> {
  late String _selectedTemplateId;
  late LaboratoryTemplatePlacement _placement;

  bool get _hasExistingContent => widget.currentText.trim().isNotEmpty;

  NoteTemplate get _selectedTemplate => widget.templates.firstWhere(
    (template) => template.id == _selectedTemplateId,
  );

  @override
  void initState() {
    super.initState();
    assert(widget.templates.isNotEmpty);
    _selectedTemplateId = widget.templates.first.id;
    _placement =
        _hasExistingContent
            ? LaboratoryTemplatePlacement.append
            : LaboratoryTemplatePlacement.replace;
  }

  @override
  Widget build(BuildContext context) {
    final template = _selectedTemplate;
    final mediaSize = MediaQuery.sizeOf(context);
    final dialogWidth = (mediaSize.width - 48).clamp(360.0, 940.0).toDouble();
    final dialogHeight = (mediaSize.height - 48).clamp(360.0, 680.0).toDouble();

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 16, 14),
              child: Row(
                children: [
                  Icon(Icons.dashboard_customize_outlined),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Шаблон заметки',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Выбери шаблон и проверь его Markdown перед применением. '
                      'Тип, теги и свойства текущей заметки не меняются.',
                    ),
                    if (_hasExistingContent) ...[
                      const SizedBox(height: 10),
                      _ExistingContentWarning(placement: _placement),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          const Text(
                            'Как применить шаблон',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          SegmentedButton<LaboratoryTemplatePlacement>(
                            segments: const [
                              ButtonSegment<LaboratoryTemplatePlacement>(
                                value: LaboratoryTemplatePlacement.append,
                                icon: Icon(Icons.add_rounded),
                                label: Text('В конец'),
                              ),
                              ButtonSegment<LaboratoryTemplatePlacement>(
                                value: LaboratoryTemplatePlacement.replace,
                                icon: Icon(Icons.find_replace_rounded),
                                label: Text('Заменить'),
                              ),
                            ],
                            selected: {_placement},
                            onSelectionChanged: (selection) {
                              setState(() => _placement = selection.first);
                            },
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final templates = _TemplateList(
                            templates: widget.templates,
                            selectedTemplateId: _selectedTemplateId,
                            onSelected: (id) {
                              setState(() => _selectedTemplateId = id);
                            },
                          );
                          final preview = _TemplatePreview(template: template);
                          if (constraints.maxWidth >= 720) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(width: 290, child: templates),
                                const VerticalDivider(width: 24),
                                Expanded(child: preview),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: _selectedTemplateId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Шаблон',
                                ),
                                items: [
                                  for (final item in widget.templates)
                                    DropdownMenuItem<String>(
                                      value: item.id,
                                      child: Text(
                                        '${item.icon}  ${item.title}',
                                      ),
                                    ),
                                ],
                                onChanged: (id) {
                                  if (id != null) {
                                    setState(() => _selectedTemplateId = id);
                                  }
                                },
                              ),
                              const SizedBox(height: 10),
                              Expanded(child: preview),
                            ],
                          );
                        },
                      ),
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
                    icon: const Icon(Icons.dashboard_customize_outlined),
                    label: Text(
                      _hasExistingContent ? 'Применить' : 'Вставить шаблон',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_hasExistingContent) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          final replacing = _placement == LaboratoryTemplatePlacement.replace;
          return AlertDialog(
            title: Text(
              replacing
                  ? 'Заменить содержимое заметки?'
                  : 'Добавить шаблон в конец заметки?',
            ),
            content: Text(
              replacing
                  ? 'Текущий Markdown будет полностью заменён выбранным '
                      'шаблоном. Отмена в этом окне оставит заметку без '
                      'изменений.'
                  : 'Существующий Markdown сохранится, а выбранный шаблон '
                      'будет добавлен после него. Отмена в этом окне оставит '
                      'заметку без изменений.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(replacing ? 'Заменить' : 'Добавить'),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !mounted) {
        return;
      }
    }

    Navigator.pop(
      context,
      LaboratoryTemplateApplication(
        template: _selectedTemplate,
        placement: _placement,
      ),
    );
  }
}

class _ExistingContentWarning extends StatelessWidget {
  const _ExistingContentWarning({required this.placement});

  final LaboratoryTemplatePlacement placement;

  @override
  Widget build(BuildContext context) {
    final replacing = placement == LaboratoryTemplatePlacement.replace;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                replacing
                    ? 'В заметке уже есть текст. Режим «Заменить» удалит '
                        'текущий Markdown только после отдельного подтверждения.'
                    : 'В заметке уже есть текст. По умолчанию шаблон будет '
                        'добавлен в конец, а существующий Markdown сохранится.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateList extends StatelessWidget {
  const _TemplateList({
    required this.templates,
    required this.selectedTemplateId,
    required this.onSelected,
  });

  final List<NoteTemplate> templates;
  final String selectedTemplateId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: templates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final template = templates[index];
        return ListTile(
          selected: template.id == selectedTemplateId,
          selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: Text(template.icon, style: const TextStyle(fontSize: 22)),
          title: Text(template.title),
          subtitle: Text(
            template.isCustom
                ? 'Пользовательский · ${template.defaultTags.length} тегов'
                : '${template.defaultTags.length} тегов · '
                    '${template.defaultProperties.length} свойств',
          ),
          onTap: () => onSelected(template.id),
        );
      },
    );
  }
}

class _TemplatePreview extends StatelessWidget {
  const _TemplatePreview({required this.template});

  final NoteTemplate template;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Text(template.icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Предварительный просмотр Markdown',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Scrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  template.content,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
