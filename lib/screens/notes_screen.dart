import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../features/notes/note_block_syntax.dart';
import '../features/notes/note_columns_editor_dialog.dart';
import '../features/notes/note_columns_syntax.dart';
import '../features/notes/note_document.dart';
import '../features/notes/note_image_editor_dialog.dart';
import '../features/notes/note_image_syntax.dart';
import '../features/notes/note_markdown_view.dart';
import '../features/notes/note_templates.dart';
import '../features/tasks/task_editor_sheet.dart';
import '../models/app_models.dart';
import '../services/app_store.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  String query = '';
  String? folderFilter;
  String? projectFilter;
  bool pinnedOnly = false;

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final folders =
        widget.store.data.notes
            .map((note) => note.folderPath.trim())
            .where((folder) => folder.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final notes =
        widget.store.data.notes.where((note) {
            if (pinnedOnly && !note.pinned) {
              return false;
            }
            if (folderFilter != null && note.folderPath != folderFilter) {
              return false;
            }
            if (projectFilter != null && note.projectId != projectFilter) {
              return false;
            }
            if (normalizedQuery.isEmpty) {
              return true;
            }
            return note.title.toLowerCase().contains(normalizedQuery) ||
                note.body.toLowerCase().contains(normalizedQuery) ||
                note.tags.any(
                  (tag) => tag.toLowerCase().contains(normalizedQuery),
                );
          }).toList()
          ..sort((a, b) {
            if (a.pinned != b.pinned) {
              return a.pinned ? -1 : 1;
            }
            return b.updatedAt.compareTo(a.updatedAt);
          });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Заметки'),
        actions: [
          IconButton(
            tooltip: pinnedOnly ? 'Показать все' : 'Только закреплённые',
            onPressed: () => setState(() => pinnedOnly = !pinnedOnly),
            icon: Icon(
              pinnedOnly ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Новая заметка',
            onPressed: widget.store.activeProjects.isEmpty ? null : _add,
            icon: const Icon(Icons.note_add_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Поиск по базе знаний',
              leading: const Icon(Icons.search_rounded),
              onChanged: (value) => setState(() => query = value),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                DropdownButton<String?>(
                  value: projectFilter,
                  hint: const Text('Все проекты'),
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Все проекты'),
                    ),
                    ...widget.store.activeProjects.map(
                      (project) => DropdownMenuItem<String?>(
                        value: project.id,
                        child: Text('${project.emoji} ${project.title}'),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => projectFilter = value),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Все папки'),
                  selected: folderFilter == null,
                  onSelected: (_) => setState(() => folderFilter = null),
                ),
                for (final folder in folders) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(folder),
                    selected: folderFilter == folder,
                    onSelected: (_) => setState(() => folderFilter = folder),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child:
                notes.isEmpty
                    ? _EmptyNotes(
                      hasFilters:
                          normalizedQuery.isNotEmpty ||
                          pinnedOnly ||
                          folderFilter != null ||
                          projectFilter != null,
                    )
                    : LayoutBuilder(
                      builder: (context, constraints) {
                        final columns =
                            constraints.maxWidth >= 1180
                                ? 3
                                : constraints.maxWidth >= 760
                                ? 2
                                : 1;
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisExtent: 218,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: notes.length,
                          itemBuilder:
                              (_, index) => _NoteCard(
                                store: widget.store,
                                note: notes[index],
                                onOpen: () => _open(notes[index]),
                              ),
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.store.activeProjects.isEmpty ? null : _add,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Заметка'),
      ),
    );
  }

  Future<void> _add() async {
    final request = await _NewNoteSheet.show(
      context,
      projects: widget.store.activeProjects,
    );
    if (request == null || !mounted) return;

    final template = noteTemplates.firstWhere(
      (item) => item.id == request.templateId,
    );
    final note = Note(
      id: const Uuid().v4(),
      title:
          request.title.trim().isEmpty ? template.title : request.title.trim(),
      projectId: request.projectId,
      body: '',
      tags: List<String>.from(template.defaultTags),
      noteType: template.noteType,
      folderPath: request.folderPath.trim(),
      properties: Map<String, String>.from(template.defaultProperties),
    );
    note.body = NoteDocument.serialize(note, template.content);
    widget.store.addNote(note);
    await _open(note);
  }

  Future<void> _open(Note note) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => NoteWorkspaceScreen(store: widget.store, note: note),
      ),
    );
    if (mounted) setState(() {});
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.store,
    required this.note,
    required this.onOpen,
  });

  final AppStore store;
  final Note note;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final project = store.projectById(note.projectId);
    final parsed = NoteDocument.parse(note.body);
    final words = NoteDocument.wordCount(parsed.content);
    final backlinks = store.backlinksFor(note).length;
    final tasks =
        store.data.tasks.where((task) => task.noteId == note.id).length;
    final seconds = store.data.entries
        .where((entry) => entry.noteId == note.id)
        .fold<int>(0, (sum, entry) => sum + entry.durationSeconds);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    noteTypeIcon(note.noteType),
                    style: const TextStyle(fontSize: 27),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      noteTypeLabel(note.noteType),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  if (note.pinned) const Icon(Icons.push_pin_rounded, size: 18),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                note.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(
                _plainSnippet(parsed.content),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (note.tags.isNotEmpty)
                Text(
                  note.tags.take(4).map((tag) => '#$tag').join('  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(project?.emoji ?? '📁'),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      note.folderPath.isEmpty
                          ? project?.title ?? 'Без проекта'
                          : note.folderPath,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _TinyMetric(icon: Icons.text_fields_rounded, value: '$words'),
                  if (backlinks > 0)
                    _TinyMetric(icon: Icons.link_rounded, value: '$backlinks'),
                  if (tasks > 0)
                    _TinyMetric(icon: Icons.checklist_rounded, value: '$tasks'),
                  if (seconds > 0)
                    _TinyMetric(
                      icon: Icons.timer_outlined,
                      value: '${(seconds / 3600).toStringAsFixed(1)}ч',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TinyMetric extends StatelessWidget {
  const _TinyMetric({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 2),
          Text(value, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class NoteWorkspaceScreen extends StatefulWidget {
  const NoteWorkspaceScreen({
    super.key,
    required this.store,
    required this.note,
  });

  final AppStore store;
  final Note note;

  @override
  State<NoteWorkspaceScreen> createState() => _NoteWorkspaceScreenState();
}

class _NoteWorkspaceScreenState extends State<NoteWorkspaceScreen> {
  late final TextEditingController titleController;
  late final TextEditingController contentController;
  late String projectId;
  late String status;
  late String folderPath;
  late String noteType;
  late List<String> tags;
  late Map<String, String> properties;
  late bool pinned;
  bool dirty = false;
  int mode = 0;

  @override
  void initState() {
    super.initState();
    final parsed = NoteDocument.parse(widget.note.body);
    titleController = TextEditingController(text: widget.note.title);
    contentController = TextEditingController(text: parsed.content);
    projectId = widget.note.projectId;
    status = parsed.frontMatter['status'] ?? widget.note.status;
    folderPath = parsed.frontMatter['folder'] ?? widget.note.folderPath;
    noteType = parsed.frontMatter['type'] ?? widget.note.noteType;
    tags =
        widget.note.tags.isEmpty
            ? NoteDocument.parseTags(parsed.frontMatter['tags'])
            : List<String>.from(widget.note.tags);
    properties = Map<String, String>.from(widget.note.properties);
    for (final entry in parsed.frontMatter.entries) {
      if (!const {'status', 'folder', 'type', 'tags'}.contains(entry.key)) {
        properties.putIfAbsent(entry.key, () => entry.value);
      }
    }
    pinned = widget.note.pinned;
    titleController.addListener(_markDirty);
    contentController.addListener(_markDirty);
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (mounted) setState(() => dirty = true);
  }

  @override
  Widget build(BuildContext context) {
    final linkedTasks =
        widget.store.data.tasks
            .where((task) => task.noteId == widget.note.id)
            .toList();
    final backlinks = widget.store.backlinksFor(widget.note);
    final outgoing = widget.store.outgoingLinksFor(widget.note.id);
    final versions = widget.store.versionsFor(widget.note.id);

    return PopScope(
      onPopInvokedWithResult: (_, __) {
        if (dirty) _save(createVersion: false);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showPanel = constraints.maxWidth >= 860;
          final split = constraints.maxWidth >= 1180;
          return Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  Text(noteTypeIcon(noteType)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dirty ? '${widget.note.title} •' : widget.note.title,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Сохранить версию',
                  onPressed: dirty ? () => _save(createVersion: true) : null,
                  icon: const Icon(Icons.save_outlined),
                ),
                IconButton(
                  tooltip: 'Редактор',
                  onPressed: () => _switchMode(0),
                  icon: Icon(
                    mode == 0 ? Icons.edit_rounded : Icons.edit_outlined,
                  ),
                ),
                IconButton(
                  tooltip: 'Предпросмотр',
                  onPressed: () => _switchMode(1),
                  icon: Icon(
                    mode == 1
                        ? Icons.visibility_rounded
                        : Icons.visibility_outlined,
                  ),
                ),
                if (split)
                  IconButton(
                    tooltip: 'Разделить редактор',
                    onPressed: () => _switchMode(2),
                    icon: Icon(
                      mode == 2
                          ? Icons.vertical_split_rounded
                          : Icons.vertical_split_outlined,
                    ),
                  ),
                if (!showPanel)
                  Builder(
                    builder:
                        (context) => IconButton(
                          tooltip: 'Контекст заметки',
                          onPressed: () => Scaffold.of(context).openEndDrawer(),
                          icon: const Icon(Icons.tune_rounded),
                        ),
                  ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      widget.store.deleteNote(widget.note.id);
                      Navigator.pop(context);
                    }
                  },
                  itemBuilder:
                      (_) => const [
                        PopupMenuItem(value: 'delete', child: Text('Удалить')),
                      ],
                ),
              ],
            ),
            endDrawer:
                showPanel
                    ? null
                    : Drawer(
                      width: 360,
                      child: SafeArea(
                        child: _contextPanel(
                          backlinks: backlinks,
                          outgoing: outgoing,
                          linkedTasks: linkedTasks,
                          versions: versions,
                        ),
                      ),
                    ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {
                _save(createVersion: false);
                widget.store.startTimer(
                  description: 'Работа над ${widget.note.title}',
                  projectId: projectId,
                  noteId: widget.note.id,
                );
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Таймер запущен')));
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Работать'),
            ),
            body: Row(
              children: [
                Expanded(
                  child:
                      mode == 2 && split
                          ? Row(
                            children: [
                              Expanded(child: _editorPane()),
                              const VerticalDivider(width: 1),
                              Expanded(child: _previewPane()),
                            ],
                          )
                          : mode == 1
                          ? _previewPane()
                          : _editorPane(),
                ),
                if (showPanel) ...[
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: constraints.maxWidth >= 1180 ? 350 : 310,
                    child: _contextPanel(
                      backlinks: backlinks,
                      outgoing: outgoing,
                      linkedTasks: linkedTasks,
                      versions: versions,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _switchMode(int nextMode) {
    if (nextMode == mode) {
      return;
    }
    if (dirty) {
      _save(createVersion: false);
    }
    if (!mounted) {
      return;
    }
    setState(() => mode = nextMode);
  }

  Widget _editorPane() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
          child: TextField(
            controller: titleController,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            decoration: const InputDecoration(
              border: InputBorder.none,
              filled: false,
              hintText: 'Название',
            ),
          ),
        ),
        _EditorToolbar(
          controller: contentController,
          onAttach: _attachFile,
          onConfigureImage: _editImageAtCursor,
          onConfigureColumns: _configureColumnsAtCursor,
          onBlockAction: _handleBlockAction,
        ),
        const Divider(height: 1),
        Expanded(
          child: TextField(
            controller: contentController,
            expands: true,
            maxLines: null,
            minLines: null,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 15,
              height: 1.6,
            ),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.all(20),
              border: InputBorder.none,
              filled: false,
              hintText: r'Markdown, $LaTeX$, [[ссылки]], изображения…',
            ),
          ),
        ),
      ],
    );
  }

  Widget _previewPane() {
    return NoteMarkdownView(
      markdown: contentController.text,
      onWikiLink: _openWikiLink,
      onEditImage: _editImageReference,
      onResizeImage: _replaceImagePresentation,
      onEditColumns: _editColumnsReference,
      onResizeColumns: _replaceColumnsWidths,
      assetListenable: widget.store,
      vaultRootPath: widget.store.vaultStatus.rootPath,
    );
  }

  Widget _contextPanel({
    required List<NoteLink> backlinks,
    required List<NoteLink> outgoing,
    required List<WorkTask> linkedTasks,
    required List<NoteVersion> versions,
  }) {
    final words = NoteDocument.wordCount(contentController.text);
    final minutes = NoteDocument.readingMinutes(contentController.text);
    final seconds = widget.store.data.entries
        .where((entry) => entry.noteId == widget.note.id)
        .fold<int>(0, (sum, entry) => sum + entry.durationSeconds);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      children: [
        Row(
          children: [
            Text(
              'Контекст заметки',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Свойства',
              onPressed: _editProperties,
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _ContextCard(
          title: 'Свойства',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PropertyRow(label: 'Тип', value: noteTypeLabel(noteType)),
              _PropertyRow(label: 'Статус', value: _statusLabel(status)),
              _PropertyRow(
                label: 'Проект',
                value: widget.store.projectById(projectId)?.title ?? '—',
              ),
              _PropertyRow(
                label: 'Папка',
                value: folderPath.isEmpty ? 'Без папки' : folderPath,
              ),
              _PropertyRow(
                label: 'Теги',
                value:
                    tags.isEmpty ? '—' : tags.map((tag) => '#$tag').join(' '),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _ContextCard(
          title: 'Статистика',
          child: Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _StatChip(icon: Icons.text_fields_rounded, label: '$words слов'),
              _StatChip(icon: Icons.menu_book_rounded, label: '$minutes мин'),
              _StatChip(
                icon: Icons.timer_outlined,
                label: '${(seconds / 3600).toStringAsFixed(1)} ч',
              ),
              _StatChip(
                icon: Icons.history_rounded,
                label: 'rev ${widget.note.revision}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _ContextCard(
          title: 'Задачи',
          action: TextButton.icon(
            onPressed: _createTask,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Добавить'),
          ),
          child:
              linkedTasks.isEmpty
                  ? const Text('Связанных задач пока нет')
                  : Column(
                    children: [
                      for (final task in linkedTasks)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: task.status == 'done',
                          title: Text(task.title),
                          onChanged:
                              (value) => widget.store.updateTaskStatus(
                                task,
                                value == true ? 'done' : 'next',
                              ),
                        ),
                    ],
                  ),
        ),
        const SizedBox(height: 10),
        _LinkSection(
          title: 'Обратные ссылки',
          emptyText: 'На эту заметку пока никто не ссылается',
          links: backlinks,
          resolve: (link) => widget.store.noteById(link.sourceNoteId),
          onOpen: _openNote,
        ),
        const SizedBox(height: 10),
        _LinkSection(
          title: 'Исходящие ссылки',
          emptyText: 'Добавь ссылку вида [[Название заметки]]',
          links: outgoing,
          resolve:
              (link) =>
                  link.targetNoteId == null
                      ? widget.store.noteByTitle(link.targetTitle)
                      : widget.store.noteById(link.targetNoteId!),
          onOpen: _openNote,
        ),
        const SizedBox(height: 10),
        _ContextCard(
          title: 'История версий',
          child:
              versions.isEmpty
                  ? const Text('Версии появятся после ручного сохранения')
                  : Column(
                    children: [
                      for (final version in versions.take(8))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.history_rounded),
                          title: Text(_dateTime(version.createdAt)),
                          subtitle: Text(version.reason),
                          trailing: TextButton(
                            onPressed: () => _restoreVersion(version),
                            child: const Text('Вернуть'),
                          ),
                        ),
                    ],
                  ),
        ),
      ],
    );
  }

  void _save({required bool createVersion}) {
    if (!dirty && !createVersion) return;
    if (createVersion && dirty) {
      widget.store.addNoteVersion(
        NoteVersion(
          id: const Uuid().v4(),
          noteId: widget.note.id,
          title: widget.note.title,
          body: widget.note.body,
          tags: List<String>.from(widget.note.tags),
          status: widget.note.status,
          folderPath: widget.note.folderPath,
          noteType: widget.note.noteType,
          properties: Map<String, String>.from(widget.note.properties),
          reason: 'Ручное сохранение',
        ),
      );
    }
    widget.note.title =
        titleController.text.trim().isEmpty
            ? 'Без названия'
            : titleController.text.trim();
    widget.note.projectId = projectId;
    widget.note.status = status;
    widget.note.folderPath = folderPath.trim();
    widget.note.noteType = noteType;
    widget.note.tags = List<String>.from(tags);
    widget.note.properties = Map<String, String>.from(properties);
    widget.note.pinned = pinned;
    widget.note.body = NoteDocument.serialize(
      widget.note,
      contentController.text,
    );
    widget.store.updateNote(widget.note);
    if (mounted) setState(() => dirty = false);
  }

  Future<void> _editProperties() async {
    final result = await _NotePropertiesSheet.show(
      context,
      projects: widget.store.activeProjects,
      metadata: _NoteMetadata(
        projectId: projectId,
        status: status,
        folderPath: folderPath,
        noteType: noteType,
        tags: tags,
        properties: properties,
        pinned: pinned,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      projectId = result.projectId;
      status = result.status;
      folderPath = result.folderPath;
      noteType = result.noteType;
      tags = result.tags;
      properties = result.properties;
      pinned = result.pinned;
      dirty = true;
    });
  }

  Future<void> _attachFile() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final attachment = await widget.store.pickAttachmentForNote(widget.note);
      if (attachment == null || !mounted) {
        return;
      }

      var markdown = attachment.markdown;
      if (attachment.isImage) {
        final reference = NoteImageSyntax.first(markdown);
        if (reference != null) {
          final configured = await NoteImageEditorDialog.show(
            context,
            initial: reference.presentation,
            imageLabel: reference.alt,
          );
          if (!mounted) {
            return;
          }
          if (configured != null) {
            markdown = reference.toMarkdown(presentation: configured);
          }
        }
      }

      _insertMarkdownAtSelection(markdown);
      _save(createVersion: false);
      final status =
          attachment.alreadyExisted
              ? 'Вложение уже было в Vault; добавлена ссылка'
              : 'Вложение добавлено';
      messenger.showSnackBar(
        SnackBar(content: Text('$status: ${attachment.fileName}')),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось добавить вложение: $error')),
      );
    }
  }

  void _insertMarkdownAtSelection(String markdown) {
    final value = contentController.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final before =
        start > 0 && !value.text.substring(0, start).endsWith('\n') ? '\n' : '';
    final after =
        end < value.text.length && !value.text.substring(end).startsWith('\n')
            ? '\n'
            : '';
    final replacement = '$before$markdown$after';
    contentController.value = value.copyWith(
      text: value.text.replaceRange(start, end, replacement),
      selection: TextSelection.collapsed(offset: start + replacement.length),
      composing: TextRange.empty,
    );
  }

  Future<void> _editImageAtCursor() async {
    final value = contentController.value;
    final offset =
        value.selection.isValid
            ? value.selection.extentOffset
            : value.text.length;
    final reference = NoteImageSyntax.findAtOffset(value.text, offset);
    if (reference == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Поставь курсор на строку с изображением и повтори команду.',
          ),
        ),
      );
      return;
    }
    await _editImageReference(reference);
  }

  Future<void> _editImageReference(NoteImageReference reference) async {
    final current = NoteImageSyntax.relocate(contentController.text, reference);
    if (current == null) {
      return;
    }
    final result = await NoteImageEditorDialog.show(
      context,
      initial: current.presentation,
      imageLabel: current.alt,
    );
    if (result == null || !mounted) {
      return;
    }
    _replaceImagePresentation(current, result);
  }

  void _replaceImagePresentation(
    NoteImageReference reference,
    NoteImagePresentation presentation,
  ) {
    final value = contentController.value;
    final current = NoteImageSyntax.relocate(value.text, reference);
    if (current == null) {
      return;
    }
    final replacement = current.toMarkdown(presentation: presentation);
    final delta = replacement.length - (current.end - current.start);

    int moveOffset(int offset) {
      if (offset <= current.start) {
        return offset;
      }
      if (offset >= current.end) {
        return offset + delta;
      }
      return current.start + replacement.length;
    }

    final selection = value.selection;
    final updatedSelection =
        selection.isValid
            ? TextSelection(
              baseOffset: moveOffset(selection.baseOffset),
              extentOffset: moveOffset(selection.extentOffset),
              affinity: selection.affinity,
              isDirectional: selection.isDirectional,
            )
            : TextSelection.collapsed(
              offset: current.start + replacement.length,
            );

    contentController.value = value.copyWith(
      text: value.text.replaceRange(current.start, current.end, replacement),
      selection: updatedSelection,
      composing: TextRange.empty,
    );
    _save(createVersion: false);
  }

  Future<void> _configureColumnsAtCursor() async {
    final value = contentController.value;
    final selection = value.selection;
    final offset =
        selection.isValid ? selection.extentOffset : value.text.length;
    final existing = NoteColumnsSyntax.findAtOffset(value.text, offset);
    if (existing != null) {
      await _editColumnsReference(existing);
      return;
    }

    final result = await NoteColumnsEditorDialog.show(
      context,
      initial: const NoteColumnsLayout(
        columnCount: 2,
        widths: [40, 60],
      ),
      editingExisting: false,
    );
    if (result == null || !mounted) {
      return;
    }

    final selected =
        selection.isValid && !selection.isCollapsed
            ? value.text.substring(selection.start, selection.end).trim()
            : '';
    final layout = result.layout;
    final contents = <String>[
      'Изображение или текст',
      selected.isEmpty ? 'Текст правой колонки' : selected,
      if (layout.columnCount == 3) 'Текст третьей колонки',
    ];
    final markdown = NoteColumnsSyntax.build(
      widths: layout.widths,
      contents: contents,
    );
    _insertMarkdownAtSelection(markdown);
    _save(createVersion: false);
  }

  Future<void> _editColumnsReference(NoteColumnsReference reference) async {
    final current = NoteColumnsSyntax.relocate(
      contentController.text,
      reference,
    );
    if (current == null) {
      return;
    }
    final result = await NoteColumnsEditorDialog.show(
      context,
      initial: NoteColumnsLayout(
        columnCount: current.columnCount,
        widths: current.widths,
      ),
      editingExisting: true,
    );
    if (result == null || !mounted) {
      return;
    }
    if (result.unwrap) {
      _unwrapColumnsReference(
        current,
        contentOrder: result.contentOrder,
      );
      return;
    }
    _replaceColumnsLayout(
      current,
      result.layout,
      contentOrder: result.contentOrder,
    );
  }

  void _replaceColumnsWidths(
    NoteColumnsReference reference,
    List<int> widths,
  ) {
    final current = NoteColumnsSyntax.relocate(
      contentController.text,
      reference,
    );
    if (current == null) {
      return;
    }
    _replaceColumnsBlock(
      current,
      widths: widths,
      contents: [for (final column in current.columns) column.markdown],
    );
  }

  void _replaceColumnsLayout(
    NoteColumnsReference reference,
    NoteColumnsLayout layout, {
    List<int>? contentOrder,
  }) {
    final current = NoteColumnsSyntax.relocate(
      contentController.text,
      reference,
    );
    if (current == null) {
      return;
    }
    final contents = current.orderedContents(contentOrder);
    if (layout.columnCount > contents.length) {
      while (contents.length < layout.columnCount) {
        contents.add('Новая колонка');
      }
    } else if (layout.columnCount < contents.length) {
      final merged = contents.sublist(layout.columnCount - 1).join('\n\n');
      contents
        ..removeRange(layout.columnCount - 1, contents.length)
        ..add(merged);
    }
    _replaceColumnsBlock(
      current,
      widths: layout.widths,
      contents: contents,
    );
  }

  void _unwrapColumnsReference(
    NoteColumnsReference reference, {
    List<int>? contentOrder,
  }) {
    final current = NoteColumnsSyntax.relocate(
      contentController.text,
      reference,
    );
    if (current == null) {
      return;
    }
    _replaceColumnsText(
      current,
      current.toPlainMarkdown(order: contentOrder),
    );
  }

  void _replaceColumnsBlock(
    NoteColumnsReference reference, {
    required List<int> widths,
    required List<String> contents,
  }) {
    final current = NoteColumnsSyntax.relocate(
      contentController.text,
      reference,
    );
    if (current == null) {
      return;
    }
    _replaceColumnsText(
      current,
      current.toMarkdown(
        widths: widths,
        contents: contents,
      ),
    );
  }

  void _replaceColumnsText(
    NoteColumnsReference reference,
    String replacement,
  ) {
    final value = contentController.value;
    final current = NoteColumnsSyntax.relocate(value.text, reference);
    if (current == null) {
      return;
    }
    final delta = replacement.length - (current.end - current.start);

    int moveOffset(int offset) {
      if (offset <= current.start) {
        return offset;
      }
      if (offset >= current.end) {
        return offset + delta;
      }
      return current.start + replacement.length;
    }

    final selection = value.selection;
    final updatedSelection =
        selection.isValid
            ? TextSelection(
              baseOffset: moveOffset(selection.baseOffset),
              extentOffset: moveOffset(selection.extentOffset),
              affinity: selection.affinity,
              isDirectional: selection.isDirectional,
            )
            : TextSelection.collapsed(
              offset: current.start + replacement.length,
            );

    contentController.value = value.copyWith(
      text: value.text.replaceRange(current.start, current.end, replacement),
      selection: updatedSelection,
      composing: TextRange.empty,
    );
    _save(createVersion: false);
  }


  Future<void> _handleBlockAction(_NoteBlockAction action) async {
    final value = contentController.value;
    final offset =
        value.selection.isValid
            ? value.selection.extentOffset
            : value.text.length;
    final block = NoteBlockSyntax.findAtOffset(value.text, offset);
    if (block == null) {
      _showBlockMessage('В заметке пока нет блока для этой команды.');
      return;
    }

    if (action == _NoteBlockAction.copy) {
      await Clipboard.setData(ClipboardData(text: block.raw));
      if (mounted) {
        _showBlockMessage('Блок скопирован.');
      }
      return;
    }

    final result = switch (action) {
      _NoteBlockAction.moveUp => NoteBlockSyntax.moveUp(value.text, offset),
      _NoteBlockAction.moveDown => NoteBlockSyntax.moveDown(value.text, offset),
      _NoteBlockAction.duplicate => NoteBlockSyntax.duplicate(
        value.text,
        offset,
      ),
      _NoteBlockAction.delete => NoteBlockSyntax.delete(value.text, offset),
      _NoteBlockAction.paragraph => NoteBlockSyntax.convert(
        value.text,
        offset,
        NoteBlockConversion.paragraph,
      ),
      _NoteBlockAction.heading1 => NoteBlockSyntax.convert(
        value.text,
        offset,
        NoteBlockConversion.heading1,
      ),
      _NoteBlockAction.heading2 => NoteBlockSyntax.convert(
        value.text,
        offset,
        NoteBlockConversion.heading2,
      ),
      _NoteBlockAction.bulletedList => NoteBlockSyntax.convert(
        value.text,
        offset,
        NoteBlockConversion.bulletedList,
      ),
      _NoteBlockAction.checklist => NoteBlockSyntax.convert(
        value.text,
        offset,
        NoteBlockConversion.checklist,
      ),
      _NoteBlockAction.quote => NoteBlockSyntax.convert(
        value.text,
        offset,
        NoteBlockConversion.quote,
      ),
      _NoteBlockAction.copy => null,
    };

    if (result == null) {
      final message = switch (action) {
        _NoteBlockAction.moveUp => 'Этот блок уже находится первым.',
        _NoteBlockAction.moveDown => 'Этот блок уже находится последним.',
        _NoteBlockAction.paragraph ||
        _NoteBlockAction.heading1 ||
        _NoteBlockAction.heading2 ||
        _NoteBlockAction.bulletedList ||
        _NoteBlockAction.checklist ||
        _NoteBlockAction.quote =>
          'Этот тип блока нельзя преобразовать без потери разметки.',
        _ => 'Команда недоступна для выбранного блока.',
      };
      _showBlockMessage(message);
      return;
    }

    final previousValue = value;
    contentController.value = value.copyWith(
      text: result.text,
      selection: TextSelection(
        baseOffset: result.selectionStart,
        extentOffset: result.selectionEnd,
      ),
      composing: TextRange.empty,
    );

    if (action == _NoteBlockAction.delete && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Блок удалён.'),
            action: SnackBarAction(
              label: 'Отменить',
              onPressed: () {
                if (contentController.text != result.text) {
                  _showBlockMessage(
                    'После удаления текст уже изменился; автоматическая отмена '
                    'не применена.',
                  );
                  return;
                }
                contentController.value = previousValue;
              },
            ),
          ),
        );
    }
  }

  void _showBlockMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createTask() async {
    final task = await TaskEditorSheet.show(
      context,
      projects: widget.store.activeProjects,
      tasks: widget.store.data.tasks,
      initialProjectId: projectId,
      initialNoteId: widget.note.id,
    );
    if (task == null) return;
    widget.store.addTask(task);
    if (mounted) setState(() {});
  }

  Future<void> _openWikiLink(String title) async {
    _save(createVersion: false);
    var target = widget.store.noteByTitle(title);
    if (target == null) {
      final create = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text('Создать «$title»?'),
              content: const Text('Такой заметки пока нет в базе знаний.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Создать'),
                ),
              ],
            ),
      );
      if (create != true || !mounted) return;
      target = Note(
        id: const Uuid().v4(),
        title: title,
        projectId: projectId,
        body: '',
        folderPath: folderPath,
      );
      target.body = NoteDocument.serialize(target, '# $title\n\n');
      widget.store.addNote(target);
      await widget.store.rebuildAllNoteLinks();
    }
    if (!mounted) return;
    await _openNote(target);
  }

  Future<void> _openNote(Note? note) async {
    if (note == null || note.id == widget.note.id) return;
    _save(createVersion: false);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => NoteWorkspaceScreen(store: widget.store, note: note),
      ),
    );
    if (mounted) setState(() {});
  }

  void _restoreVersion(NoteVersion version) {
    widget.store.addNoteVersion(
      NoteVersion(
        id: const Uuid().v4(),
        noteId: widget.note.id,
        title: widget.note.title,
        body: widget.note.body,
        tags: List<String>.from(widget.note.tags),
        status: widget.note.status,
        folderPath: widget.note.folderPath,
        noteType: widget.note.noteType,
        properties: Map<String, String>.from(widget.note.properties),
        reason: 'Перед восстановлением',
      ),
    );
    widget.store.restoreNoteVersion(widget.note, version);
    final parsed = NoteDocument.parse(widget.note.body);
    titleController.text = widget.note.title;
    contentController.text = parsed.content;
    setState(() {
      projectId = widget.note.projectId;
      status = widget.note.status;
      folderPath = widget.note.folderPath;
      noteType = widget.note.noteType;
      tags = List<String>.from(widget.note.tags);
      properties = Map<String, String>.from(widget.note.properties);
      pinned = widget.note.pinned;
      dirty = false;
    });
  }
}

