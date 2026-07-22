import 'package:flutter/material.dart';

import 'note_columns_syntax.dart';

class NoteColumnsEditorResult {
  const NoteColumnsEditorResult({
    required this.layout,
    required this.contents,
    this.unwrap = false,
  });

  final NoteColumnsLayout layout;
  final List<String> contents;
  final bool unwrap;
}

class NoteColumnsEditorDialog extends StatefulWidget {
  const NoteColumnsEditorDialog({
    super.key,
    required this.initial,
    required this.initialContents,
    required this.editingExisting,
  });

  final NoteColumnsLayout initial;
  final List<String> initialContents;
  final bool editingExisting;

  static Future<NoteColumnsEditorResult?> show(
    BuildContext context, {
    required NoteColumnsLayout initial,
    required List<String> initialContents,
    required bool editingExisting,
  }) {
    return showDialog<NoteColumnsEditorResult>(
      context: context,
      builder:
          (context) => NoteColumnsEditorDialog(
            initial: initial,
            initialContents: initialContents,
            editingExisting: editingExisting,
          ),
    );
  }

  @override
  State<NoteColumnsEditorDialog> createState() =>
      _NoteColumnsEditorDialogState();
}

class _NoteColumnsEditorDialogState extends State<NoteColumnsEditorDialog> {
  late int columnCount;
  late List<int> widths;
  final List<TextEditingController> contentControllers = [];

  @override
  void initState() {
    super.initState();
    columnCount = widget.initial.columnCount.clamp(2, 3).toInt();
    widths = NoteColumnsSyntax.normalizeWidths(
      widget.initial.widths,
      columnCount,
    );
    _replaceContentControllers(
      NoteColumnsSyntax.normalizeContents(
        widget.initialContents,
        columnCount,
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in contentControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = (availableWidth - 96).clamp(420.0, 920.0).toDouble();

    return AlertDialog(
      title: Text(
        widget.editingExisting
            ? 'Редактор колонок'
            : 'Создать блок колонок',
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Быстрые макеты',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _layoutPreset(
                    icon: Icons.image_outlined,
                    label: 'Рисунок слева + текст',
                    count: 2,
                    values: const [40, 60],
                  ),
                  _layoutPreset(
                    icon: Icons.notes_rounded,
                    label: 'Текст + рисунок справа',
                    count: 2,
                    values: const [60, 40],
                  ),
                  _layoutPreset(
                    icon: Icons.view_column_outlined,
                    label: 'Две равные',
                    count: 2,
                    values: const [50, 50],
                  ),
                  _layoutPreset(
                    icon: Icons.view_week_outlined,
                    label: 'Три равные',
                    count: 3,
                    values: const [34, 33, 33],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Количество колонок',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment<int>(
                    value: 2,
                    icon: Icon(Icons.view_column_outlined),
                    label: Text('2'),
                  ),
                  ButtonSegment<int>(
                    value: 3,
                    icon: Icon(Icons.view_week_outlined),
                    label: Text('3'),
                  ),
                ],
                selected: {columnCount},
                onSelectionChanged: (selection) {
                  _setColumnCount(selection.first);
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Содержимое колонок',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    'Markdown',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Каждую колонку можно редактировать отдельно. Стрелки меняют '
                'порядок содержимого вместе с изображениями, подписями, '
                'формулами и списками.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _contentEditors(context),
              const SizedBox(height: 20),
              Text(
                'Ширина колонок',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              _WidthPreview(widths: widths),
              const SizedBox(height: 14),
              if (columnCount == 2)
                _twoColumnControls()
              else
                _threeColumnControls(),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    columnCount == 2
                        ? [
                          _widthPreset('50 / 50', const [50, 50]),
                          _widthPreset('40 / 60', const [40, 60]),
                          _widthPreset('60 / 40', const [60, 40]),
                          _widthPreset('35 / 65', const [35, 65]),
                        ]
                        : [
                          _widthPreset('Равные', const [34, 33, 33]),
                          _widthPreset('25 / 50 / 25', const [25, 50, 25]),
                          _widthPreset('40 / 30 / 30', const [40, 30, 30]),
                          _widthPreset('30 / 30 / 40', const [30, 30, 40]),
                        ],
              ),
              const SizedBox(height: 16),
              Text(
                'На узком экране колонки автоматически расположатся одна под '
                'другой. Формат заметки остаётся переносимым Markdown.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.editingExisting)
          TextButton.icon(
            onPressed: _confirmUnwrap,
            icon: const Icon(Icons.view_stream_outlined),
            label: const Text('Сделать обычным текстом'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _result()),
          child: Text(widget.editingExisting ? 'Применить' : 'Добавить'),
        ),
      ],
    );
  }

  Widget _contentEditors(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= 720;
        final cards = [
          for (var index = 0; index < contentControllers.length; index += 1)
            _contentCard(context, index),
        ];
        if (!horizontal) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < cards.length; index += 1) ...[
                cards[index],
                if (index < cards.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < cards.length; index += 1) ...[
              Expanded(child: cards[index]),
              if (index < cards.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      },
    );
  }

  Widget _contentCard(BuildContext context, int index) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Колонка ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Переместить левее',
                visualDensity: VisualDensity.compact,
                onPressed: index > 0 ? () => _moveContent(index, index - 1) : null,
                icon: const Icon(Icons.arrow_back_rounded, size: 19),
              ),
              IconButton(
                tooltip: 'Переместить правее',
                visualDensity: VisualDensity.compact,
                onPressed:
                    index < contentControllers.length - 1
                        ? () => _moveContent(index, index + 1)
                        : null,
                icon: const Icon(Icons.arrow_forward_rounded, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: contentControllers[index],
            minLines: 7,
            maxLines: 12,
            keyboardType: TextInputType.multiline,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText:
                  index == 0
                      ? 'Изображение, таблица или текст'
                      : 'Текст колонки ${index + 1}',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  NoteColumnsEditorResult _result({bool unwrap = false}) {
    return NoteColumnsEditorResult(
      layout: NoteColumnsLayout(
        columnCount: columnCount,
        widths: NoteColumnsSyntax.normalizeWidths(widths, columnCount),
      ),
      contents: List<String>.unmodifiable(_currentContents()),
      unwrap: unwrap,
    );
  }

  List<String> _currentContents() {
    return [for (final controller in contentControllers) controller.text];
  }

  void _setColumnCount(int next) {
    final safeNext = next.clamp(2, 3).toInt();
    _applyColumnCount(
      safeNext,
      safeNext == 2 ? const [50, 50] : const [34, 33, 33],
    );
  }

  void _applyLayoutPreset(int count, List<int> values) {
    _applyColumnCount(count.clamp(2, 3).toInt(), values);
  }

  void _applyColumnCount(int next, List<int> nextWidths) {
    final normalized = NoteColumnsSyntax.normalizeContents(
      _currentContents(),
      next,
    );
    final removed = <TextEditingController>[];
    setState(() {
      final shared = contentControllers.length < next
          ? contentControllers.length
          : next;
      for (var index = 0; index < shared; index += 1) {
        contentControllers[index].text = normalized[index];
      }
      while (contentControllers.length < next) {
        contentControllers.add(
          TextEditingController(text: normalized[contentControllers.length]),
        );
      }
      if (contentControllers.length > next) {
        removed.addAll(contentControllers.sublist(next));
        contentControllers.removeRange(next, contentControllers.length);
      }
      columnCount = next;
      widths = NoteColumnsSyntax.normalizeWidths(nextWidths, next);
    });
    if (removed.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final controller in removed) {
          controller.dispose();
        }
      });
    }
  }

