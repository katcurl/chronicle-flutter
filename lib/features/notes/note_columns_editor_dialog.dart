import 'package:flutter/material.dart';

import 'note_columns_syntax.dart';

class NoteColumnsEditorResult {
  const NoteColumnsEditorResult({
    required this.layout,
    required this.contentOrder,
    this.unwrap = false,
  });

  final NoteColumnsLayout layout;
  final List<int> contentOrder;
  final bool unwrap;
}

class NoteColumnsEditorDialog extends StatefulWidget {
  const NoteColumnsEditorDialog({
    super.key,
    required this.initial,
    required this.editingExisting,
  });

  final NoteColumnsLayout initial;
  final bool editingExisting;

  static Future<NoteColumnsEditorResult?> show(
    BuildContext context, {
    required NoteColumnsLayout initial,
    required bool editingExisting,
  }) {
    return showDialog<NoteColumnsEditorResult>(
      context: context,
      builder:
          (context) => NoteColumnsEditorDialog(
            initial: initial,
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
  late List<int> contentOrder;

  @override
  void initState() {
    super.initState();
    columnCount = widget.initial.columnCount.clamp(2, 3).toInt();
    widths = NoteColumnsSyntax.normalizeWidths(
      widget.initial.widths,
      columnCount,
    );
    contentOrder = [
      for (var index = 0; index < columnCount; index += 1) index,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.editingExisting ? 'Управление колонками' : 'Добавить колонки',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                  final next = selection.first;
                  setState(() {
                    columnCount = next;
                    widths = NoteColumnsSyntax.normalizeWidths(
                      next == 2 ? const [50, 50] : const [34, 33, 33],
                      next,
                    );
                  });
                },
              ),
              if (widget.editingExisting) ...[
                const SizedBox(height: 20),
                Text(
                  'Порядок существующего содержимого',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 10),
                _contentOrderControls(context),
                const SizedBox(height: 8),
                Text(
                  'Стрелки перемещают содержимое колонок, не изменяя сам текст. '
                  'При переходе с трёх колонок на две последняя будет добавлена '
                  'в конец второй.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
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
                          _preset('50 / 50', const [50, 50]),
                          _preset('40 / 60', const [40, 60]),
                          _preset('60 / 40', const [60, 40]),
                          _preset('35 / 65', const [35, 65]),
                        ]
                        : [
                          _preset('Равные', const [34, 33, 33]),
                          _preset('25 / 50 / 25', const [25, 50, 25]),
                          _preset('40 / 30 / 30', const [40, 30, 30]),
                          _preset('30 / 30 / 40', const [30, 30, 40]),
                        ],
              ),
              const SizedBox(height: 16),
              Text(
                'На узком экране колонки автоматически расположатся одна под другой.',
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
          onPressed: () => Navigator.pop(
            context,
            NoteColumnsEditorResult(
              layout: NoteColumnsLayout(
                columnCount: columnCount,
                widths: NoteColumnsSyntax.normalizeWidths(
                  widths,
                  columnCount,
                ),
              ),
              contentOrder: List<int>.unmodifiable(contentOrder),
            ),
          ),
          child: Text(widget.editingExisting ? 'Применить' : 'Добавить'),
        ),
      ],
    );
  }

  Widget _contentOrderControls(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var position = 0; position < contentOrder.length; position += 1)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: position < contentOrder.length - 1 ? 8 : 0,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Колонка ${contentOrder[position] + 1}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Переместить левее',
                          visualDensity: VisualDensity.compact,
                          onPressed:
                              position > 0
                                  ? () => _moveContent(position, position - 1)
                                  : null,
                          icon: const Icon(Icons.arrow_back_rounded, size: 19),
                        ),
                        IconButton(
                          tooltip: 'Переместить правее',
                          visualDensity: VisualDensity.compact,
                          onPressed:
                              position < contentOrder.length - 1
                                  ? () => _moveContent(position, position + 1)
                                  : null,
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 19,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _moveContent(int from, int to) {
    if (from < 0 ||
        from >= contentOrder.length ||
        to < 0 ||
        to >= contentOrder.length ||
        from == to) {
      return;
    }
    setState(() {
      final value = contentOrder.removeAt(from);
      contentOrder.insert(to, value);
    });
  }

  Future<void> _confirmUnwrap() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Убрать колонки?'),
            content: const Text(
              'Содержимое останется в заметке и будет расположено подряд '
              'обычным Markdown-текстом.',
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
    Navigator.pop(
      context,
      NoteColumnsEditorResult(
        layout: NoteColumnsLayout(
          columnCount: columnCount,
          widths: NoteColumnsSyntax.normalizeWidths(widths, columnCount),
        ),
        contentOrder: List<int>.unmodifiable(contentOrder),
        unwrap: true,
      ),
    );
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

  Widget _preset(String label, List<int> values) {
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