enum _NoteBlockAction {
  moveUp,
  moveDown,
  duplicate,
  copy,
  delete,
  paragraph,
  heading1,
  heading2,
  bulletedList,
  checklist,
  quote,
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.controller,
    required this.onAttach,
    required this.onConfigureImage,
    required this.onConfigureColumns,
    required this.onBlockAction,
  });

  final TextEditingController controller;
  final VoidCallback onAttach;
  final VoidCallback onConfigureImage;
  final VoidCallback onConfigureColumns;
  final ValueChanged<_NoteBlockAction> onBlockAction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final offset =
              value.selection.isValid
                  ? value.selection.extentOffset
                  : value.text.length;
          final blocks = NoteBlockSyntax.all(value.text);
          final block = NoteBlockSyntax.findIn(
            blocks,
            value.text.length,
            offset,
          );
          final canMoveUp = block != null && block.index > 0;
          final canMoveDown =
              block != null && block.index < blocks.length - 1;
          final canConvert = block?.supportsTextConversion ?? false;

          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              if (block != null)
                Tooltip(
                  message: 'Текущий блок: ${block.label}',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    child: Chip(
                      avatar: const Icon(Icons.view_agenda_outlined, size: 16),
                      label: Text(block.label),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Переместить блок выше',
                onPressed:
                    canMoveUp
                        ? () => onBlockAction(_NoteBlockAction.moveUp)
                        : null,
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
              ),
              IconButton(
                tooltip: 'Переместить блок ниже',
                onPressed:
                    canMoveDown
                        ? () => onBlockAction(_NoteBlockAction.moveDown)
                        : null,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
              PopupMenuButton<_NoteBlockAction>(
                tooltip: 'Действия с текущим блоком',
                enabled: block != null,
                onSelected: onBlockAction,
                itemBuilder:
                    (context) => [
                      const PopupMenuItem(
                        value: _NoteBlockAction.duplicate,
                        child: ListTile(
                          leading: Icon(Icons.copy_all_outlined),
                          title: Text('Дублировать блок'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: _NoteBlockAction.copy,
                        child: ListTile(
                          leading: Icon(Icons.content_copy_rounded),
                          title: Text('Копировать Markdown'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: _NoteBlockAction.paragraph,
                        enabled:
                            canConvert &&
                            block?.type != NoteBlockType.paragraph,
                        child: const ListTile(
                          leading: Icon(Icons.notes_rounded),
                          title: Text('Преобразовать в абзац'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: _NoteBlockAction.heading1,
                        enabled: canConvert,
                        child: const ListTile(
                          leading: Icon(Icons.looks_one_outlined),
                          title: Text('Преобразовать в заголовок 1'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: _NoteBlockAction.heading2,
                        enabled: canConvert,
                        child: const ListTile(
                          leading: Icon(Icons.looks_two_outlined),
                          title: Text('Преобразовать в заголовок 2'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: _NoteBlockAction.bulletedList,
                        enabled:
                            canConvert &&
                            block?.type != NoteBlockType.bulletedList,
                        child: const ListTile(
                          leading: Icon(Icons.format_list_bulleted_rounded),
                          title: Text('Преобразовать в список'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: _NoteBlockAction.checklist,
                        enabled:
                            canConvert &&
                            block?.type != NoteBlockType.checklist,
                        child: const ListTile(
                          leading: Icon(Icons.check_box_outlined),
                          title: Text('Преобразовать в чек-лист'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: _NoteBlockAction.quote,
                        enabled:
                            canConvert && block?.type != NoteBlockType.quote,
                        child: const ListTile(
                          leading: Icon(Icons.format_quote_rounded),
                          title: Text('Преобразовать в цитату'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: _NoteBlockAction.delete,
                        child: ListTile(
                          leading: Icon(Icons.delete_outline_rounded),
                          title: Text('Удалить блок'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                icon: const Icon(Icons.more_horiz_rounded),
              ),
              const VerticalDivider(indent: 10, endIndent: 10),
              _button(Icons.title_rounded, '# ', ''),
              _button(Icons.format_bold_rounded, '**', '**'),
              _button(Icons.format_italic_rounded, '_', '_'),
              _button(Icons.format_list_bulleted_rounded, '- ', ''),
              _button(Icons.check_box_outlined, '- [ ] ', ''),
              _button(Icons.link_rounded, '[[', ']]'),
              _button(Icons.functions_rounded, r'$', r'$'),
              _button(Icons.calculate_outlined, '\n\\[\n', '\n\\]\n'),
              IconButton(
                tooltip: 'Добавить локальное вложение',
                onPressed: onAttach,
                icon: const Icon(Icons.attach_file_rounded),
              ),
              IconButton(
                tooltip: 'Размер, выравнивание и подпись изображения',
                onPressed: onConfigureImage,
                icon: const Icon(Icons.photo_size_select_large_rounded),
              ),
              IconButton(
                tooltip: 'Вставить или настроить колонки',
                onPressed: onConfigureColumns,
                icon: const Icon(Icons.view_column_outlined),
              ),
              _button(Icons.image_outlined, '![описание](', ')'),
              _button(Icons.code_rounded, '```\n', '\n```'),
            ],
          );
        },
      ),
    );
  }

  Widget _button(IconData icon, String before, String after) {
    return IconButton(
      onPressed: () => _wrapSelection(before, after),
      icon: Icon(icon),
    );
  }

  void _wrapSelection(String before, String after) {
    final value = controller.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final selected = value.text.substring(start, end);
    final replacement = '$before$selected$after';
    controller.value = value.copyWith(
      text: value.text.replaceRange(start, end, replacement),
      selection: TextSelection.collapsed(
        offset: start + before.length + selected.length,
      ),
      composing: TextRange.empty,
    );
  }
}

class _LinkSection extends StatelessWidget {
  const _LinkSection({
    required this.title,
    required this.emptyText,
    required this.links,
    required this.resolve,
    required this.onOpen,
  });

  final String title;
  final String emptyText;
  final List<NoteLink> links;
  final Note? Function(NoteLink link) resolve;
  final ValueChanged<Note?> onOpen;

  @override
  Widget build(BuildContext context) {
    return _ContextCard(
      title: title,
      child:
          links.isEmpty
              ? Text(emptyText)
              : Column(
                children: [
                  for (final link in links)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.description_outlined),
                      title: Text(resolve(link)?.title ?? link.targetTitle),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => onOpen(resolve(link)),
                    ),
                ],
              ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _PropertyRow extends StatelessWidget {
  const _PropertyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 17),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _NotePropertiesSheet extends StatefulWidget {
  const _NotePropertiesSheet({required this.projects, required this.metadata});

  final List<Project> projects;
  final _NoteMetadata metadata;

  static Future<_NoteMetadata?> show(
    BuildContext context, {
    required List<Project> projects,
    required _NoteMetadata metadata,
  }) {
    return showModalBottomSheet<_NoteMetadata>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 700),
      builder:
          (_) => _NotePropertiesSheet(projects: projects, metadata: metadata),
    );
  }

  @override
  State<_NotePropertiesSheet> createState() => _NotePropertiesSheetState();
}

class _NotePropertiesSheetState extends State<_NotePropertiesSheet> {
  late String projectId;
  late String status;
  late String noteType;
  late bool pinned;
  late final TextEditingController folderController;
  late final TextEditingController tagsController;
  late final TextEditingController propertiesController;

  @override
  void initState() {
    super.initState();
    projectId = widget.metadata.projectId;
    status = widget.metadata.status;
    noteType = widget.metadata.noteType;
    pinned = widget.metadata.pinned;
    folderController = TextEditingController(text: widget.metadata.folderPath);
    tagsController = TextEditingController(
      text: widget.metadata.tags.join(', '),
    );
    propertiesController = TextEditingController(
      text: widget.metadata.properties.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('\n'),
    );
  }

  @override
  void dispose() {
    folderController.dispose();
    tagsController.dispose();
    propertiesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Свойства заметки',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: projectId,
                decoration: const InputDecoration(labelText: 'Проект'),
                items:
                    widget.projects
                        .map(
                          (project) => DropdownMenuItem(
                            value: project.id,
                            child: Text('${project.emoji} ${project.title}'),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => projectId = value);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: noteType,
                      decoration: const InputDecoration(labelText: 'Тип'),
                      items: const [
                        DropdownMenuItem(value: 'note', child: Text('Заметка')),
                        DropdownMenuItem(
                          value: 'lecture',
                          child: Text('Лекция'),
                        ),
                        DropdownMenuItem(
                          value: 'research',
                          child: Text('Исследование'),
                        ),
                        DropdownMenuItem(
                          value: 'literature',
                          child: Text('Источник'),
                        ),
                        DropdownMenuItem(
                          value: 'meeting',
                          child: Text('Встреча'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => noteType = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Статус'),
                      items: const [
                        DropdownMenuItem(
                          value: 'draft',
                          child: Text('Черновик'),
                        ),
                        DropdownMenuItem(
                          value: 'review',
                          child: Text('Проверка'),
                        ),
                        DropdownMenuItem(value: 'ready', child: Text('Готово')),
                        DropdownMenuItem(
                          value: 'archived',
                          child: Text('Архив'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => status = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: folderController,
                decoration: const InputDecoration(
                  labelText: 'Папка',
                  hintText: 'Лекции/Химия',
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
                controller: propertiesController,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Дополнительные YAML-свойства',
                  hintText: 'audience=8 класс\ndoi=10.1000/example',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: pinned,
                title: const Text('Закрепить заметку'),
                onChanged: (value) => setState(() => pinned = value),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Применить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    final properties = <String, String>{};
    for (final rawLine in propertiesController.text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final separator = line.indexOf('=');
      if (separator <= 0) continue;
      properties[line.substring(0, separator).trim()] =
          line.substring(separator + 1).trim();
    }
    Navigator.pop(
      context,
      _NoteMetadata(
        projectId: projectId,
        status: status,
        folderPath: folderController.text.trim(),
        noteType: noteType,
        tags: NoteDocument.parseTags(tagsController.text),
        properties: properties,
        pinned: pinned,
      ),
    );
  }
}

class _NoteMetadata {
  const _NoteMetadata({
    required this.projectId,
    required this.status,
    required this.folderPath,
    required this.noteType,
    required this.tags,
    required this.properties,
    required this.pinned,
  });

  final String projectId;
  final String status;
  final String folderPath;
  final String noteType;
  final List<String> tags;
  final Map<String, String> properties;
  final bool pinned;
}

class _NewNoteSheet extends StatefulWidget {
  const _NewNoteSheet({required this.projects});

  final List<Project> projects;

  static Future<_NewNoteRequest?> show(
    BuildContext context, {
    required List<Project> projects,
  }) {
    return showModalBottomSheet<_NewNoteRequest>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 700),
      builder: (_) => _NewNoteSheet(projects: projects),
    );
  }

  @override
  State<_NewNoteSheet> createState() => _NewNoteSheetState();
}

class _NewNoteSheetState extends State<_NewNoteSheet> {
  late String projectId;
  String templateId = 'blank';
  final titleController = TextEditingController();
  final folderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    projectId = widget.projects.first.id;
  }

  @override
  void dispose() {
    titleController.dispose();
    folderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Новая заметка',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: projectId,
                decoration: const InputDecoration(labelText: 'Проект'),
                items:
                    widget.projects
                        .map(
                          (project) => DropdownMenuItem(
                            value: project.id,
                            child: Text('${project.emoji} ${project.title}'),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => projectId = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: folderController,
                decoration: const InputDecoration(
                  labelText: 'Папка',
                  hintText: 'Например: Лекции/Химия',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Шаблон',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final template in noteTemplates)
                    ChoiceChip(
                      avatar: Text(template.icon),
                      label: Text(template.title),
                      selected: templateId == template.id,
                      onSelected:
                          (_) => setState(() => templateId = template.id),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      () => Navigator.pop(
                        context,
                        _NewNoteRequest(
                          projectId: projectId,
                          templateId: templateId,
                          title: titleController.text,
                          folderPath: folderController.text,
                        ),
                      ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Создать'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewNoteRequest {
  const _NewNoteRequest({
    required this.projectId,
    required this.templateId,
    required this.title,
    required this.folderPath,
  });

  final String projectId;
  final String templateId;
  final String title;
  final String folderPath;
}

class _EmptyNotes extends StatelessWidget {
  const _EmptyNotes({required this.hasFilters});

  final bool hasFilters;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_outlined, size: 54),
            const SizedBox(height: 12),
            Text(
              hasFilters ? 'Ничего не найдено' : 'Заметок пока нет',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              hasFilters
                  ? 'Измени поиск или фильтры.'
                  : 'Создай лекцию, конспект или исследовательскую запись.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

String _plainSnippet(String markdown) {
  return markdown
      .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
      .replaceAll(RegExp(r'[#>*_`~\[\]()!-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _statusLabel(String status) => switch (status) {
  'review' => 'Проверка',
  'ready' => 'Готово',
  'archived' => 'Архив',
  _ => 'Черновик',
};

String _dateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day.$month.${value.year} $hour:$minute';
}
