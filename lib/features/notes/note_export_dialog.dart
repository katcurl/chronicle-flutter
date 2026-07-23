import 'package:flutter/material.dart';

import 'note_export.dart';

class NoteExportDialog extends StatefulWidget {
  const NoteExportDialog({
    super.key,
    required this.subjectLabel,
    required this.isProject,
  });

  final String subjectLabel;
  final bool isProject;

  static Future<ChronicleExportFormat?> show(
    BuildContext context, {
    required String subjectLabel,
    required bool isProject,
  }) {
    return showDialog<ChronicleExportFormat>(
      context: context,
      builder:
          (context) => NoteExportDialog(
            subjectLabel: subjectLabel,
            isProject: isProject,
          ),
    );
  }

  @override
  State<NoteExportDialog> createState() => _NoteExportDialogState();
}

class _NoteExportDialogState extends State<NoteExportDialog> {
  ChronicleExportFormat format = ChronicleExportFormat.portableArchive;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isProject ? 'Экспорт проекта' : 'Экспорт заметки'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.subjectLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            _ExportChoice(
              selected: format == ChronicleExportFormat.markdown,
              icon: Icons.description_outlined,
              title: 'Markdown',
              subtitle:
                  widget.isProject
                      ? 'Один читаемый документ с задачами и всеми заметками.'
                      : 'Обычный UTF-8 Markdown; ссылки на Vault сохраняются.',
              onTap:
                  () => setState(() => format = ChronicleExportFormat.markdown),
            ),
            _ExportChoice(
              selected: format == ChronicleExportFormat.html,
              icon: Icons.language_rounded,
              title: 'Автономный HTML',
              subtitle:
                  'Один файл для браузера; использованные изображения '
                  'встраиваются внутрь.',
              onTap: () => setState(() => format = ChronicleExportFormat.html),
            ),
            if (!widget.isProject)
              _ExportChoice(
                selected: format == ChronicleExportFormat.docx,
                icon: Icons.article_outlined,
                title: 'DOCX',
                subtitle:
                    'Редактируемый документ для Microsoft Word и LibreOffice.',
                onTap:
                    () => setState(() => format = ChronicleExportFormat.docx),
              ),
            if (!widget.isProject)
              _ExportChoice(
                selected: format == ChronicleExportFormat.pdf,
                icon: Icons.picture_as_pdf_outlined,
                title: 'PDF',
                subtitle:
                    'Готовый документ с фиксированной вёрсткой для чтения и печати.',
                onTap: () => setState(() => format = ChronicleExportFormat.pdf),
              ),
            _ExportChoice(
              selected: format == ChronicleExportFormat.portableArchive,
              icon: Icons.folder_zip_outlined,
              title: 'Переносимый ZIP',
              subtitle:
                  widget.isProject
                      ? 'README, отдельные Markdown/HTML-файлы заметок, '
                          'манифест и использованные вложения.'
                      : 'Markdown, HTML, манифест и только использованные '
                          'вложения.',
              onTap:
                  () => setState(
                    () => format = ChronicleExportFormat.portableArchive,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Экспорт создаёт новый файл и не изменяет Vault или исходные '
              'заметки.',
              style: Theme.of(context).textTheme.bodySmall,
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
          onPressed: () => Navigator.pop(context, format),
          icon: const Icon(Icons.download_rounded),
          label: const Text('Экспортировать'),
        ),
      ],
    );
  }
}

class _ExportChoice extends StatelessWidget {
  const _ExportChoice({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color:
          selected
              ? colorScheme.secondaryContainer
              : colorScheme.surfaceContainerLow,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing:
            selected
                ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
                : const Icon(Icons.circle_outlined),
      ),
    );
  }
}
