import 'package:flutter/material.dart';

import 'note_columns_syntax.dart';

class NoteColumnsEditorDialog extends StatefulWidget {
  const NoteColumnsEditorDialog({
    super.key,
    required this.initial,
    required this.editingExisting,
  });

  final NoteColumnsLayout initial;
  final bool editingExisting;

  static Future<NoteColumnsLayout?> show(
    BuildContext context, {
    required NoteColumnsLayout initial,
    required bool editingExisting,
  }) {
    return showDialog<NoteColumnsLayout>(
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

  @override
  void initState() {
    super.initState();
    columnCount = widget.initial.columnCount.clamp(2, 3).toInt();
    widths = NoteColumnsSyntax.normalizeWidths(
      widget.initial.widths,
      columnCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.editingExisting ? 'Настроить колонки' : 'Добавить колонки',
      ),
      content: SizedBox(
        width: 500,
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
              const SizedBox(height: 20),
              Text(
                'Ширина колонок',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              _WidthPreview(widths: widths),
              const SizedBox(height: 14),
              if (columnCount == 2) _twoColumnControls() else _threeColumnControls(),
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed:
              () => Navigator.pop(
                context,
                NoteColumnsLayout(
                  columnCount: columnCount,
                  widths: NoteColumnsSyntax.normalizeWidths(
                    widths,
                    columnCount,
                  ),
                ),
              ),
          child: Text(widget.editingExisting ? 'Применить' : 'Добавить'),
        ),
      ],
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
            setState(() => widths = [left, nextMiddle, 100 - left - nextMiddle]);
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
