import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'note_table_syntax.dart';
import 'scientific_reference_syntax.dart';

class ScientificTableEditorDialog extends StatefulWidget {
  const ScientificTableEditorDialog({
    super.key,
    required this.existingKeys,
    this.initialTable,
  });

  final Set<String> existingKeys;
  final NoteTableModel? initialTable;

  static Future<NoteTableModel?> show(
    BuildContext context, {
    required Set<String> existingKeys,
    NoteTableModel? initialTable,
  }) {
    return showDialog<NoteTableModel>(
      context: context,
      builder: (context) => ScientificTableEditorDialog(
        existingKeys: existingKeys,
        initialTable: initialTable,
      ),
    );
  }

  @override
  State<ScientificTableEditorDialog> createState() =>
      _ScientificTableEditorDialogState();
}

class _ScientificTableEditorDialogState
    extends State<ScientificTableEditorDialog> {
  late final TextEditingController idController;
  late final TextEditingController captionController;
  final horizontalController = ScrollController();
  final verticalController = ScrollController();
  final List<List<TextEditingController>> cellControllers = [];
  final List<NoteTableAlignment> alignments = [];

  String? idError;
  bool clipboardBusy = false;

  bool get isEditing => widget.initialTable != null;
  int get columnCount => cellControllers.first.length;
  int get bodyRowCount => cellControllers.length - 1;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTable ??
        NoteTableModel(
          id: 'table',
          caption: '',
          headers: const ['Столбец 1', 'Столбец 2', 'Столбец 3'],
          rows: const [
            ['', '', ''],
            ['', '', ''],
          ],
        );
    idController = TextEditingController(text: initial.id);
    captionController = TextEditingController(text: initial.caption);
    _replaceGrid([initial.headers, ...initial.rows], initial.alignments);
  }

  @override
  void dispose() {
    idController.dispose();
    captionController.dispose();
    horizontalController.dispose();
    verticalController.dispose();
    _disposeCells();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = (size.width - 72).clamp(620.0, 1060.0).toDouble();
    final height = (size.height - 100).clamp(520.0, 760.0).toDouble();

    return AlertDialog(
      title: Text(isEditing ? 'Редактировать научную таблицу' : 'Добавить научную таблицу'),
      content: SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: captionController,
                    autofocus: !isEditing,
                    decoration: const InputDecoration(
                      labelText: 'Подпись таблицы',
                      hintText: 'Условия эксперимента',
                      prefixIcon: Icon(Icons.short_text_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: idController,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'Устойчивый ID',
                      hintText: 'experiment-conditions',
                      prefixIcon: const Icon(Icons.tag_rounded),
                      errorText: idError,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: clipboardBusy ? null : _pasteClipboard,
                    icon: clipboardBusy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.content_paste_rounded),
                    label: const Text('Вставить из Excel/CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: bodyRowCount < NoteTableSyntax.maxRows ? _addRow : null,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Строка'),
                  ),
                  OutlinedButton.icon(
                    onPressed: columnCount < NoteTableSyntax.maxColumns ? _addColumn : null,
                    icon: const Icon(Icons.view_column_outlined),
                    label: const Text('Столбец'),
                  ),
                  Text(
                    '$columnCount столбц. · $bodyRowCount строк',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Scrollbar(
                  controller: verticalController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: verticalController,
                    child: Scrollbar(
                      controller: horizontalController,
                      thumbVisibility: true,
                      notificationPredicate: (notification) => notification.depth == 1,
                      child: SingleChildScrollView(
                        controller: horizontalController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 22),
                        child: _buildGrid(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Первая строка — заголовки. Вставка диапазона заменяет текущую сетку; исходный Markdown остаётся переносимым.',
              ),
            ),
          ],
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
          label: Text(isEditing ? 'Сохранить таблицу' : 'Вставить таблицу'),
        ),
      ],
    );
  }

  Widget _buildGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 48),
            for (var column = 0; column < columnCount; column += 1)
              _HeaderCell(
                controller: cellControllers[0][column],
                column: column,
                alignment: alignments[column],
                canRemove: columnCount > NoteTableSyntax.minColumns,
                onAlignmentChanged: (value) {
                  setState(() => alignments[column] = value);
                },
                onRemove: () => _removeColumn(column),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (var row = 1; row < cellControllers.length; row += 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 48,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text('${row}.'),
                      ),
                      IconButton(
                        tooltip: 'Удалить строку',
                        onPressed: bodyRowCount > NoteTableSyntax.minRows
                            ? () => _removeRow(row)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline_rounded, size: 19),
                      ),
                    ],
                  ),
                ),
                for (var column = 0; column < columnCount; column += 1)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 176,
                      child: TextField(
                        controller: cellControllers[row][column],
                        minLines: 1,
                        maxLines: 3,
                        textAlign: _textAlign(alignments[column]),
                        decoration: InputDecoration(
                          hintText: 'Значение',
                          isDense: true,
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _pasteClipboard() async {
    setState(() => clipboardBusy = true);
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final parsed = NoteTableSyntax.parseClipboard(data?.text ?? '');
      if (!mounted) {
        return;
      }
      if (parsed.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('В буфере нет табличных текстовых данных.')),
        );
        return;
      }
      final rows = parsed.rows;
      final headers = rows.first;
      final body = rows.length > 1
          ? rows.skip(1).toList()
          : [List<String>.filled(headers.length, '')];
      setState(() {
        _replaceGrid(
          [headers, ...body],
          List<NoteTableAlignment>.filled(headers.length, NoteTableAlignment.left),
        );
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось прочитать таблицу из буфера: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => clipboardBusy = false);
      }
    }
  }

  void _addRow() {
    setState(() {
      cellControllers.add([
        for (var column = 0; column < columnCount; column += 1)
          TextEditingController(),
      ]);
    });
  }

  void _removeRow(int row) {
    if (bodyRowCount <= NoteTableSyntax.minRows) {
      return;
    }
    setState(() {
      final removed = cellControllers.removeAt(row);
      for (final controller in removed) {
        controller.dispose();
      }
    });
  }

  void _addColumn() {
    setState(() {
      final next = columnCount + 1;
      for (var row = 0; row < cellControllers.length; row += 1) {
        cellControllers[row].add(
          TextEditingController(text: row == 0 ? 'Столбец $next' : ''),
        );
      }
      alignments.add(NoteTableAlignment.left);
    });
  }

  void _removeColumn(int column) {
    if (columnCount <= NoteTableSyntax.minColumns) {
      return;
    }
    setState(() {
      for (final row in cellControllers) {
        row.removeAt(column).dispose();
      }
      alignments.removeAt(column);
    });
  }

  void _replaceGrid(
    List<List<String>> source,
    List<NoteTableAlignment> sourceAlignments,
  ) {
    _disposeCells();
    cellControllers.clear();
    alignments.clear();

    final width = source.fold<int>(0, (maximum, row) => row.length > maximum ? row.length : maximum)
        .clamp(NoteTableSyntax.minColumns, NoteTableSyntax.maxColumns)
        .toInt();
    final limitedRows = source.take(NoteTableSyntax.maxRows + 1).toList();
    if (limitedRows.isEmpty) {
      limitedRows.add(List<String>.filled(width, ''));
    }
    while (limitedRows.length < 2) {
      limitedRows.add(List<String>.filled(width, ''));
    }
    for (var rowIndex = 0; rowIndex < limitedRows.length; rowIndex += 1) {
      final row = limitedRows[rowIndex];
      cellControllers.add([
        for (var column = 0; column < width; column += 1)
          TextEditingController(
            text: column < row.length
                ? row[column]
                : rowIndex == 0
                    ? 'Столбец ${column + 1}'
                    : '',
          ),
      ]);
    }
    for (var column = 0; column < width; column += 1) {
      alignments.add(
        column < sourceAlignments.length
            ? sourceAlignments[column]
            : NoteTableAlignment.left,
      );
    }
  }

  void _disposeCells() {
    for (final row in cellControllers) {
      for (final controller in row) {
        controller.dispose();
      }
    }
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
      NoteTableModel(
        id: id,
        caption: captionController.text.trim(),
        headers: [for (final controller in cellControllers.first) controller.text],
        rows: [
          for (final row in cellControllers.skip(1))
            [for (final controller in row) controller.text],
        ],
        alignments: alignments,
      ),
    );
  }

  TextAlign _textAlign(NoteTableAlignment alignment) {
    return switch (alignment) {
      NoteTableAlignment.left => TextAlign.left,
      NoteTableAlignment.center => TextAlign.center,
      NoteTableAlignment.right => TextAlign.right,
    };
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.controller,
    required this.column,
    required this.alignment,
    required this.canRemove,
    required this.onAlignmentChanged,
    required this.onRemove,
  });

  final TextEditingController controller;
  final int column;
  final NoteTableAlignment alignment;
  final bool canRemove;
  final ValueChanged<NoteTableAlignment> onAlignmentChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: 176,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Столбец ${column + 1}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                PopupMenuButton<NoteTableAlignment>(
                  tooltip: 'Выравнивание столбца',
                  initialValue: alignment,
                  onSelected: onAlignmentChanged,
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: NoteTableAlignment.left,
                      child: ListTile(
                        leading: Icon(Icons.format_align_left_rounded),
                        title: Text('По левому краю'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: NoteTableAlignment.center,
                      child: ListTile(
                        leading: Icon(Icons.format_align_center_rounded),
                        title: Text('По центру'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: NoteTableAlignment.right,
                      child: ListTile(
                        leading: Icon(Icons.format_align_right_rounded),
                        title: Text('По правому краю'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                  icon: Icon(_alignmentIcon(alignment), size: 19),
                ),
                IconButton(
                  tooltip: 'Удалить столбец',
                  onPressed: canRemove ? onRemove : null,
                  icon: const Icon(Icons.remove_circle_outline_rounded, size: 19),
                ),
              ],
            ),
            TextField(
              controller: controller,
              minLines: 1,
              maxLines: 2,
              textAlign: _textAlign(alignment),
              style: const TextStyle(fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'Заголовок',
                isDense: true,
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _alignmentIcon(NoteTableAlignment alignment) {
    return switch (alignment) {
      NoteTableAlignment.left => Icons.format_align_left_rounded,
      NoteTableAlignment.center => Icons.format_align_center_rounded,
      NoteTableAlignment.right => Icons.format_align_right_rounded,
    };
  }

  static TextAlign _textAlign(NoteTableAlignment alignment) {
    return switch (alignment) {
      NoteTableAlignment.left => TextAlign.left,
      NoteTableAlignment.center => TextAlign.center,
      NoteTableAlignment.right => TextAlign.right,
    };
  }
}
