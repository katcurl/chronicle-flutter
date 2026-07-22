import 'package:flutter/material.dart';

import 'note_data_import.dart';

class NoteDataImportDialog extends StatefulWidget {
  const NoteDataImportDialog({
    super.key,
    required this.files,
  });

  final List<NoteDataImportFile> files;

  static Future<NoteDataImportPlan?> show(
    BuildContext context, {
    required List<NoteDataImportFile> files,
  }) {
    return showDialog<NoteDataImportPlan>(
      context: context,
      builder: (context) => NoteDataImportDialog(files: files),
    );
  }

  @override
  State<NoteDataImportDialog> createState() => _NoteDataImportDialogState();
}

class _NoteDataImportDialogState extends State<NoteDataImportDialog> {
  late final TextEditingController titleController;
  late final ClipboardTableData? tablePreview;
  late NoteDataImportMode mode;
  bool showImagePreviews = true;

  bool get canImportAsTable => tablePreview?.isEmpty == false;

  @override
  void initState() {
    super.initState();
    tablePreview = widget.files.length == 1 && widget.files.single.isTabular
        ? NoteDataImport.parseTableFile(widget.files.single)
        : null;
    titleController = TextEditingController(
      text: NoteDataImport.defaultTitle(widget.files),
    );
    mode = canImportAsTable
        ? NoteDataImportMode.tableWithSource
        : NoteDataImportMode.attachmentBundle;
  }

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalBytes = widget.files.fold<int>(
      0,
      (sum, file) => sum + file.bytes.length,
    );
    return AlertDialog(
      title: const Text('Импорт данных'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Заголовок блока',
                  hintText: 'Например, Данные измерения 12.08',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${widget.files.length} файл(а), '
                '${NoteDataImport.fileSizeLabel(totalBytes)}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 190),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.files.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final file = widget.files[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        file.isImage
                            ? Icons.image_outlined
                            : file.isTabular
                            ? Icons.table_chart_outlined
                            : Icons.insert_drive_file_outlined,
                      ),
                      title: Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        NoteDataImport.fileSizeLabel(file.bytes.length),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (canImportAsTable) ...[
                SegmentedButton<NoteDataImportMode>(
                  segments: const [
                    ButtonSegment(
                      value: NoteDataImportMode.tableWithSource,
                      icon: Icon(Icons.table_chart_outlined),
                      label: Text('Таблица + исходник'),
                    ),
                    ButtonSegment(
                      value: NoteDataImportMode.attachmentBundle,
                      icon: Icon(Icons.folder_zip_outlined),
                      label: Text('Набор файлов'),
                    ),
                  ],
                  selected: <NoteDataImportMode>{mode},
                  onSelectionChanged: (selection) {
                    setState(() => mode = selection.single);
                  },
                ),
                if (mode == NoteDataImportMode.tableWithSource &&
                    tablePreview != null) ...[
                  const SizedBox(height: 12),
                  _TablePreview(data: tablePreview),
                  const SizedBox(height: 8),
                  Text(
                    'В заметку попадут максимум '
                    '${tablePreview.rows.length.clamp(1, 41)} строк и '
                    '${tablePreview.columnCount.clamp(2, 8)} столбцов; '
                    'исходный файл сохранится во вложениях.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
              if (mode == NoteDataImportMode.attachmentBundle &&
                  widget.files.any((file) => file.isImage))
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Показывать изображения в заметке'),
                  subtitle: const Text(
                    'Остальные файлы будут вставлены обычными ссылками.',
                  ),
                  value: showImagePreviews,
                  onChanged: (value) {
                    setState(() => showImagePreviews = value);
                  },
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
          onPressed: () {
            Navigator.pop(
              context,
              NoteDataImportPlan(
                mode: mode,
                title: titleController.text,
                showImagePreviews: showImagePreviews,
              ),
            );
          },
          icon: const Icon(Icons.file_download_done_outlined),
          label: const Text('Импортировать'),
        ),
      ],
    );
  }
}

class _TablePreview extends StatelessWidget {
  const _TablePreview({required this.data});

  final ClipboardTableData data;

  @override
  Widget build(BuildContext context) {
    final rows = data.rows.take(6).toList();
    final columns = data.columnCount.clamp(2, 8).toInt();
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 42,
          dataRowMinHeight: 36,
          dataRowMaxHeight: 52,
          columns: [
            for (var column = 0; column < columns; column += 1)
              DataColumn(
                label: Text(
                  column < rows.first.length && rows.first[column].isNotEmpty
                      ? rows.first[column]
                      : 'Столбец ${column + 1}',
                ),
              ),
          ],
          rows: [
            for (final row in rows.skip(1))
              DataRow(
                cells: [
                  for (var column = 0; column < columns; column += 1)
                    DataCell(
                      Text(
                        column < row.length ? row[column] : '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
