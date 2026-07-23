import 'package:flutter/material.dart';

import 'scientific_reference_syntax.dart';

class ScientificTableDialog extends StatefulWidget {
  const ScientificTableDialog({
    super.key,
    required this.existingKeys,
  });

  final Set<String> existingKeys;

  static Future<ScientificTableDraft?> show(
    BuildContext context, {
    required Set<String> existingKeys,
  }) {
    return showDialog<ScientificTableDraft>(
      context: context,
      builder: (context) => ScientificTableDialog(existingKeys: existingKeys),
    );
  }

  @override
  State<ScientificTableDialog> createState() => _ScientificTableDialogState();
}

class _ScientificTableDialogState extends State<ScientificTableDialog> {
  final idController = TextEditingController(text: 'table');
  final captionController = TextEditingController();
  int columns = 3;
  int rows = 2;
  String? idError;

  @override
  void dispose() {
    idController.dispose();
    captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Добавить научную таблицу'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: captionController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Подпись таблицы',
                  hintText: 'Условия эксперимента',
                  prefixIcon: Icon(Icons.short_text_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: idController,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Устойчивый ID',
                  hintText: 'experiment-conditions',
                  prefixIcon: const Icon(Icons.tag_rounded),
                  errorText: idError,
                  helperText:
                      'ID не меняется при перемещении таблицы и используется в @tbl(id).',
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _NumberStepper(
                      label: 'Столбцы',
                      value: columns,
                      minimum: 2,
                      maximum: 8,
                      onChanged: (value) => setState(() => columns = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _NumberStepper(
                      label: 'Строки',
                      value: rows,
                      minimum: 1,
                      maximum: 20,
                      onChanged: (value) => setState(() => rows = value),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.table_chart_outlined),
          label: const Text('Вставить'),
        ),
      ],
    );
  }

  void _submit() {
    final rawId = idController.text.trim();
    final id = ScientificReferenceSyntax.normalizeId(rawId);
    final key = '${ScientificObjectType.table.name}:$id';
    if (rawId.isEmpty) {
      setState(() => idError = 'ID таблицы не может быть пустым.');
      return;
    }
    if (!ScientificReferenceSyntax.isValidId(id)) {
      setState(() => idError = 'Укажи корректный ID таблицы.');
      return;
    }
    if (widget.existingKeys.contains(key)) {
      setState(() => idError = 'Такой ID таблицы уже используется.');
      return;
    }
    Navigator.pop(
      context,
      ScientificTableDraft(
        id: id,
        caption: captionController.text.trim(),
        columns: columns,
        rows: rows,
      ),
    );
  }
}

class ScientificReferencePickerDialog extends StatefulWidget {
  const ScientificReferencePickerDialog({
    super.key,
    required this.objects,
  });

  final List<ScientificObjectReference> objects;

  static Future<ScientificObjectReference?> show(
    BuildContext context, {
    required List<ScientificObjectReference> objects,
  }) {
    return showDialog<ScientificObjectReference>(
      context: context,
      builder: (context) => ScientificReferencePickerDialog(objects: objects),
    );
  }

  @override
  State<ScientificReferencePickerDialog> createState() =>
      _ScientificReferencePickerDialogState();
}