  void _replaceContentControllers(List<String> contents) {
    for (final controller in contentControllers) {
      controller.dispose();
    }
    contentControllers
      ..clear()
      ..addAll([
        for (final content in contents)
          TextEditingController(text: content),
      ]);
  }

  void _moveContent(int from, int to) {
    if (from < 0 ||
        from >= contentControllers.length ||
        to < 0 ||
        to >= contentControllers.length ||
        from == to) {
      return;
    }
    setState(() {
      final controller = contentControllers.removeAt(from);
      contentControllers.insert(to, controller);
    });
  }

  Future<void> _confirmUnwrap() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Убрать колонки?'),
            content: const Text(
              'Отредактированное содержимое останется в заметке и будет '
              'расположено подряд обычным Markdown-текстом.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Убрать колонки'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    Navigator.pop(context, _result(unwrap: true));
  }

  Widget _twoColumnControls() {
    final left = widths[0];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Левая колонка: $left%'),
        Slider(
          value: left.toDouble(),
          min: 20,
          max: 80,
          divisions: 12,
          label: '$left%',
          onChanged: (value) {
            final rounded = ((value / 5).round() * 5).clamp(20, 80).toInt();
            setState(() => widths = [rounded, 100 - rounded]);
          },
        ),
      ],
    );
  }

  Widget _threeColumnControls() {
    final left = widths[0];
    final middle = widths[1];
    final right = widths[2];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Левая колонка: $left%'),
        Slider(
          value: left.toDouble(),
          min: 15,
          max: 70,
          divisions: 11,
          label: '$left%',
          onChanged: (value) {
            final nextLeft = ((value / 5).round() * 5).clamp(15, 70).toInt();
            final remaining = 100 - nextLeft;
            final currentTail = middle + right;
            final nextMiddle =
                currentTail == 0
                    ? remaining ~/ 2
                    : (middle / currentTail * remaining).round();
            setState(() {
              widths = NoteColumnsSyntax.normalizeWidths(
                [nextLeft, nextMiddle, remaining - nextMiddle],
                3,
              );
            });
          },
        ),
        Text('Средняя колонка: $middle%'),
        Slider(
          value: middle.toDouble(),
          min: 15,
          max: (85 - left).clamp(15, 70).toDouble(),
          divisions:
              ((85 - left).clamp(15, 70) - 15) ~/ 5 > 0
                  ? ((85 - left).clamp(15, 70) - 15) ~/ 5
                  : null,
          label: '$middle%',
          onChanged: (value) {
            final maximum = 85 - left;
            final nextMiddle =
                ((value / 5).round() * 5).clamp(15, maximum).toInt();
            setState(() {
              widths = [left, nextMiddle, 100 - left - nextMiddle];
            });
          },
        ),
      ],
    );
  }

  Widget _layoutPreset({
    required IconData icon,
    required String label,
    required int count,
    required List<int> values,
  }) {
    return OutlinedButton.icon(
      onPressed: () => _applyLayoutPreset(count, values),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Widget _widthPreset(String label, List<int> values) {
    return OutlinedButton(
      onPressed: () {
        setState(() {
          widths = NoteColumnsSyntax.normalizeWidths(values, columnCount);
        });
      },
      child: Text(label),
    );
  }
}

class _WidthPreview extends StatelessWidget {
  const _WidthPreview({required this.widths});

  final List<int> widths;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          for (var index = 0; index < widths.length; index += 1) ...[
            Expanded(
              flex: widths[index],
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Text(
                  '${widths[index]}%',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            if (index < widths.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
