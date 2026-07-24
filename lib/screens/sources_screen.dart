import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../features/references/bibtex_codec.dart';
import '../features/references/citation_syntax.dart';
import '../models/app_models.dart';
import '../services/app_store.dart';

class SourcesScreen extends StatefulWidget {
  const SourcesScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    final sources =
        widget.store.data.citationSources.where((source) {
            if (normalized.isEmpty) return true;
            final searchable =
                [
                  source.citationKey,
                  source.title,
                  source.authors.join(' '),
                  source.containerTitle,
                  source.doi,
                  source.pmid,
                  source.arxivId,
                  source.tags.join(' '),
                ].join(' ').toLowerCase();
            return searchable.contains(normalized);
          }).toList()
          ..sort((left, right) {
            final yearCompare = (right.year ?? 0).compareTo(left.year ?? 0);
            if (yearCompare != 0) return yearCompare;
            return left.title.toLowerCase().compareTo(
              right.title.toLowerCase(),
            );
          });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Источники'),
        actions: [
          IconButton(
            tooltip: 'Импортировать BibTeX',
            onPressed: _importBibTex,
            icon: const Icon(Icons.upload_file_outlined),
          ),
          IconButton(
            tooltip: 'Скопировать библиотеку как BibTeX',
            onPressed:
                widget.store.data.citationSources.isEmpty
                    ? null
                    : _exportBibTex,
            icon: const Icon(Icons.file_copy_outlined),
          ),
          IconButton(
            tooltip: 'Добавить источник',
            onPressed: () => _editSource(null),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: SearchBar(
              hintText: 'Название, автор, DOI, тег или citation key',
              leading: const Icon(Icons.search_rounded),
              onChanged: (value) => setState(() => query = value),
            ),
          ),
          Expanded(
            child:
                sources.isEmpty
                    ? _SourcesEmpty(
                      hasQuery: normalized.isNotEmpty,
                      onAdd: () => _editSource(null),
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      itemCount: sources.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final source = sources[index];
                        final usage = widget.store.citationUsageCount(
                          source.citationKey,
                        );
                        return Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () => _editSource(source),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    child: Icon(_sourceIcon(source.sourceType)),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          source.title,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          _sourceSubtitle(source),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.copyWith(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 7,
                                          runSpacing: 7,
                                          children: [
                                            Chip(
                                              avatar: const Icon(
                                                Icons.alternate_email_rounded,
                                                size: 16,
                                              ),
                                              label: Text(source.citationKey),
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                            if (source.doi.trim().isNotEmpty)
                                              Chip(
                                                label: Text(
                                                  'DOI ${source.normalizedDoi}',
                                                ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                            if (source.arxivId
                                                .trim()
                                                .isNotEmpty)
                                              Chip(
                                                label: Text(
                                                  'arXiv ${source.arxivId}',
                                                ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                            if (usage > 0)
                                              Chip(
                                                avatar: const Icon(
                                                  Icons.format_quote_rounded,
                                                  size: 16,
                                                ),
                                                label: Text('$usage цит.'),
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                            for (final tag in source.tags.take(
                                              3,
                                            ))
                                              Chip(
                                                label: Text('#$tag'),
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'copy') {
                                        Clipboard.setData(
                                          ClipboardData(
                                            text: CitationSyntax.markdownFor([
                                              source,
                                            ]),
                                          ),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Скопировано [@${source.citationKey}]',
                                            ),
                                          ),
                                        );
                                      } else if (value == 'delete') {
                                        _deleteSource(source);
                                      }
                                    },
                                    itemBuilder:
                                        (_) => const [
                                          PopupMenuItem(
                                            value: 'copy',
                                            child: Text('Копировать цитату'),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Удалить'),
                                          ),
                                        ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editSource(null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Источник'),
      ),
    );
  }

  Future<void> _editSource(CitationSource? existing) async {
    final result = await showDialog<CitationSource>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CitationSourceDialog(source: existing),
    );
    if (result == null || !mounted) return;

    final keyConflict = widget.store.data.citationSources.any(
      (source) =>
          source.id != result.id &&
          source.normalizedCitationKey == result.normalizedCitationKey,
    );
    if (keyConflict) {
      _showError('Citation key «${result.citationKey}» уже используется.');
      return;
    }
    final normalizedDoi = result.normalizedDoi;
    final doiConflict =
        normalizedDoi.isNotEmpty &&
        widget.store.data.citationSources.any(
          (source) =>
              source.id != result.id && source.normalizedDoi == normalizedDoi,
        );
    if (doiConflict) {
      _showError('Источник с DOI $normalizedDoi уже есть в библиотеке.');
      return;
    }

    if (existing == null) {
      await widget.store.addCitationSource(result);
    } else {
      await widget.store.updateCitationSource(result);
    }
    setState(() {});
  }

  Future<void> _deleteSource(CitationSource source) async {
    final usage = widget.store.citationUsageCount(source.citationKey);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Удалить источник?'),
            content: Text(
              usage == 0
                  ? 'Источник «${source.title}» будет удалён из локальной библиотеки.'
                  : 'Ключ @${source.citationKey} используется $usage раз. '
                      'Цитаты останутся в Markdown, но станут неразрешёнными.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
    );
    if (confirmed == true && mounted) {
      await widget.store.deleteCitationSource(source.id);
      if (!mounted) {
        return;
      }
      setState(() {});
    }
  }

  Future<void> _importBibTex() async {
    final raw = await showDialog<String>(
      context: context,
      builder: (context) => const _BibTexPasteDialog(),
    );
    if (raw == null || raw.trim().isEmpty || !mounted) return;
    final parsed = BibTexCodec.decode(raw);
    final existingKeys =
        widget.store.data.citationSources
            .map((source) => source.normalizedCitationKey)
            .toSet();
    final existingDois =
        widget.store.data.citationSources
            .map((source) => source.normalizedDoi)
            .where((doi) => doi.isNotEmpty)
            .toSet();
    final accepted = <CitationSource>[];
    final skipped = <String>[];
    final batchKeys = <String>{};
    final batchDois = <String>{};
    for (final source in parsed.sources) {
      final key = source.normalizedCitationKey;
      final doi = source.normalizedDoi;
      if (!RegExp(r'^[A-Za-z0-9_.:-]+$').hasMatch(source.citationKey)) {
        skipped.add('${source.citationKey}: неподдерживаемый citation key');
        continue;
      }
      if (existingKeys.contains(key) || !batchKeys.add(key)) {
        skipped.add('${source.citationKey}: повторяющийся citation key');
        continue;
      }
      if (doi.isNotEmpty &&
          (existingDois.contains(doi) || !batchDois.add(doi))) {
        skipped.add('${source.citationKey}: DOI $doi уже существует');
        continue;
      }
      accepted.add(source);
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => _BibTexPreviewDialog(
            accepted: accepted,
            skipped: [...parsed.errors, ...skipped],
          ),
    );
    if (confirmed != true || !mounted) return;
    final count = await widget.store.importCitationSources(accepted);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Импортировано источников: $count')));
  }

  Future<void> _exportBibTex() async {
    final value = BibTexCodec.encode(widget.store.data.citationSources);
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Библиотека BibTeX скопирована в буфер обмена'),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SourcesEmpty extends StatelessWidget {
  const _SourcesEmpty({required this.hasQuery, required this.onAdd});

  final bool hasQuery;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.library_books_outlined, size: 60),
            const SizedBox(height: 16),
            Text(
              hasQuery
                  ? 'Источники не найдены'
                  : 'Локальная библиотека пока пуста',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'Измени поисковый запрос.'
                  : 'Добавь статью вручную или импортируй BibTeX.',
              textAlign: TextAlign.center,
            ),
            if (!hasQuery) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Добавить источник'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CitationSourceDialog extends StatefulWidget {
  const _CitationSourceDialog({this.source});

  final CitationSource? source;

  @override
  State<_CitationSourceDialog> createState() => _CitationSourceDialogState();
}

class _CitationSourceDialogState extends State<_CitationSourceDialog> {
  late final TextEditingController keyController;
  late final TextEditingController titleController;
  late final TextEditingController authorsController;
  late final TextEditingController yearController;
  late final TextEditingController containerController;
  late final TextEditingController doiController;
  late final TextEditingController pmidController;
  late final TextEditingController arxivController;
  late final TextEditingController urlController;
  late final TextEditingController pdfController;
  late final TextEditingController tagsController;
  late final TextEditingController noteController;
  late String sourceType;
  String? error;

  @override
  void initState() {
    super.initState();
    final source = widget.source;
    keyController = TextEditingController(text: source?.citationKey ?? '');
    titleController = TextEditingController(text: source?.title ?? '');
    authorsController = TextEditingController(
      text: source?.authors.join('\n') ?? '',
    );
    yearController = TextEditingController(
      text: source?.year?.toString() ?? '',
    );
    containerController = TextEditingController(
      text: source?.containerTitle ?? '',
    );
    doiController = TextEditingController(text: source?.doi ?? '');
    pmidController = TextEditingController(text: source?.pmid ?? '');
    arxivController = TextEditingController(text: source?.arxivId ?? '');
    urlController = TextEditingController(text: source?.url ?? '');
    pdfController = TextEditingController(text: source?.pdfPath ?? '');
    tagsController = TextEditingController(text: source?.tags.join(', ') ?? '');
    noteController = TextEditingController(text: source?.note ?? '');
    sourceType = source?.sourceType ?? 'article';
  }

  @override
  void dispose() {
    keyController.dispose();
    titleController.dispose();
    authorsController.dispose();
    yearController.dispose();
    containerController.dispose();
    doiController.dispose();
    pmidController.dispose();
    arxivController.dispose();
    urlController.dispose();
    pdfController.dispose();
    tagsController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 820),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.source == null
                          ? 'Новый источник'
                          : 'Редактировать источник',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (error != null) ...[
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: keyController,
                          readOnly: widget.source != null,
                          decoration: InputDecoration(
                            labelText: 'Citation key *',
                            hintText: 'Jaffe2005',
                            helperText:
                                widget.source == null
                                    ? null
                                    : 'Ключ фиксируется после создания.',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: sourceType,
                          decoration: const InputDecoration(labelText: 'Тип'),
                          items: const [
                            DropdownMenuItem(
                              value: 'article',
                              child: Text('Статья / препринт'),
                            ),
                            DropdownMenuItem(
                              value: 'book',
                              child: Text('Книга'),
                            ),
                            DropdownMenuItem(
                              value: 'conference',
                              child: Text('Конференция'),
                            ),
                            DropdownMenuItem(
                              value: 'thesis',
                              child: Text('Диссертация'),
                            ),
                            DropdownMenuItem(
                              value: 'web',
                              child: Text('Веб-источник'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => sourceType = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Название *'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: authorsController,
                    decoration: const InputDecoration(
                      labelText: 'Авторы',
                      hintText: 'Один автор на строку',
                    ),
                    minLines: 2,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 150,
                        child: TextField(
                          controller: yearController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Год'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: containerController,
                          decoration: const InputDecoration(
                            labelText: 'Журнал / издательство',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: doiController,
                    decoration: const InputDecoration(labelText: 'DOI'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: pmidController,
                          decoration: const InputDecoration(labelText: 'PMID'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: arxivController,
                          decoration: const InputDecoration(
                            labelText: 'arXiv ID',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(labelText: 'Ссылка'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pdfController,
                    decoration: InputDecoration(
                      labelText: 'Локальный PDF',
                      suffixIcon: IconButton(
                        tooltip: 'Выбрать PDF',
                        onPressed: _pickPdf,
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tagsController,
                    decoration: const InputDecoration(
                      labelText: 'Теги через запятую',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'Комментарий'),
                    minLines: 3,
                    maxLines: 8,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Отмена'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Сохранить'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    pdfController.text = result.files.single.path ?? result.files.single.name;
  }

  void _save() {
    final key = keyController.text.trim();
    final title = titleController.text.trim();
    if (!RegExp(r'^[A-Za-z0-9_.:-]+$').hasMatch(key)) {
      setState(
        () =>
            error =
                'Citation key может содержать латинские буквы, цифры, _, ., : и -.',
      );
      return;
    }
    if (title.isEmpty) {
      setState(() => error = 'Укажи название источника.');
      return;
    }
    final existing = widget.source;
    Navigator.pop(
      context,
      CitationSource(
        id: existing?.id ?? const Uuid().v4(),
        citationKey: key,
        title: title,
        sourceType: sourceType,
        authors:
            authorsController.text
                .split(RegExp(r'[\n;]+'))
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty)
                .toList(),
        year: int.tryParse(yearController.text.trim()),
        containerTitle: containerController.text.trim(),
        doi: doiController.text.trim(),
        pmid: pmidController.text.trim(),
        arxivId: arxivController.text.trim(),
        url: urlController.text.trim(),
        pdfPath: pdfController.text.trim(),
        tags:
            tagsController.text
                .split(RegExp(r'[,;]'))
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty)
                .toList(),
        note: noteController.text.trim(),
        createdAt: existing?.createdAt,
        updatedAt: DateTime.now(),
      ),
    );
  }
}

class _BibTexPasteDialog extends StatefulWidget {
  const _BibTexPasteDialog();

  @override
  State<_BibTexPasteDialog> createState() => _BibTexPasteDialogState();
}

class _BibTexPasteDialogState extends State<_BibTexPasteDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Импорт BibTeX'),
      content: SizedBox(
        width: 680,
        child: TextField(
          controller: controller,
          autofocus: true,
          minLines: 12,
          maxLines: 20,
          style: const TextStyle(fontFamily: 'monospace'),
          decoration: const InputDecoration(
            hintText:
                '@article{Jaffe2005,\n  title = {...},\n  author = {...}\n}',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Проверить'),
        ),
      ],
    );
  }
}

class _BibTexPreviewDialog extends StatelessWidget {
  const _BibTexPreviewDialog({required this.accepted, required this.skipped});

  final List<CitationSource> accepted;
  final List<String> skipped;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Предварительный просмотр импорта'),
      content: SizedBox(
        width: 680,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text('Будет импортировано: ${accepted.length}'),
            if (skipped.isNotEmpty)
              Text('Пропущено или требует внимания: ${skipped.length}'),
            const SizedBox(height: 12),
            for (final source in accepted)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle_outline_rounded),
                title: Text(source.title),
                subtitle: Text(
                  '@${source.citationKey} · ${_sourceSubtitle(source)}',
                ),
              ),
            if (skipped.isNotEmpty) ...[
              const Divider(),
              Text(
                'Предупреждения',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              for (final message in skipped)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.warning_amber_rounded),
                  title: Text(message),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed:
              accepted.isEmpty ? null : () => Navigator.pop(context, true),
          child: const Text('Импортировать'),
        ),
      ],
    );
  }
}

IconData _sourceIcon(String type) {
  return switch (type) {
    'book' => Icons.menu_book_outlined,
    'conference' => Icons.groups_outlined,
    'thesis' => Icons.school_outlined,
    'web' => Icons.public_outlined,
    _ => Icons.article_outlined,
  };
}

String _sourceSubtitle(CitationSource source) {
  final values = <String>[];
  if (source.authors.isNotEmpty) values.add(source.authors.join(', '));
  if (source.year != null) values.add(source.year.toString());
  if (source.containerTitle.trim().isNotEmpty) {
    values.add(source.containerTitle.trim());
  }
  return values.isEmpty
      ? 'Без библиографического описания'
      : values.join(' · ');
}