class _ScientificReferencePickerDialogState
    extends State<ScientificReferencePickerDialog> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    final objects = widget.objects.where((object) {
      if (normalized.isEmpty) {
        return true;
      }
      return [
        object.label,
        object.id,
        object.caption,
      ].join(' ').toLowerCase().contains(normalized);
    }).toList();

    return AlertDialog(
      title: const Text('Вставить перекрёстную ссылку'),
      content: SizedBox(
        width: 620,
        height: 480,
        child: Column(
          children: [
            SearchBar(
              hintText: 'Рисунок, таблица, ID или подпись',
              leading: const Icon(Icons.search_rounded),
              onChanged: (value) => setState(() => query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: objects.isEmpty
                  ? const Center(child: Text('Объекты не найдены'))
                  : ListView.separated(
                      itemCount: objects.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final object = objects[index];
                        return ListTile(
                          leading: Icon(
                            object.type == ScientificObjectType.figure
                                ? Icons.image_outlined
                                : Icons.table_chart_outlined,
                          ),
                          title: Text(object.label),
                          subtitle: Text(
                            [
                              object.id,
                              if (object.caption.isNotEmpty) object.caption,
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(object.markdownReference),
                          onTap: () => Navigator.pop(context, object),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}

class ScientificObjectsDialog extends StatelessWidget {
  const ScientificObjectsDialog({
    super.key,
    required this.index,
  });

  final ScientificReferenceIndex index;

  static Future<void> show(
    BuildContext context, {
    required ScientificReferenceIndex index,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => ScientificObjectsDialog(index: index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final figures = index.objects
        .where((object) => object.type == ScientificObjectType.figure)
        .toList();
    final tables = index.objects
        .where((object) => object.type == ScientificObjectType.table)
        .toList();
    final broken = index.brokenCrossReferences;
    final ambiguous = index.ambiguousCrossReferences;

    return AlertDialog(
      title: const Text('Рисунки, таблицы и ссылки'),
      content: SizedBox(
        width: 720,
        height: 560,
        child: ListView(
          children: [
            _SummaryCard(
              figures: figures.length,
              tables: tables.length,
              warnings: index.duplicateKeys.length + broken.length + ambiguous.length,
            ),
            const SizedBox(height: 14),
            if (index.objects.isEmpty)
              const _EmptyCard(
                text:
                    'В заметке пока нет нумерованных рисунков или научных таблиц.',
              )
            else ...[
              if (figures.isNotEmpty)
                _ObjectsSection(title: 'Рисунки', objects: figures),
              if (tables.isNotEmpty)
                _ObjectsSection(title: 'Таблицы', objects: tables),
            ],
            if (index.duplicateKeys.isNotEmpty) ...[
              const SizedBox(height: 14),
              _WarningSection(
                title: 'Повторяющиеся ID',
                icon: Icons.copy_all_outlined,
                lines: index.duplicateKeys.toList()..sort(),
              ),
            ],
            if (broken.isNotEmpty) ...[
              const SizedBox(height: 14),
              _WarningSection(
                title: 'Сломанные ссылки',
                icon: Icons.link_off_rounded,
                lines: [for (final reference in broken) reference.raw],
              ),
            ],
            if (ambiguous.isNotEmpty) ...[
              const SizedBox(height: 14),
              _WarningSection(
                title: 'Неоднозначные ссылки',
                icon: Icons.warning_amber_rounded,
                lines: [for (final reference in ambiguous) reference.raw],
              ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Готово'),
        ),
      ],
    );
  }
}

class _NumberStepper extends StatelessWidget {
  const _NumberStepper({
    required this.label,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int minimum;
  final int maximum;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            IconButton(
              tooltip: 'Уменьшить',
              onPressed: value > minimum ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            SizedBox(
              width: 28,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Увеличить',
              onPressed: value < maximum ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.figures,
    required this.tables,
    required this.warnings,
  });

  final int figures;
  final int tables;
  final int warnings;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [
            Text('Рисунки: $figures'),
            Text('Таблицы: $tables'),
            Text(
              warnings == 0 ? 'Ошибок нет' : 'Предупреждения: $warnings',
              style: TextStyle(
                color: warnings == 0
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ObjectsSection extends StatelessWidget {
  const _ObjectsSection({required this.title, required this.objects});

  final String title;
  final List<ScientificObjectReference> objects;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            for (final object in objects)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(object.label),
                subtitle: Text(
                  [
                    object.id,
                    if (object.caption.isNotEmpty) object.caption,
                  ].join(' · '),
                ),
                trailing: SelectableText(object.markdownReference),
              ),
          ],
        ),
      ),
    );
  }
}

class _WarningSection extends StatelessWidget {
  const _WarningSection({
    required this.title,
    required this.icon,
    required this.lines,
  });

  final String title;
  final IconData icon;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SelectableText(line),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(text),
      ),
    );
  }
}
