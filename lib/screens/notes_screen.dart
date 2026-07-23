import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../features/appearance/app_appearance.dart';
import '../features/notes/custom_note_template_dialog.dart';
import '../features/notes/debounced_text_notifier.dart';
import '../features/notes/note_block_reorder_dialog.dart';
import '../features/notes/note_block_syntax.dart';
import '../features/notes/note_columns_editor_dialog.dart';
import '../features/notes/note_columns_syntax.dart';
import '../features/notes/note_document.dart';
import '../features/notes/note_data_import.dart';
import '../features/notes/note_data_import_dialog.dart';
import '../features/notes/note_data_import_file_service.dart';
import '../features/notes/note_edit_history.dart';
import '../features/notes/note_editor_preferences_store.dart';
import '../features/notes/note_editor_profile.dart';
import '../features/notes/note_editor_profile_dialog.dart';
import '../features/notes/note_export.dart';
import '../features/notes/note_export_dialog.dart';
import '../features/notes/note_export_file_service.dart';
import '../features/notes/note_image_editor_dialog.dart';
import '../features/notes/note_image_syntax.dart';
import '../features/notes/note_link_dialogs.dart';
import '../features/notes/note_link_tools.dart';
import '../features/notes/laboratory_template_dialog.dart';
import '../features/notes/note_graph_screen.dart';
import '../features/notes/note_home_page.dart';
import '../features/notes/note_home_preferences.dart';
import '../features/notes/note_home_preferences_dialog.dart';
import '../features/notes/note_home_preferences_store.dart';
import '../features/notes/research_canvas_screen.dart';
import '../features/notes/note_markdown_view.dart';
import '../features/notes/note_templates.dart';
import '../features/notes/note_version_history_dialog.dart';
import '../features/notes/note_table_syntax.dart';
import '../features/notes/note_toolbar_preferences_store.dart';
import '../features/notes/note_toolbar_profile.dart';
import '../features/notes/note_toolbar_profile_dialog.dart';
import '../features/notes/note_wiki_link_syntax.dart';
import '../features/notes/note_wiki_rename.dart';
import '../features/notes/scientific_object_dialogs.dart';
import '../features/notes/scientific_table_editor_dialog.dart';
import '../features/notes/scientific_reference_syntax.dart';
import '../features/projects/project_appearance_store.dart';
import '../features/projects/project_appearance_widgets.dart';
import '../features/publications/publication_workspace.dart';
import '../features/publications/publication_workspace_screen.dart';
import '../features/references/citation_syntax.dart';
import '../features/tasks/task_editor_sheet.dart';
import '../models/app_models.dart';
import '../platform/clipboard_image_reader.dart';
import '../services/app_store.dart';
import 'sources_screen.dart';

Future<void> _showCustomNoteTemplateManager(
  BuildContext context,
  AppStore store,
) {
  return CustomNoteTemplateManagerDialog.show(
    context,
    templates: store.customNoteTemplates,
    onCreate:
        (draft) => store.createCustomNoteTemplate(
          title: draft.title,
          icon: draft.icon,
          noteType: draft.noteType,
          content: draft.content,
          category: draft.category,
          defaultTags: draft.defaultTags,
        ),
    onUpdate:
        (template, draft) => store.updateCustomNoteTemplate(
          id: template.id,
          title: draft.title,
          icon: draft.icon,
          noteType: draft.noteType,
          content: draft.content,
          category: draft.category,
          defaultTags: draft.defaultTags,
          defaultProperties: template.defaultProperties,
        ),
    onDelete: (template) => store.deleteCustomNoteTemplate(template.id),
    onDuplicate:
        (template) => store.duplicateCustomNoteTemplate(template.id),
    onImport: store.importCustomNoteTemplates,
  );
}

class NotesScreen extends StatefulWidget {
  const NotesScreen({
    super.key,
    required this.store,
    required this.appearanceController,
    required this.globalAppearance,
  });

  final AppStore store;
  final ProjectAppearanceController appearanceController;
  final AppAppearancePreferences globalAppearance;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final NoteHomePreferencesStore _homePreferencesStore =
      NoteHomePreferencesStore();
  NoteHomePreferences _homePreferences = NoteHomePreferences.defaults();
  String query = '';
  String? folderFilter;
  String? projectFilter;
  bool pinnedOnly = false;
  bool _showHome = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadHomePreferences());
  }

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
        title: Text(_showHome ? 'Обзор заметок' : 'Заметки'),
        actions: [
          IconButton(
            tooltip: _showHome ? 'Все заметки' : 'Обзор заметок',
            onPressed: () => setState(() => _showHome = !_showHome),
            icon: Icon(
              _showHome
                  ? Icons.library_books_outlined
                  : Icons.space_dashboard_outlined,
            ),
          ),
          if (_showHome)
            IconButton(
              tooltip: 'Настроить обзор',
              onPressed: _openHomePreferences,
              icon: const Icon(Icons.tune_rounded),
            ),
          IconButton(
            tooltip: 'Источники',
            onPressed: _openSources,
            icon: const Icon(Icons.library_books_outlined),
          ),
          IconButton(
            tooltip: 'Карта знаний',
            onPressed: _openKnowledgeGraph,
            icon: const Icon(Icons.hub_outlined),
          ),
          IconButton(
            tooltip: 'Карта исследования',
            onPressed: _openResearchCanvas,
            icon: const Icon(Icons.dashboard_customize_outlined),
          ),
          IconButton(
            tooltip: 'Проверить ссылки',
            onPressed: _openLinkHealth,
            icon: const Icon(Icons.link_off_rounded),
          ),
          if (!_showHome)
            IconButton(
              tooltip: pinnedOnly ? 'Показать все' : 'Только закреплённые',
              onPressed: () => setState(() => pinnedOnly = !pinnedOnly),
              icon: Icon(
                pinnedOnly ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              ),
            ),
          IconButton(
            tooltip: 'Новая заметка',
            onPressed: widget.store.activeProjects.isEmpty
                ? null
                : () => _add(),
            icon: const Icon(Icons.note_add_outlined),
          ),
        ],
      ),
      body: _showHome
          ? NoteHomePage(
              store: widget.store,
              preferences: _homePreferences,
              appearanceController: widget.appearanceController,
              globalAppearance: widget.globalAppearance,
              onOpenNote: _open,
              onOpenProject: (projectId) {
                setState(() {
                  projectFilter = projectId;
                  folderFilter = null;
                  pinnedOnly = false;
                  _showHome = false;
                });
              },
              onOpenFolder: (folder) {
                setState(() {
                  folderFilter = folder;
                  projectFilter = null;
                  pinnedOnly = false;
                  _showHome = false;
                });
              },
              onCreateFromTemplate: (template) =>
                  _add(initialTemplateId: template.id),
              onOpenLibrary: () => setState(() => _showHome = false),
              onConfigure: _openHomePreferences,
            )
          : Column(
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
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ProjectAvatar(
                                    project: project,
                                    controller: widget.appearanceController,
                                    size: 22,
                                    borderRadius: 6,
                                    emojiFontSize: 15,
                                  ),
                                  const SizedBox(width: 7),
                                  Text(project.title),
                                ],
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => projectFilter = value),
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
                          onSelected: (_) =>
                              setState(() => folderFilter = folder),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: notes.isEmpty
                      ? _EmptyNotes(
                          hasFilters: normalizedQuery.isNotEmpty ||
                              pinnedOnly ||
                              folderFilter != null ||
                              projectFilter != null,
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 1180
                                ? 3
                                : constraints.maxWidth >= 760
                                    ? 2
                                    : 1;
                            return GridView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                10,
                                16,
                                110,
                              ),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisExtent: 218,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: notes.length,
                              itemBuilder: (_, index) => _NoteCard(
                                store: widget.store,
                                note: notes[index],
                                appearanceController: widget.appearanceController,
                                onOpen: () => _open(notes[index]),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.store.activeProjects.isEmpty ? null : () => _add(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Заметка'),
      ),
    );
  }

  Future<void> _loadHomePreferences() async {
    final preferences = await _homePreferencesStore.load();
    if (!mounted) return;
    setState(() {
      _homePreferences = preferences;
      _showHome = preferences.openOnHome;
    });
  }

  Future<void> _openHomePreferences() async {
    final updated = await NoteHomePreferencesDialog.show(
      context,
      initialValue: _homePreferences,
    );
    if (updated == null || !mounted) return;
    try {
      await _homePreferencesStore.save(updated);
      if (!mounted) return;
      setState(() => _homePreferences = updated);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить обзор: $error')),
      );
    }
  }

  Future<void> _openLinkHealth() async {
    while (true) {
      if (!mounted) return;
      final issues = widget.store.wikiLinkIssues();
      final selection = await showDialog<_LinkHealthSelection>(
        context: context,
        builder:
            (context) => _LinkHealthDialog(
              store: widget.store,
              issues: issues,
            ),
      );
      if (!mounted || selection == null) return;
      final source = widget.store.noteById(selection.issue.sourceNoteId);
      if (source == null) continue;
      if (!selection.repair) {
        await _open(source);
        return;
      }
      await _repairLinkIssue(selection.issue, source);
    }
  }

  Future<void> _repairLinkIssue(
    NoteWikiLinkIssue issue,
    Note source,
  ) async {
    Note? target;
    if (issue.kind == NoteWikiLinkIssueKind.ambiguous) {
      final candidates = issue.candidateNoteIds
          .map(widget.store.noteById)
          .whereType<Note>()
          .toList(growable: false);
      target = await showDialog<Note>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text('Куда должна вести «${issue.rawTarget}»?'),
              content: SizedBox(
                width: 460,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final candidate in candidates)
                      ListTile(
                        leading: Text(noteTypeIcon(candidate.noteType)),
                        title: Text(candidate.title),
                        subtitle: Text(
                          _noteLocationLabel(widget.store, candidate),
                        ),
                        onTap: () => Navigator.pop(context, candidate),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
              ],
            ),
      );
    } else {
      final reference = NoteWikiTarget.parse(issue.rawTarget);
      if (reference.noteId != null || reference.noteTitle.trim().isEmpty) {
        await _open(source);
        return;
      }
      final create = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text('Создать «${reference.noteTitle}»?'),
              content: Text(
                'Новая заметка будет создана рядом с «${source.title}», '
                'а ссылка станет точной и устойчивой к переименованию.',
              ),
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
      var targetProjectId = source.projectId;
      final requestedProject = reference.projectTitle?.trim().toLowerCase();
      if (requestedProject != null) {
        for (final project in widget.store.data.projects) {
          if (project.title.trim().toLowerCase() == requestedProject) {
            targetProjectId = project.id;
            break;
          }
        }
      }
      target = Note(
        id: const Uuid().v4(),
        title: reference.noteTitle,
        projectId: targetProjectId,
        body: '',
        folderPath:
            targetProjectId == source.projectId ? source.folderPath : '',
      );
      target.body = NoteDocument.serialize(
        target,
        '# ${reference.noteTitle}\n\n',
      );
      widget.store.addNote(target);
      await widget.store.rebuildAllNoteLinks();
    }
    if (target == null) return;
    await widget.store.repairWikiLink(
      source: source,
      rawTarget: issue.rawTarget,
      target: target,
    );
  }

  Future<void> _openSources() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SourcesScreen(store: widget.store),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openKnowledgeGraph() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder:
            (_) => NoteGraphScreen(
              store: widget.store,
              onOpenNote: _open,
            ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openResearchCanvas() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ResearchCanvasScreen(
          store: widget.store,
          onOpenNote: _open,
        ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _add({String? initialTemplateId}) async {
    final request = await _NewNoteSheet.show(
      context,
      store: widget.store,
      initialTemplateId: initialTemplateId,
    );
    if (request == null || !mounted) return;

    final template = widget.store.availableNoteTemplates.firstWhere(
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
    if (PublicationWorkspaceCodec.isPublication(note)) {
      final project = widget.store.projectById(note.projectId);
      if (project == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не найден проект этого документа.'),
          ),
        );
        return;
      }
      await PublicationWorkspaceScreen.show(
        context,
        store: widget.store,
        project: project,
        publication: note,
        readOnly: project.archived,
      );
    } else {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => NoteWorkspaceScreen(
            store: widget.store,
            note: note,
            appearanceController: widget.appearanceController,
            globalAppearance: widget.globalAppearance,
          ),
        ),
      );
    }
    if (mounted) setState(() {});
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.store,
    required this.note,
    required this.appearanceController,
    required this.onOpen,
  });

  final AppStore store;
  final Note note;
  final ProjectAppearanceController appearanceController;
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
                  if (project == null)
                    const Text('📁')
                  else
                    ProjectAvatar(
                      project: project,
                      controller: appearanceController,
                      size: 20,
                      borderRadius: 6,
                      emojiFontSize: 14,
                    ),
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
    required this.appearanceController,
    required this.globalAppearance,
  });

  final AppStore store;
  final Note note;
  final ProjectAppearanceController appearanceController;
  final AppAppearancePreferences globalAppearance;

  @override
  State<NoteWorkspaceScreen> createState() => _NoteWorkspaceScreenState();
}

class _NoteWorkspaceScreenState extends State<NoteWorkspaceScreen> {
  late final TextEditingController titleController;
  late final TextEditingController contentController;
  late final NoteEditHistory _editHistory;
  late final DebouncedTextNotifier _previewTextNotifier;
  late final DebouncedTextNotifier _statisticsTextNotifier;
  final NoteEditorPreferencesStore _editorPreferencesStore =
      NoteEditorPreferencesStore();
  final NoteToolbarPreferencesStore _toolbarPreferencesStore =
      NoteToolbarPreferencesStore();
  NoteEditorPreferences _editorPreferences = NoteEditorPreferences.defaults();
  NoteToolbarPreferences _toolbarPreferences =
      NoteToolbarPreferences.defaults();
  bool _editorProfileLoaded = false;
  bool _toolbarPreferencesLoaded = false;
  bool _modeChangedManually = false;
  late final ScrollController _editorScrollController;
  late final ScrollController _previewScrollController;
  Timer? _previewScrollResumeTimer;
  Timer? _autosaveTimer;
  double _editorScrollOffset = 0;
  late String projectId;
  late String status;
  late String folderPath;
  late String noteType;
  late List<String> tags;
  late Map<String, String> properties;
  late bool pinned;
  late String _lastTitleText;
  late String _lastContentText;
  bool _suppressTextChangeTracking = false;
  bool dirty = false;
  bool _renameReviewBusy = false;
  bool _clipboardPasteBusy = false;
  bool _dataImportBusy = false;
  bool _exportBusy = false;
  int mode = 0;

  @override
  void initState() {
    super.initState();
    final parsed = NoteDocument.parse(widget.note.body);
    titleController = TextEditingController(text: widget.note.title);
    contentController = TextEditingController(text: parsed.content);
    _editHistory = NoteEditHistory(controller: contentController);
    _previewTextNotifier = DebouncedTextNotifier(
      parsed.content,
      delay: const Duration(milliseconds: 260),
    );
    _statisticsTextNotifier = DebouncedTextNotifier(
      parsed.content,
      delay: const Duration(milliseconds: 420),
    );
    _editorScrollController = ScrollController()
      ..addListener(_rememberEditorScrollOffset);
    _previewScrollController = ScrollController();
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
    _lastTitleText = titleController.text;
    _lastContentText = contentController.text;
    titleController.addListener(_markDirty);
    contentController.addListener(_markDirty);
    unawaited(_loadEditorPreferences());
    unawaited(_loadToolbarPreferences());
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _previewScrollResumeTimer?.cancel();
    _editHistory.dispose();
    titleController.dispose();
    contentController.dispose();
    _editorScrollController
      ..removeListener(_rememberEditorScrollOffset)
      ..dispose();
    _previewScrollController.dispose();
    _previewTextNotifier.dispose();
    _statisticsTextNotifier.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (_suppressTextChangeTracking) {
      return;
    }
    final nextTitle = titleController.text;
    final nextContent = contentController.text;
    final titleChanged = nextTitle != _lastTitleText;
    final contentChanged = nextContent != _lastContentText;
    if (!titleChanged && !contentChanged) {
      return;
    }
    _lastTitleText = nextTitle;
    _lastContentText = nextContent;
    if (contentChanged) {
      _statisticsTextNotifier.schedule(nextContent);
      if (mode != 0) {
        _previewTextNotifier.schedule(nextContent);
      }
    }
    _scheduleAutosave();
    if (!dirty && mounted) {
      setState(() => dirty = true);
    }
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    if (_proposedTitle != widget.note.title || _renameReviewBusy) {
      return;
    }
    _autosaveTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || !dirty || _renameReviewBusy) {
        return;
      }
      if (_proposedTitle == widget.note.title) {
        _save(createVersion: false);
      }
    });
  }

  void _rememberEditorScrollOffset() {
    if (_editorScrollController.hasClients) {
      _editorScrollOffset = _editorScrollController.offset;
    }
  }

  void _restoreEditorScrollOffset() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_editorScrollController.hasClients) {
        return;
      }
      final position = _editorScrollController.position;
      final target = _editorScrollOffset
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if ((position.pixels - target).abs() > 0.5) {
        _editorScrollController.jumpTo(target);
      }
    });
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
    final editorProfile = _editorPreferences.activeProfile;

    return ProjectAppearanceScope(
      projectId: projectId,
      controller: widget.appearanceController,
      globalAppearance: widget.globalAppearance,
      child: PopScope(
        onPopInvokedWithResult: (_, __) {
          if (dirty) _save(createVersion: false);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
          final showPanel =
              constraints.maxWidth >= 860 && editorProfile.showContextPanel;
          final split = constraints.maxWidth >= 1180;
          final effectiveMode = mode == 2 && !split ? 0 : mode;
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
                  onPressed:
                      dirty && !_renameReviewBusy
                          ? () => unawaited(
                            _saveWithRenameReview(createVersion: true),
                          )
                          : null,
                  icon: const Icon(Icons.save_outlined),
                ),
                IconButton(
                  tooltip: 'Редактор',
                  onPressed: () => _switchMode(0),
                  icon: Icon(
                    effectiveMode == 0 ? Icons.edit_rounded : Icons.edit_outlined,
                  ),
                ),
                IconButton(
                  tooltip: 'Предпросмотр',
                  onPressed: () => _switchMode(1),
                  icon: Icon(
                    effectiveMode == 1
                        ? Icons.visibility_rounded
                        : Icons.visibility_outlined,
                  ),
                ),
                if (split)
                  IconButton(
                    tooltip: 'Разделить редактор',
                    onPressed: () => _switchMode(2),
                    icon: Icon(
                      effectiveMode == 2
                          ? Icons.vertical_split_rounded
                          : Icons.vertical_split_outlined,
                    ),
                  ),
                _editorProfileSwitcher(),
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
                    switch (value) {
                      case 'copy_stable_link':
                        unawaited(_copyStableNoteLink());
                        break;
                      case 'link_mentions':
                        unawaited(_linkUnlinkedMentions());
                        break;
                      case 'delete':
                        widget.store.deleteNote(widget.note.id);
                        Navigator.pop(context);
                        break;
                    }
                  },
                  itemBuilder:
                      (_) => const [
                        PopupMenuItem(
                          value: 'copy_stable_link',
                          child: ListTile(
                            leading: Icon(Icons.link_rounded),
                            title: Text('Копировать устойчивую ссылку'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'link_mentions',
                          child: ListTile(
                            leading: Icon(Icons.auto_fix_high_rounded),
                            title: Text('Связать упоминания'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete_outline_rounded),
                            title: Text('Удалить'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
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
            floatingActionButton: editorProfile.showTimerButton
                ? FloatingActionButton.extended(
                    onPressed: () {
                      _save(createVersion: false);
                      widget.store.startTimer(
                        description: 'Работа над ${widget.note.title}',
                        projectId: projectId,
                        noteId: widget.note.id,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Таймер запущен')),
                      );
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Работать'),
                  )
                : null,
            body: Row(
              children: [
                Expanded(
                  child:
                      effectiveMode == 2 && split
                          ? Row(
                            children: [
                              Expanded(child: _editorPane()),
                              const VerticalDivider(width: 1),
                              Expanded(child: _previewPane()),
                            ],
                          )
                          : effectiveMode == 1
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
      ),
    );
  }

  void _switchMode(int nextMode) {
    _modeChangedManually = true;
    if (nextMode == mode) {
      return;
    }
    _rememberEditorScrollOffset();
    if (nextMode != 0) {
      _previewTextNotifier.setImmediate(contentController.text);
    }
    _statisticsTextNotifier.flush();
    if (!mounted) {
      return;
    }
    setState(() => mode = nextMode);
    if (nextMode != 1) {
      _restoreEditorScrollOffset();
    }
  }

  Widget _editorPane() {
    final profile = _editorPreferences.activeProfile;
    return Column(
      children: [
        if (profile.showTitle)
          Padding(
            padding: EdgeInsets.fromLTRB(
              profile.density.horizontalPadding,
              8,
              10,
              4,
            ),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: titleController,
              builder: (context, titleValue, _) {
                final proposed = titleValue.text.trim();
                final titleChanged =
                    proposed.isNotEmpty && proposed != widget.note.title;
                return Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: titleController,
                        onSubmitted: (_) => unawaited(
                          _saveWithRenameReview(createVersion: false),
                        ),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          filled: false,
                          hintText: 'Название',
                        ),
                      ),
                    ),
                    if (titleChanged)
                      IconButton(
                        tooltip: 'Предпросмотр безопасного переименования',
                        onPressed: _renameReviewBusy
                            ? null
                            : () => unawaited(
                                _saveWithRenameReview(createVersion: false),
                              ),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                  ],
                );
              },
            ),
          ),
        if (profile.showToolbar)
          _EditorToolbar(
            controller: contentController,
            history: _editHistory,
            toolbarPreferences: _toolbarPreferences,
            toolbarPreferencesLoaded: _toolbarPreferencesLoaded,
            onActivateToolbarProfile: (id) =>
                unawaited(_activateToolbarProfile(id)),
            onManageToolbarProfiles: () =>
                unawaited(_openToolbarProfileManager()),
            onUndo: () => _editHistory.undo(),
            onRedo: () => _editHistory.redo(),
            onAttach: _attachFile,
            onPasteImage: () => unawaited(_pasteImageFromClipboard()),
            onConfigureImage: _editImageAtCursor,
            onConfigureColumns: _configureColumnsAtCursor,
            onReorderBlocks: _reorderBlocks,
            onBlockAction: _handleBlockAction,
            onInsertNoteLink: _insertNoteLinks,
            onInsertCitation: _insertCitation,
            onInsertBibliography: _insertBibliography,
            onInsertScientificTable: _insertScientificTable,
            onImportData: () => unawaited(_importDataFiles()),
            onExport: () => unawaited(_exportCurrentNote()),
            onInsertScientificReference: _insertScientificReference,
            onInspectScientificObjects: _inspectScientificObjects,
            onApplyLaboratoryTemplate: _applyLaboratoryTemplate,
            onSaveAsTemplate: _saveCurrentNoteAsTemplate,
            onManageTemplates: _manageCustomTemplates,
          ),
        if (profile.showLinkSuggestions)
          _WikiLinkSuggestionsBar(
            controller: contentController,
            store: widget.store,
            currentNoteId: widget.note.id,
            sourceProjectId: projectId,
            sourceFolderPath: folderPath,
          ),
        const Divider(height: 1),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleEditorScrollNotification,
            child: Focus(
              onKeyEvent: _handleEditorKeyEvent,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: profile.contentWidth > 0
                        ? profile.contentWidth
                        : double.infinity,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextField(
                      controller: contentController,
                      scrollController: _editorScrollController,
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      style: TextStyle(
                        fontFamily: profile.fontFamily,
                        fontSize: profile.fontSize,
                        height: profile.lineHeight,
                      ),
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: profile.density.horizontalPadding,
                          vertical: profile.density.verticalPadding,
                        ),
                        border: InputBorder.none,
                        filled: false,
                        hintText: r'Markdown, $LaTeX$, [[ссылки]], изображения…',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _previewPane() {
    final profile = _editorPreferences.activeProfile;
    final mediaQuery = MediaQuery.of(context);
    return NotificationListener<ScrollNotification>(
      onNotification: _handlePreviewScrollNotification,
      child: ValueListenableBuilder<String>(
        valueListenable: _previewTextNotifier,
        builder: (context, text, _) {
          return RepaintBoundary(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: profile.contentWidth > 0
                      ? profile.contentWidth
                      : double.infinity,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: MediaQuery(
                    data: mediaQuery.copyWith(
                      textScaler: TextScaler.linear(profile.previewScale),
                    ),
                    child: NoteMarkdownView(
                      key: PageStorageKey<String>(
                        'note-preview-${widget.note.id}',
                      ),
                      markdown: text,
                      controller: _previewScrollController,
                      onWikiLink: _openWikiLink,
                      onEditImage: _editImageReference,
                      onResizeImage: _replaceImagePresentation,
                      onEditColumns: _editColumnsReference,
                      onResizeColumns: _replaceColumnsWidths,
                      assetListenable: widget.store.attachmentRefreshListenable,
                      citationSources: widget.store.data.citationSources,
                      vaultRootPath: widget.store.vaultStatus.rootPath,
                      padding: EdgeInsets.fromLTRB(
                        profile.density.horizontalPadding,
                        profile.density.verticalPadding,
                        profile.density.horizontalPadding,
                        120,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  bool _handleEditorScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _autosaveTimer?.cancel();
    } else if (notification is ScrollEndNotification && dirty) {
      _scheduleAutosave();
    }
    return false;
  }

  bool _handlePreviewScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _autosaveTimer?.cancel();
      _previewScrollResumeTimer?.cancel();
      _previewTextNotifier.pause();
    } else if (notification is ScrollEndNotification) {
      _previewScrollResumeTimer?.cancel();
      _previewScrollResumeTimer = Timer(
        const Duration(milliseconds: 140),
        () {
          _previewTextNotifier.resume();
          if (dirty) {
            _scheduleAutosave();
          }
        },
      );
    }
    return false;
  }

  Future<void> _loadEditorPreferences() async {
    NoteEditorPreferences loaded;
    try {
      loaded = await _editorPreferencesStore.load();
    } on Object {
      loaded = NoteEditorPreferences.defaults();
    }
    if (!mounted) return;
    setState(() {
      _editorPreferences = loaded;
      _editorProfileLoaded = true;
      if (!_modeChangedManually) {
        mode = loaded.activeProfile.startMode.value;
      }
    });
    if (mode != 0) {
      _previewTextNotifier.setImmediate(contentController.text);
    }
  }

  Future<void> _activateEditorProfile(String id) async {
    NoteEditorProfile? profile;
    for (final candidate in _editorPreferences.profiles) {
      if (candidate.id == id) {
        profile = candidate;
        break;
      }
    }
    if (profile == null) return;
    final selectedProfile = profile;
    final next = _editorPreferences.copyWith(activeProfileId: id);
    setState(() {
      _editorPreferences = next;
      mode = selectedProfile.startMode.value;
      _modeChangedManually = false;
    });
    if (mode != 0) {
      _previewTextNotifier.setImmediate(contentController.text);
    }
    await _saveEditorPreferences(next);
  }

  Future<void> _openEditorProfileManager() async {
    final result = await NoteEditorProfileDialog.show(
      context,
      preferences: _editorPreferences,
    );
    if (!mounted || result == null) return;
    setState(() {
      _editorPreferences = result;
      mode = result.activeProfile.startMode.value;
      _modeChangedManually = false;
    });
    if (mode != 0) {
      _previewTextNotifier.setImmediate(contentController.text);
    }
    await _saveEditorPreferences(result);
  }

  Future<void> _saveEditorPreferences(NoteEditorPreferences value) async {
    try {
      await _editorPreferencesStore.save(value);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить профиль: $error')),
      );
    }
  }

  Widget _editorProfileSwitcher() {
    final profile = _editorPreferences.activeProfile;
    final colors = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: _editorProfileLoaded
          ? 'Профиль редактора: ${profile.name}'
          : 'Профиль редактора',
      onSelected: (value) {
        if (value == '__manage__') {
          unawaited(_openEditorProfileManager());
        } else {
          unawaited(_activateEditorProfile(value));
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        for (final candidate in _editorPreferences.profiles)
          PopupMenuItem<String>(
            value: candidate.id,
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    candidate.emoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                Expanded(child: Text(candidate.name)),
                if (candidate.id == _editorPreferences.activeProfileId)
                  Icon(Icons.check_rounded, color: colors.primary),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: '__manage__',
          child: Row(
            children: [
              Icon(Icons.tune_rounded),
              SizedBox(width: 12),
              Text('Настроить редактор'),
            ],
          ),
        ),
      ],
      icon: Text(profile.emoji, style: const TextStyle(fontSize: 18)),
    );
  }

  Future<void> _loadToolbarPreferences() async {
    NoteToolbarPreferences loaded;
    try {
      loaded = await _toolbarPreferencesStore.load();
    } on Object {
      loaded = NoteToolbarPreferences.defaults();
    }
    if (!mounted) return;
    setState(() {
      _toolbarPreferences = loaded;
      _toolbarPreferencesLoaded = true;
    });
  }

  Future<void> _activateToolbarProfile(String id) async {
    final exists = _toolbarPreferences.profiles.any(
      (profile) => profile.id == id,
    );
    if (!exists) return;
    final next = _toolbarPreferences.copyWith(activeProfileId: id);
    setState(() => _toolbarPreferences = next);
    await _saveToolbarPreferences(next);
  }

  Future<void> _openToolbarProfileManager() async {
    final result = await NoteToolbarProfileDialog.show(
      context,
      preferences: _toolbarPreferences,
    );
    if (!mounted || result == null) return;
    setState(() => _toolbarPreferences = result);
    await _saveToolbarPreferences(result);
  }

  Future<void> _saveToolbarPreferences(NoteToolbarPreferences value) async {
    try {
      await _toolbarPreferencesStore.save(value);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось сохранить панель действий: $error'),
        ),
      );
    }
  }

  Widget _contextPanel({
    required List<NoteLink> backlinks,
    required List<NoteLink> outgoing,
    required List<WorkTask> linkedTasks,
    required List<NoteVersion> versions,
  }) {
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
          child: ValueListenableBuilder<String>(
            valueListenable: _statisticsTextNotifier,
            builder: (context, text, _) {
              final words = NoteDocument.wordCount(text);
              final minutes = NoteDocument.readingMinutes(text);
              return Wrap(
                spacing: 14,
                runSpacing: 8,
                children: [
                  _StatChip(
                    icon: Icons.text_fields_rounded,
                    label: '$words слов',
                  ),
                  _StatChip(
                    icon: Icons.menu_book_rounded,
                    label: '$minutes мин',
                  ),
                  _StatChip(
                    icon: Icons.timer_outlined,
                    label: '${(seconds / 3600).toStringAsFixed(1)} ч',
                  ),
                  _StatChip(
                    icon: Icons.history_rounded,
                    label: 'rev ${widget.note.revision}',
                  ),
                ],
              );
            },
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
          subtitle: (link, source) {
            if (source == null) return null;
            final content = NoteDocument.parse(source.body).content;
            return NoteWikiLinkSyntax.snippetForTarget(
              content,
              link.targetTitle,
            );
          },
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
                      ? widget.store.resolveWikiTarget(
                        link.targetTitle,
                        source: widget.note,
                      )
                      : widget.store.noteById(link.targetNoteId!),
          subtitle: (link, target) {
            if (target == null) {
              final candidates = widget.store.notesForWikiTarget(
                link.targetTitle,
                source: widget.note,
              );
              return candidates.isEmpty
                  ? 'Цель не найдена — можно создать заметку'
                  : 'Найдено несколько заметок — выбери нужную';
            }
            final project = widget.store.projectById(target.projectId);
            final location = [
              project?.title,
              if (target.folderPath.trim().isNotEmpty) target.folderPath,
            ].whereType<String>().join(' · ');
            return location.isEmpty ? null : location;
          },
          onOpen: _openNote,
          onMissing: (link) => _openWikiLink(link.targetTitle),
          missingActionLabel: (link) {
            final candidates = widget.store.notesForWikiTarget(
              link.targetTitle,
              source: widget.note,
            );
            return candidates.isEmpty ? 'Создать' : 'Выбрать';
          },
        ),
        const SizedBox(height: 10),
        _ContextCard(
          title: 'История версий',
          action:
              versions.isEmpty
                  ? null
                  : TextButton.icon(
                    onPressed: () => _openVersionHistory(),
                    icon: const Icon(Icons.manage_history_rounded, size: 18),
                    label: const Text('Все версии'),
                  ),
          child:
              versions.isEmpty
                  ? const Text('Версии появятся после ручного сохранения')
                  : Column(
                    children: [
                      for (final version in versions.take(3))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.history_rounded),
                          title: Text(_dateTime(version.createdAt)),
                          subtitle: Text(
                            version.reason,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: TextButton(
                            onPressed:
                                () => _openVersionHistory(
                                  initialVersionId: version.id,
                                ),
                            child: const Text('Сравнить'),
                          ),
                        ),
                    ],
                  ),
        ),
      ],
    );
  }

  void _save({required bool createVersion}) {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    _editHistory.flush();
    if (!dirty && !createVersion) return;
    final proposedTitle = _proposedTitle;
    final titleChanged = proposedTitle != widget.note.title;
    final renamePlan =
        titleChanged
            ? widget.store.buildWikiRenamePlan(widget.note, proposedTitle)
            : null;
    final needsReview = renamePlan?.requiresReview ?? false;

    if (createVersion && dirty && !needsReview) {
      _recordCurrentVersion('Ручное сохранение');
    }
    final savedTitle = needsReview ? widget.note.title : proposedTitle;
    _writeEditorState(savedTitle: savedTitle);
    _lastContentText = contentController.text;
    if (needsReview) {
      _lastTitleText = widget.note.title;
      if (mounted) setState(() => dirty = true);
    } else {
      _lastTitleText = titleController.text;
      if (mounted) setState(() => dirty = false);
    }
  }

  Future<void> _saveWithRenameReview({required bool createVersion}) async {
    if (_renameReviewBusy) return;
    final proposedTitle = _proposedTitle;
    if (proposedTitle == widget.note.title) {
      _save(createVersion: createVersion);
      return;
    }

    setState(() => _renameReviewBusy = true);
    try {
      final oldTitle = widget.note.title;
      _assignEditorState(savedTitle: oldTitle);
      _lastContentText = contentController.text;
      _lastTitleText = oldTitle;
      final plan = widget.store.buildWikiRenamePlan(
        widget.note,
        proposedTitle,
      );

      if (!plan.requiresReview) {
        final previous = NoteWikiSnapshot(
          noteId: widget.note.id,
          title: oldTitle,
          body: widget.note.body,
        );
        if (createVersion) {
          _recordCurrentVersion('Перед переименованием заметки');
        }
        widget.note.title = proposedTitle;
        widget.store.updateNote(widget.note);
        final undo = NoteWikiRenameUndo(
          snapshots: [previous],
          appliedSnapshots: [
            NoteWikiSnapshot(
              noteId: widget.note.id,
              title: widget.note.title,
              body: widget.note.body,
            ),
          ],
        );
        _reloadEditorFromNote();
        _showRenameUndo(
          undo,
          'Заметка переименована; связанных ссылок для обновления нет.',
        );
        return;
      }

      final decision = await showDialog<_WikiRenameDecision>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _WikiRenamePreviewDialog(plan: plan),
      );
      if (!mounted || decision == null || decision == _WikiRenameDecision.cancel) {
        widget.store.updateNote(widget.note);
        setState(() => dirty = true);
        return;
      }

      if (decision == _WikiRenameDecision.renameOnly) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Оставить старые ссылки?'),
                content: const Text(
                  'Ссылки с прежним названием перестанут открываться до '
                  'ручного исправления. Безопаснее обновить их автоматически.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Назад'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Переименовать без ссылок'),
                  ),
                ],
              ),
        );
        if (!mounted || confirmed != true) {
          setState(() => dirty = true);
          return;
        }
      }

      late final NoteWikiRenameUndo undo;
      if (decision == _WikiRenameDecision.renameOnly) {
        final previous = NoteWikiSnapshot(
          noteId: widget.note.id,
          title: oldTitle,
          body: widget.note.body,
        );
        _recordCurrentVersion('Перед переименованием без обновления ссылок');
        widget.note.title = proposedTitle;
        widget.store.updateNote(widget.note);
        undo = NoteWikiRenameUndo(
          snapshots: [previous],
          appliedSnapshots: [
            NoteWikiSnapshot(
              noteId: widget.note.id,
              title: widget.note.title,
              body: widget.note.body,
            ),
          ],
        );
      } else {
        undo = await widget.store.applyWikiRenamePlan(plan);
      }
      if (!mounted) return;
      _reloadEditorFromNote();
      final message =
          decision == _WikiRenameDecision.renameOnly
              ? 'Название изменено без обновления ссылок.'
              : 'Обновлено ссылок: ${plan.occurrenceCount} '
                'в ${plan.changedNoteCount} заметках.';
      _showRenameUndo(undo, message);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Не удалось переименовать заметку: $error')),
        );
      setState(() => dirty = true);
    } finally {
      if (mounted) setState(() => _renameReviewBusy = false);
    }
  }

  String get _proposedTitle {
    final value = titleController.text.trim();
    return value.isEmpty ? 'Без названия' : value;
  }

  void _assignEditorState({required String savedTitle}) {
    widget.note.title = savedTitle;
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
  }

  void _writeEditorState({required String savedTitle}) {
    _assignEditorState(savedTitle: savedTitle);
    widget.store.updateNote(widget.note);
  }

  void _recordCurrentVersion(String reason) {
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
        reason: reason,
      ),
    );
  }

  void _reloadEditorFromNote() {
    final parsed = NoteDocument.parse(widget.note.body);
    _suppressTextChangeTracking = true;
    titleController.text = widget.note.title;
    contentController.text = parsed.content;
    _suppressTextChangeTracking = false;
    _lastTitleText = titleController.text;
    _lastContentText = contentController.text;
    _editHistory.reset();
    _previewTextNotifier.setImmediate(_lastContentText);
    _statisticsTextNotifier.setImmediate(_lastContentText);
    if (mounted) {
      setState(() => dirty = false);
    }
  }

  void _showRenameUndo(NoteWikiRenameUndo undo, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: 'Отменить',
            onPressed: () => unawaited(_undoRename(undo)),
          ),
        ),
      );
  }

  Future<void> _undoRename(NoteWikiRenameUndo undo) async {
    try {
      await widget.store.undoWikiRename(undo);
      if (!mounted) return;
      _reloadEditorFromNote();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Переименование и изменения ссылок отменены.')),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отменить переименование: $error')),
      );
    }
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

  Future<void> _manageCustomTemplates() async {
    await _showCustomNoteTemplateManager(context, widget.store);
    if (mounted) setState(() {});
  }

  Future<void> _applyLaboratoryTemplate() async {
    final originalValue = contentController.value;
    final wasDirty = dirty;
    final application = await LaboratoryTemplateDialog.show(
      context,
      currentText: originalValue.text,
      templates: widget.store.applicableNoteTemplates,
    );
    if (application == null || !mounted) {
      return;
    }

    final updatedText = applyLaboratoryTemplateContent(
      currentText: originalValue.text,
      templateContent: application.template.content,
      placement: application.placement,
    );
    if (updatedText == originalValue.text) {
      return;
    }

    final appliedValue = originalValue.copyWith(
      text: updatedText,
      selection: TextSelection.collapsed(offset: updatedText.length),
      composing: TextRange.empty,
    );
    contentController.value = appliedValue;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          application.placement == LaboratoryTemplatePlacement.replace
              ? 'Содержимое заменено шаблоном «${application.template.title}».'
              : 'Шаблон «${application.template.title}» добавлен в конец.',
        ),
        action: SnackBarAction(
          label: 'Отменить',
          onPressed: () {
            if (!mounted) {
              return;
            }
            if (contentController.value != appliedValue) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'После вставки текст уже изменён; автоматическая отмена не выполнена.',
                  ),
                ),
              );
              return;
            }
            contentController.value = originalValue;
            if (!wasDirty) {
              setState(() => dirty = false);
            }
          },
        ),
      ),
    );
  }

  Future<void> _saveCurrentNoteAsTemplate() async {
    final draft = await CustomNoteTemplateEditorDialog.show(
      context,
      initialTitle: titleController.text.trim(),
      initialIcon: noteTypeIcon(noteType),
      initialNoteType: noteType,
      initialContent: contentController.text,
      initialTags: tags,
    );
    if (draft == null || !mounted) return;
    try {
      final template = await widget.store.createCustomNoteTemplate(
        title: draft.title,
        icon: draft.icon,
        noteType: draft.noteType,
        content: draft.content,
        category: draft.category,
        defaultTags: draft.defaultTags,
        defaultProperties: properties,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Создан пользовательский шаблон «${template.title}».'),
          action: SnackBarAction(
            label: 'Открыть',
            onPressed:
                () => unawaited(
                  _showCustomNoteTemplateManager(context, widget.store),
                ),
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось создать шаблон: $error')),
      );
    }
  }

  List<NoteLinkTarget> _availableNoteLinkTargets() {
    return <NoteLinkTarget>[
      for (final note in widget.store.data.notes)
        if (note.id != widget.note.id)
          NoteLinkTarget(
            id: note.id,
            title: note.title,
            projectTitle:
                widget.store.projectById(note.projectId)?.title ?? 'Без проекта',
            folderPath: note.folderPath,
            noteType: note.noteType,
            tags: List<String>.from(note.tags),
          ),
    ];
  }

  NoteLinkTarget _currentNoteLinkTarget() {
    return NoteLinkTarget(
      id: widget.note.id,
      title: _proposedTitle,
      projectTitle:
          widget.store.projectById(projectId)?.title ?? 'Без проекта',
      folderPath: folderPath,
      noteType: noteType,
      tags: List<String>.from(tags),
    );
  }

  Future<void> _insertNoteLinks() async {
    final targets = _availableNoteLinkTargets();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Других заметок пока нет.')),
      );
      return;
    }
    final result = await NoteLinkPickerDialog.show(
      context,
      targets: targets,
      sourceProjectTitle:
          widget.store.projectById(projectId)?.title ?? 'Без проекта',
    );
    if (result == null || result.targets.isEmpty || !mounted) {
      return;
    }
    final markdown = NoteLinkTools.compose(
      result.targets,
      style: result.style,
    );
    if (result.style == NoteLinkInsertStyle.inline) {
      _insertInlineMarkdown(markdown);
    } else {
      _insertMarkdownAtSelection(markdown);
    }
  }

  Future<void> _linkUnlinkedMentions() async {
    final targets = _availableNoteLinkTargets();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Других заметок пока нет.')),
      );
      return;
    }
    final originalValue = contentController.value;
    final selected = await NoteUnlinkedMentionsDialog.show(
      context,
      markdown: originalValue.text,
      targets: targets,
    );
    if (selected == null || selected.isEmpty || !mounted) {
      return;
    }
    final cursor = originalValue.selection.isValid
        ? originalValue.selection.extentOffset
        : originalValue.text.length;
    final edit = NoteLinkTools.applyMentions(
      originalValue.text,
      selected,
      cursor: cursor,
    );
    if (edit.text == originalValue.text) {
      return;
    }
    contentController.value = originalValue.copyWith(
      text: edit.text,
      selection: TextSelection.collapsed(offset: edit.cursor),
      composing: TextRange.empty,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Создано устойчивых ссылок: ${selected.length}.'),
      ),
    );
  }

  Future<void> _copyStableNoteLink() async {
    final markdown = NoteLinkTools.stableMarkdown(_currentNoteLinkTarget());
    await Clipboard.setData(ClipboardData(text: markdown));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Устойчивая ссылка скопирована.')),
    );
  }

  Future<void> _insertScientificTable() async {
    final value = contentController.value;
    final selection = value.selection;
    final offset = selection.isValid ? selection.extentOffset : value.text.length;
    ScientificTableReference? currentReference;
    for (final table in ScientificReferenceSyntax.tables(value.text)) {
      final selectionIntersects = selection.isValid &&
          !selection.isCollapsed &&
          selection.start < table.end &&
          selection.end > table.start;
      if ((offset >= table.start && offset <= table.end) || selectionIntersects) {
        currentReference = table;
        break;
      }
    }

    NoteTableModel? initialTable;
    if (currentReference != null) {
      initialTable = NoteTableSyntax.parseReference(currentReference);
      if (initialTable == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось безопасно разобрать текущую Markdown-таблицу.',
            ),
          ),
        );
        return;
      }
    }

    final index = ScientificReferenceSyntax.index(value.text);
    final currentKey = currentReference == null
        ? null
        : '${ScientificObjectType.table.name}:${currentReference.id}';
    final table = await ScientificTableEditorDialog.show(
      context,
      existingKeys: {
        for (final object in index.objects)
          if (object.key != currentKey) object.key,
      },
      initialTable: initialTable,
    );
    if (table == null || !mounted) {
      return;
    }

    final markdown = table.toMarkdown();
    if (currentReference == null) {
      _insertMarkdownAtSelection('\n$markdown\n');
    } else {
      contentController.value = value.copyWith(
        text: value.text.replaceRange(
          currentReference.start,
          currentReference.end,
          markdown,
        ),
        selection: TextSelection(
          baseOffset: currentReference.start,
          extentOffset: currentReference.start + markdown.length,
        ),
        composing: TextRange.empty,
      );
    }
    _save(createVersion: false);
  }

  Future<void> _insertScientificReference() async {
    final index = ScientificReferenceSyntax.index(contentController.text);
    final available = [
      for (final object in index.objects)
        if (!index.duplicateKeys.contains(object.key)) object,
    ];
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Сначала добавь нумерованный рисунок или научную таблицу.',
          ),
        ),
      );
      return;
    }
    final target = await ScientificReferencePickerDialog.show(
      context,
      objects: available,
    );
    if (target == null || !mounted) {
      return;
    }
    _insertInlineMarkdown(target.markdownReference);
  }

  Future<void> _inspectScientificObjects() async {
    final index = ScientificReferenceSyntax.index(contentController.text);
    await ScientificObjectsDialog.show(context, index: index);
  }

  Future<void> _insertCitation() async {
    if (widget.store.data.citationSources.isEmpty) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => SourcesScreen(store: widget.store),
        ),
      );
      if (!mounted || widget.store.data.citationSources.isEmpty) return;
    }
    final selected = await showDialog<List<CitationSource>>(
      context: context,
      builder: (context) => _CitationPickerDialog(
        sources: widget.store.data.citationSources,
      ),
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    _insertInlineMarkdown(CitationSyntax.markdownFor(selected));
  }

  void _insertBibliography() {
    if (contentController.text.contains(CitationSyntax.bibliographyMarker)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Блок библиографии уже есть в заметке.')),
      );
      return;
    }
    _insertMarkdownAtSelection(CitationSyntax.bibliographyMarker);
  }

  void _insertInlineMarkdown(String markdown) {
    final value = contentController.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    contentController.value = value.copyWith(
      text: value.text.replaceRange(start, end, markdown),
      selection: TextSelection.collapsed(offset: start + markdown.length),
      composing: TextRange.empty,
    );
  }

  KeyEventResult _handleEditorKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isControlPressed && !keyboard.isMetaPressed) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.keyZ) {
      if (keyboard.isShiftPressed) {
        _editHistory.redo();
      } else {
        _editHistory.undo();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyY) {
      _editHistory.redo();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyK &&
        keyboard.isShiftPressed) {
      unawaited(_insertNoteLinks());
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyV) {
      unawaited(_pasteClipboardContent());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _pasteClipboardContent() async {
    if (_clipboardPasteBusy) {
      return;
    }
    _clipboardPasteBusy = true;
    try {
      final imageBytes = await readClipboardPngImage();
      if (imageBytes != null && imageBytes.isNotEmpty) {
        await _storeClipboardImage(imageBytes);
        return;
      }
      await _pasteClipboardText();
    } on Object catch (error) {
      var pastedText = false;
      try {
        pastedText = await _pasteClipboardText();
      } on Object {
        pastedText = false;
      }
      if (!pastedText && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось прочитать буфер обмена: $error')),
        );
      }
    } finally {
      _clipboardPasteBusy = false;
    }
  }

  Future<void> _pasteImageFromClipboard() async {
    if (_clipboardPasteBusy) {
      return;
    }
    _clipboardPasteBusy = true;
    try {
      final imageBytes = await readClipboardPngImage();
      if (!mounted) {
        return;
      }
      if (imageBytes == null || imageBytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('В буфере обмена нет изображения.')),
        );
        return;
      }
      await _storeClipboardImage(imageBytes);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось вставить изображение: $error')),
      );
    } finally {
      _clipboardPasteBusy = false;
    }
  }

  Future<bool> _pasteClipboardText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty || !mounted) {
      return false;
    }
    _insertInlineMarkdown(text);
    return true;
  }

  Future<void> _storeClipboardImage(Uint8List bytes) async {
    final messenger = ScaffoldMessenger.of(context);
    final attachment = await widget.store.storeAttachmentBytesForNote(
      widget.note,
      fileName: clipboardImageFileName(DateTime.now()),
      bytes: bytes,
    );
    if (!mounted) {
      return;
    }
    _insertMarkdownAtSelection(attachment.markdown);
    _save(createVersion: false);
    final status =
        attachment.alreadyExisted
            ? 'Изображение уже было в Vault; добавлена ссылка'
            : 'Изображение из буфера добавлено';
    messenger.showSnackBar(
      SnackBar(content: Text('$status: ${attachment.fileName}')),
    );
  }

  Note _currentExportDraft() {
    final draft = Note(
      id: widget.note.id,
      title: _proposedTitle,
      projectId: projectId,
      body: '',
      tags: List<String>.from(tags),
      status: status,
      folderPath: folderPath.trim(),
      noteType: noteType,
      properties: Map<String, String>.from(properties),
      pinned: pinned,
      revision: widget.note.revision,
      createdAt: widget.note.createdAt,
      updatedAt: widget.note.updatedAt,
      deletedAt: widget.note.deletedAt,
    );
    draft.body = NoteDocument.serialize(draft, contentController.text);
    return draft;
  }

  Future<void> _exportCurrentNote() async {
    if (_exportBusy) {
      return;
    }
    final format = await NoteExportDialog.show(
      context,
      subjectLabel: _proposedTitle,
      isProject: false,
    );
    if (format == null || !mounted) {
      return;
    }
    _exportBusy = true;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final draft = _currentExportDraft();
      final projectTitle =
          widget.store.projectById(projectId)?.title ?? 'Без проекта';
      final payload = await NoteExportComposer(
        readAttachment: widget.store.readManagedAttachment,
      ).exportNote(
        note: draft,
        projectTitle: projectTitle,
        format: format,
      );
      final savedPath = await const NoteExportFileService().save(payload);
      if (savedPath == null || !mounted) {
        return;
      }
      final missingSuffix =
          payload.missingAttachments.isEmpty
              ? ''
              : '; не найдено вложений: '
                  '${payload.missingAttachments.length}';
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Экспорт сохранён: ${payload.fileName}; '
            'вложений: ${payload.assetCount}$missingSuffix',
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось экспортировать заметку: $error')),
      );
    } finally {
      _exportBusy = false;
    }
  }

  Future<void> _importDataFiles() async {
    if (_dataImportBusy) {
      return;
    }
    _dataImportBusy = true;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final files = await pickNoteDataImportFiles();
      if (files == null || files.isEmpty || !mounted) {
        return;
      }
      final plan = await NoteDataImportDialog.show(context, files: files);
      if (plan == null || !mounted) {
        return;
      }

      NoteTableModel? table;
      if (plan.mode == NoteDataImportMode.tableWithSource) {
        final index = ScientificReferenceSyntax.index(contentController.text);
        table = NoteDataImport.tableModelFor(
          file: files.single,
          existingObjectKeys: {
            for (final object in index.objects) object.key,
          },
        );
      }

      final results = await widget.store.storeAttachmentBatchForNote(
        widget.note,
        fileNames: [for (final file in files) file.name],
        fileBytes: [for (final file in files) file.bytes],
      );
      if (!mounted) {
        return;
      }
      final attachments = <NoteDataImportAttachment>[
        for (var index = 0; index < results.length; index += 1)
          NoteDataImportAttachment(
            sourceName: files[index].name,
            result: results[index],
          ),
      ];
      final markdown = switch (plan.mode) {
        NoteDataImportMode.tableWithSource =>
          NoteDataImport.buildTableImportMarkdown(
            title: plan.title,
            table: table!,
            source: attachments.single,
          ),
        NoteDataImportMode.attachmentBundle =>
          NoteDataImport.buildAttachmentBundleMarkdown(
            title: plan.title,
            attachments: attachments,
            showImagePreviews: plan.showImagePreviews,
          ),
      };
      _insertMarkdownAtSelection(markdown);
      _save(createVersion: false);
      final duplicateCount = results.where((result) => result.alreadyExisted).length;
      final duplicateSuffix = duplicateCount == 0
          ? ''
          : '; $duplicateCount уже были в Vault';
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Импортировано файлов: ${results.length}$duplicateSuffix.',
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось импортировать данные: $error')),
      );
    } finally {
      _dataImportBusy = false;
    }
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
    final existingFigureIds = <String>{
      for (final image in NoteImageSyntax.all(contentController.text))
        if (image.start != current.start &&
            image.presentation.figureId.trim().isNotEmpty)
          image.presentation.figureId.trim(),
    };
    final result = await NoteImageEditorDialog.show(
      context,
      initial: current.presentation,
      imageLabel: current.alt,
      existingFigureIds: existingFigureIds,
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

    final updatedText = value.text.replaceRange(
      current.start,
      current.end,
      replacement,
    );
    contentController.value = value.copyWith(
      text: updatedText,
      selection: updatedSelection,
      composing: TextRange.empty,
    );
    _previewTextNotifier.setImmediate(updatedText);
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

    final selected =
        selection.isValid && !selection.isCollapsed
            ? value.text.substring(selection.start, selection.end).trim()
            : '';
    final result = await NoteColumnsEditorDialog.show(
      context,
      initial: const NoteColumnsLayout(
        columnCount: 2,
        widths: [40, 60],
      ),
      initialContents: _initialColumnComposerContents(selected),
      editingExisting: false,
    );
    if (result == null || !mounted) {
      return;
    }

    final markdown = NoteColumnsSyntax.build(
      widths: result.layout.widths,
      contents: result.contents,
    );
    _insertMarkdownAtSelection(markdown);
    _save(createVersion: false);
  }

  List<String> _initialColumnComposerContents(String selected) {
    if (selected.isEmpty) {
      return const ['Изображение или текст', 'Текст правой колонки'];
    }
    final image = NoteImageSyntax.first(selected);
    if (image != null && image.start == 0) {
      final remainder = selected.substring(image.end).trim();
      return [
        image.raw,
        remainder.isEmpty ? 'Текст правой колонки' : remainder,
      ];
    }
    return ['Изображение или текст', selected];
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
      initialContents: [
        for (final column in current.columns) column.markdown,
      ],
      editingExisting: true,
    );
    if (result == null || !mounted) {
      return;
    }
    if (result.unwrap) {
      _unwrapColumnsReference(
        current,
        contents: result.contents,
      );
      return;
    }
    _replaceColumnsLayout(
      current,
      result.layout,
      contents: result.contents,
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
    required List<String> contents,
  }) {
    final current = NoteColumnsSyntax.relocate(
      contentController.text,
      reference,
    );
    if (current == null) {
      return;
    }
    _replaceColumnsBlock(
      current,
      widths: layout.widths,
      contents: NoteColumnsSyntax.normalizeContents(
        contents,
        layout.columnCount,
      ),
    );
  }

  void _unwrapColumnsReference(
    NoteColumnsReference reference, {
    required List<String> contents,
  }) {
    final current = NoteColumnsSyntax.relocate(
      contentController.text,
      reference,
    );
    if (current == null) {
      return;
    }
    final plainMarkdown = contents
        .map((content) => content.trim())
        .where((content) => content.isNotEmpty)
        .join('\n\n');
    _replaceColumnsText(current, plainMarkdown);
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


  Future<void> _reorderBlocks() async {
    final value = contentController.value;
    final blocks = NoteBlockSyntax.all(value.text);
    if (blocks.length < 2) {
      _showBlockMessage('Для перетаскивания нужны хотя бы два блока.');
      return;
    }

    final selectionOffset =
        value.selection.isValid
            ? value.selection.extentOffset
            : value.text.length;
    final selectedBlock = NoteBlockSyntax.findIn(
      blocks,
      value.text.length,
      selectionOffset,
    );
    final order = await NoteBlockReorderDialog.show(
      context,
      source: value.text,
      selectedBlockIndex: selectedBlock?.index,
    );
    if (order == null || !mounted) {
      return;
    }

    final result = NoteBlockSyntax.reorder(
      value.text,
      order,
      selectedOriginalIndex: selectedBlock?.index,
    );
    if (result == null) {
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

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Порядок блоков изменён.'),
          action: SnackBarAction(
            label: 'Отменить',
            onPressed: () {
              if (contentController.text != result.text) {
                _showBlockMessage(
                  'После перемещения текст уже изменился; автоматическая '
                  'отмена не применена.',
                );
                return;
              }
              contentController.value = previousValue;
            },
          ),
        ),
      );
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

  Future<void> _openWikiLink(String rawTarget) async {
    _save(createVersion: false);
    final reference = NoteWikiTarget.parse(rawTarget);
    final candidates = widget.store.notesForWikiTarget(
      rawTarget,
      source: widget.note,
    );
    var target = widget.store.resolveWikiTarget(
      rawTarget,
      source: widget.note,
    );

    if (target == null && candidates.isNotEmpty) {
      target = await _chooseWikiTarget(reference.noteTitle, candidates);
      if (!mounted || target == null) return;
    }

    if (target == null && reference.noteId != null) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Связанная заметка удалена'),
              content: const Text(
                'Эта точная ссылка указывает на заметку, которой больше нет. '
                'Открой «Проверить ссылки» в списке заметок, чтобы найти '
                'источник и исправить ссылку вручную.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Закрыть'),
                ),
              ],
            ),
      );
      return;
    }

    if (target == null) {
      if (!mounted) return;
      final create = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text('Создать «${reference.noteTitle}»?'),
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

      var targetProjectId = projectId;
      final projectTitle = reference.projectTitle?.trim().toLowerCase();
      if (projectTitle != null) {
        for (final project in widget.store.data.projects) {
          if (project.title.trim().toLowerCase() == projectTitle) {
            targetProjectId = project.id;
            break;
          }
        }
      }
      target = Note(
        id: const Uuid().v4(),
        title: reference.noteTitle,
        projectId: targetProjectId,
        body: '',
        folderPath: targetProjectId == projectId ? folderPath : '',
      );
      target.body = NoteDocument.serialize(
        target,
        '# ${reference.noteTitle}\n\n',
      );
      widget.store.addNote(target);
      await widget.store.rebuildAllNoteLinks();
    }
    if (!mounted) return;
    await _openNote(target);
  }

  Future<Note?> _chooseWikiTarget(
    String title,
    List<Note> candidates,
  ) {
    return showDialog<Note>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Какую заметку «$title» открыть?'),
            content: SizedBox(
              width: 440,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final candidate in candidates)
                    ListTile(
                      leading: Text(noteTypeIcon(candidate.noteType)),
                      title: Text(candidate.title),
                      subtitle: Text(
                        _noteLocationLabel(widget.store, candidate),
                      ),
                      onTap: () => Navigator.pop(context, candidate),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
            ],
          ),
    );
  }

  NoteVersion _currentVersionSnapshot() {
    final draft = Note(
      id: widget.note.id,
      title: _proposedTitle,
      projectId: projectId,
      body: widget.note.body,
      tags: List<String>.from(tags),
      status: status,
      folderPath: folderPath.trim(),
      noteType: noteType,
      properties: Map<String, String>.from(properties),
      pinned: pinned,
      revision: widget.note.revision,
      createdAt: widget.note.createdAt,
      updatedAt: widget.note.updatedAt,
    );
    return NoteVersion(
      id: 'current',
      noteId: widget.note.id,
      title: draft.title,
      body: NoteDocument.serialize(draft, contentController.text),
      tags: List<String>.from(draft.tags),
      status: draft.status,
      folderPath: draft.folderPath,
      noteType: draft.noteType,
      properties: Map<String, String>.from(draft.properties),
      reason: 'Текущее состояние',
      createdAt: DateTime.now(),
    );
  }

  Future<void> _openVersionHistory({String? initialVersionId}) async {
    final versions = widget.store.versionsFor(widget.note.id);
    if (versions.isEmpty) {
      return;
    }
    final selected = await NoteVersionHistoryDialog.show(
      context,
      versions: versions,
      current: _currentVersionSnapshot(),
      initialVersionId: initialVersionId,
    );
    if (selected == null || !mounted) {
      return;
    }
    _restoreVersion(selected);
  }

  Future<void> _openNote(Note? note) async {
    if (note == null || note.id == widget.note.id) return;
    _save(createVersion: false);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => NoteWorkspaceScreen(
          store: widget.store,
          note: note,
          appearanceController: widget.appearanceController,
          globalAppearance: widget.globalAppearance,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  void _restoreVersion(NoteVersion version) {
    final current = _currentVersionSnapshot();
    widget.store.addNoteVersion(
      NoteVersion(
        id: const Uuid().v4(),
        noteId: widget.note.id,
        title: current.title,
        body: current.body,
        tags: List<String>.from(current.tags),
        status: current.status,
        folderPath: current.folderPath,
        noteType: current.noteType,
        properties: Map<String, String>.from(current.properties),
        reason: 'Перед восстановлением',
      ),
    );
    widget.store.restoreNoteVersion(widget.note, version);
    final parsed = NoteDocument.parse(widget.note.body);
    _suppressTextChangeTracking = true;
    titleController.text = widget.note.title;
    contentController.text = parsed.content;
    _suppressTextChangeTracking = false;
    _lastTitleText = titleController.text;
    _lastContentText = contentController.text;
    _editHistory.reset();
    _previewTextNotifier.setImmediate(_lastContentText);
    _statisticsTextNotifier.setImmediate(_lastContentText);
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

class _EditorToolbar extends StatefulWidget {
  const _EditorToolbar({
    required this.controller,
    required this.history,
    required this.toolbarPreferences,
    required this.toolbarPreferencesLoaded,
    required this.onActivateToolbarProfile,
    required this.onManageToolbarProfiles,
    required this.onUndo,
    required this.onRedo,
    required this.onAttach,
    required this.onPasteImage,
    required this.onConfigureImage,
    required this.onConfigureColumns,
    required this.onReorderBlocks,
    required this.onBlockAction,
    required this.onInsertNoteLink,
    required this.onInsertCitation,
    required this.onInsertBibliography,
    required this.onInsertScientificTable,
    required this.onImportData,
    required this.onExport,
    required this.onInsertScientificReference,
    required this.onInspectScientificObjects,
    required this.onApplyLaboratoryTemplate,
    required this.onSaveAsTemplate,
    required this.onManageTemplates,
  });

  final TextEditingController controller;
  final NoteEditHistory history;
  final NoteToolbarPreferences toolbarPreferences;
  final bool toolbarPreferencesLoaded;
  final ValueChanged<String> onActivateToolbarProfile;
  final VoidCallback onManageToolbarProfiles;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onAttach;
  final VoidCallback onPasteImage;
  final VoidCallback onConfigureImage;
  final VoidCallback onConfigureColumns;
  final VoidCallback onReorderBlocks;
  final ValueChanged<_NoteBlockAction> onBlockAction;
  final VoidCallback onInsertNoteLink;
  final VoidCallback onInsertCitation;
  final VoidCallback onInsertBibliography;
  final VoidCallback onInsertScientificTable;
  final VoidCallback onImportData;
  final VoidCallback onExport;
  final VoidCallback onInsertScientificReference;
  final VoidCallback onInspectScientificObjects;
  final VoidCallback onApplyLaboratoryTemplate;
  final VoidCallback onSaveAsTemplate;
  final VoidCallback onManageTemplates;

  @override
  State<_EditorToolbar> createState() => _EditorToolbarState();
}

class _EditorToolbarState extends State<_EditorToolbar> {
  static const _parseDelay = Duration(milliseconds: 220);

  Timer? _parseTimer;
  String _parsedText = '';
  List<NoteBlockReference> _blocks = const [];
  NoteBlockReference? _block;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    _parseNow(notify: false);
  }

  @override
  void didUpdateWidget(covariant _EditorToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }
    oldWidget.controller.removeListener(_handleControllerChanged);
    widget.controller.addListener(_handleControllerChanged);
    _parseTimer?.cancel();
    _parseNow(notify: false);
  }

  @override
  void dispose() {
    _parseTimer?.cancel();
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    final value = widget.controller.value;
    if (value.text != _parsedText) {
      _parseTimer?.cancel();
      _parseTimer = Timer(_parseDelay, () => _parseNow());
      return;
    }
    final nextBlock = _findCurrentBlock(value);
    if (_sameBlock(_block, nextBlock)) {
      return;
    }
    setState(() => _block = nextBlock);
  }

  void _parseNow({bool notify = true}) {
    _parseTimer?.cancel();
    _parseTimer = null;
    final value = widget.controller.value;
    final blocks = NoteBlockSyntax.all(value.text);
    final block = NoteBlockSyntax.findIn(
      blocks,
      value.text.length,
      _selectionOffset(value),
    );
    if (!notify || !mounted) {
      _parsedText = value.text;
      _blocks = blocks;
      _block = block;
      return;
    }
    setState(() {
      _parsedText = value.text;
      _blocks = blocks;
      _block = block;
    });
  }

  NoteBlockReference? _findCurrentBlock(TextEditingValue value) {
    return NoteBlockSyntax.findIn(
      _blocks,
      value.text.length,
      _selectionOffset(value),
    );
  }

  int _selectionOffset(TextEditingValue value) {
    return value.selection.isValid
        ? value.selection.extentOffset
        : value.text.length;
  }

  bool _sameBlock(NoteBlockReference? left, NoteBlockReference? right) {
    return left?.start == right?.start &&
        left?.end == right?.end &&
        left?.type == right?.type &&
        left?.index == right?.index;
  }

  @override
  Widget build(BuildContext context) {
    final block = _block;
    final canMoveUp = block != null && block.index > 0;
    final canMoveDown = block != null && block.index < _blocks.length - 1;
    final canConvert = block?.supportsTextConversion ?? false;

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          AnimatedBuilder(
            animation: widget.history,
            builder: (context, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Отменить (Ctrl+Z)',
                    onPressed: widget.history.canUndo ? widget.onUndo : null,
                    icon: const Icon(Icons.undo_rounded),
                  ),
                  IconButton(
                    tooltip: 'Повторить (Ctrl+Y)',
                    onPressed: widget.history.canRedo ? widget.onRedo : null,
                    icon: const Icon(Icons.redo_rounded),
                  ),
                ],
              );
            },
          ),
          const VerticalDivider(indent: 10, endIndent: 10),
          Tooltip(
            message:
                block == null
                    ? 'Помести курсор в блок заметки'
                    : 'Текущий блок: ${block.label}',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: SizedBox(
                width: 118,
                child: Chip(
                  avatar: const Icon(Icons.view_agenda_outlined, size: 16),
                  label: Text(
                    block?.label ?? 'Нет блока',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Переместить блок выше',
            onPressed:
                canMoveUp
                    ? () => widget.onBlockAction(_NoteBlockAction.moveUp)
                    : null,
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
          ),
          IconButton(
            tooltip: 'Переместить блок ниже',
            onPressed:
                canMoveDown
                    ? () => widget.onBlockAction(_NoteBlockAction.moveDown)
                    : null,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          IconButton(
            tooltip: 'Перетащить блоки',
            onPressed: _blocks.length > 1 ? widget.onReorderBlocks : null,
            icon: const Icon(Icons.drag_indicator_rounded),
          ),
          PopupMenuButton<_NoteBlockAction>(
            tooltip: 'Действия с текущим блоком',
            enabled: block != null,
            onSelected: widget.onBlockAction,
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
                        canConvert && block?.type != NoteBlockType.paragraph,
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
                        canConvert && block?.type != NoteBlockType.checklist,
                    child: const ListTile(
                      leading: Icon(Icons.check_box_outlined),
                      title: Text('Преобразовать в чек-лист'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: _NoteBlockAction.quote,
                    enabled: canConvert && block?.type != NoteBlockType.quote,
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
          _toolbarProfileSwitcher(),
          for (final action in widget.toolbarPreferences.activeProfile.actions)
            _actionButton(action),
        ],
      ),
    );
  }

  Widget _toolbarProfileSwitcher() {
    final preferences = widget.toolbarPreferences;
    final active = preferences.activeProfile;
    final colors = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: widget.toolbarPreferencesLoaded
          ? 'Панель действий: ${active.name}'
          : 'Панель быстрых действий',
      onSelected: (value) {
        if (value == '__manage__') {
          widget.onManageToolbarProfiles();
        } else {
          widget.onActivateToolbarProfile(value);
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        for (final profile in preferences.profiles)
          PopupMenuItem<String>(
            value: profile.id,
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    profile.emoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                Expanded(child: Text(profile.name)),
                if (profile.id == preferences.activeProfileId)
                  Icon(Icons.check_rounded, color: colors.primary),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: '__manage__',
          child: Row(
            children: [
              Icon(Icons.tune_rounded),
              SizedBox(width: 12),
              Text('Настроить панель'),
            ],
          ),
        ),
      ],
      icon: Text(active.emoji, style: const TextStyle(fontSize: 18)),
    );
  }

  Widget _actionButton(NoteToolbarAction action) {
    return switch (action) {
      NoteToolbarAction.applyTemplate => _callbackButton(
        action,
        Icons.dashboard_customize_outlined,
        widget.onApplyLaboratoryTemplate,
      ),
      NoteToolbarAction.saveAsTemplate => _callbackButton(
        action,
        Icons.bookmark_add_outlined,
        widget.onSaveAsTemplate,
      ),
      NoteToolbarAction.manageTemplates => _callbackButton(
        action,
        Icons.settings_outlined,
        widget.onManageTemplates,
      ),
      NoteToolbarAction.heading => _wrapButton(
        action,
        Icons.title_rounded,
        '# ',
        '',
      ),
      NoteToolbarAction.bold => _wrapButton(
        action,
        Icons.format_bold_rounded,
        '**',
        '**',
      ),
      NoteToolbarAction.italic => _wrapButton(
        action,
        Icons.format_italic_rounded,
        '_',
        '_',
      ),
      NoteToolbarAction.bulletedList => _wrapButton(
        action,
        Icons.format_list_bulleted_rounded,
        '- ',
        '',
      ),
      NoteToolbarAction.checklist => _wrapButton(
        action,
        Icons.check_box_outlined,
        '- [ ] ',
        '',
      ),
      NoteToolbarAction.inlineMath => _wrapButton(
        action,
        Icons.functions_rounded,
        r'$',
        r'$',
      ),
      NoteToolbarAction.displayMath => _wrapButton(
        action,
        Icons.calculate_outlined,
        '\n\\[\n',
        '\n\\]\n',
      ),
      NoteToolbarAction.codeBlock => _wrapButton(
        action,
        Icons.code_rounded,
        '```\n',
        '\n```',
      ),
      NoteToolbarAction.noteLink => _callbackButton(
        action,
        Icons.link_rounded,
        widget.onInsertNoteLink,
      ),
      NoteToolbarAction.citation => _callbackButton(
        action,
        Icons.format_quote_rounded,
        widget.onInsertCitation,
      ),
      NoteToolbarAction.bibliography => _callbackButton(
        action,
        Icons.library_books_outlined,
        widget.onInsertBibliography,
      ),
      NoteToolbarAction.scientificReference => _callbackButton(
        action,
        Icons.numbers_rounded,
        widget.onInsertScientificReference,
      ),
      NoteToolbarAction.importData => _callbackButton(
        action,
        Icons.upload_file_outlined,
        widget.onImportData,
      ),
      NoteToolbarAction.exportNote => _callbackButton(
        action,
        Icons.download_outlined,
        widget.onExport,
      ),
      NoteToolbarAction.scientificTable => _callbackButton(
        action,
        Icons.table_chart_outlined,
        widget.onInsertScientificTable,
      ),
      NoteToolbarAction.inspectScientificObjects => _callbackButton(
        action,
        Icons.fact_check_outlined,
        widget.onInspectScientificObjects,
      ),
      NoteToolbarAction.attach => _callbackButton(
        action,
        Icons.attach_file_rounded,
        widget.onAttach,
      ),
      NoteToolbarAction.pasteImage => _callbackButton(
        action,
        Icons.content_paste_rounded,
        widget.onPasteImage,
      ),
      NoteToolbarAction.configureImage => _callbackButton(
        action,
        Icons.photo_size_select_large_rounded,
        widget.onConfigureImage,
      ),
      NoteToolbarAction.columns => _callbackButton(
        action,
        Icons.view_column_outlined,
        widget.onConfigureColumns,
      ),
      NoteToolbarAction.imageSyntax => _wrapButton(
        action,
        Icons.image_outlined,
        '![описание](',
        ')',
      ),
    };
  }

  Widget _callbackButton(
    NoteToolbarAction action,
    IconData icon,
    VoidCallback callback,
  ) {
    return IconButton(
      tooltip: action.label,
      onPressed: callback,
      icon: Icon(icon),
    );
  }

  Widget _wrapButton(
    NoteToolbarAction action,
    IconData icon,
    String before,
    String after,
  ) {
    return IconButton(
      tooltip: action.label,
      onPressed: () => _wrapSelection(before, after),
      icon: Icon(icon),
    );
  }

  void _wrapSelection(String before, String after) {
    final value = widget.controller.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final selected = value.text.substring(start, end);
    final replacement = '$before$selected$after';
    widget.controller.value = value.copyWith(
      text: value.text.replaceRange(start, end, replacement),
      selection: TextSelection.collapsed(
        offset: start + before.length + selected.length,
      ),
      composing: TextRange.empty,
    );
  }
}

class _CitationPickerDialog extends StatefulWidget {
  const _CitationPickerDialog({required this.sources});

  final List<CitationSource> sources;

  @override
  State<_CitationPickerDialog> createState() => _CitationPickerDialogState();
}

class _CitationPickerDialogState extends State<_CitationPickerDialog> {
  String query = '';
  final Set<String> selectedIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    final sources = widget.sources.where((source) {
      if (normalized.isEmpty) return true;
      return [
        source.citationKey,
        source.title,
        source.authors.join(' '),
        source.containerTitle,
        source.doi,
      ].join(' ').toLowerCase().contains(normalized);
    }).toList()
      ..sort((left, right) => left.citationKey.toLowerCase().compareTo(
        right.citationKey.toLowerCase(),
      ));

    return AlertDialog(
      title: const Text('Вставить цитату'),
      content: SizedBox(
        width: 680,
        height: 520,
        child: Column(
          children: [
            SearchBar(
              hintText: 'Citation key, название или автор',
              leading: const Icon(Icons.search_rounded),
              onChanged: (value) => setState(() => query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: sources.isEmpty
                  ? const Center(child: Text('Источники не найдены'))
                  : ListView.builder(
                      itemCount: sources.length,
                      itemBuilder: (context, index) {
                        final source = sources[index];
                        final selected = selectedIds.contains(source.id);
                        final subtitleParts = <String>[
                          '@${source.citationKey}',
                          if (source.year != null) source.year.toString(),
                          if (source.authors.isNotEmpty) source.authors.first,
                        ];
                        return CheckboxListTile(
                          value: selected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                selectedIds.add(source.id);
                              } else {
                                selectedIds.remove(source.id);
                              }
                            });
                          },
                          title: Text(source.title),
                          subtitle: Text(subtitleParts.join(' · ')),
                          secondary: const Icon(Icons.article_outlined),
                          controlAffinity: ListTileControlAffinity.trailing,
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
          child: const Text('Отмена'),
        ),
        FilledButton.icon(
          onPressed: selectedIds.isEmpty
              ? null
              : () => Navigator.pop(
                    context,
                    [
                      for (final source in widget.sources)
                        if (selectedIds.contains(source.id)) source,
                    ],
                  ),
          icon: const Icon(Icons.format_quote_rounded),
          label: Text(
            selectedIds.length <= 1
                ? 'Вставить'
                : 'Вставить ${selectedIds.length}',
          ),
        ),
      ],
    );
  }
}

class _WikiLinkSuggestionsBar extends StatelessWidget {
  const _WikiLinkSuggestionsBar({
    required this.controller,
    required this.store,
    required this.currentNoteId,
    required this.sourceProjectId,
    required this.sourceFolderPath,
  });

  final TextEditingController controller;
  final AppStore store;
  final String currentNoteId;
  final String sourceProjectId;
  final String sourceFolderPath;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final value = controller.value;
        if (!value.selection.isValid || !value.selection.isCollapsed) {
          return const SizedBox.shrink();
        }
        final query = NoteWikiLinkSyntax.autocompleteAt(
          value.text,
          value.selection.extentOffset,
        );
        if (query == null) {
          return const SizedBox.shrink();
        }

        final normalized = query.query.toLowerCase();
        final candidates = store.data.notes
            .where((note) => note.id != currentNoteId)
            .where((note) {
              if (normalized.isEmpty) return true;
              final project = store.projectById(note.projectId);
              final searchable = [
                note.title,
                note.folderPath,
                project?.title ?? '',
              ].join(' ').toLowerCase();
              return searchable.contains(normalized);
            })
            .toList();
        candidates.sort((left, right) {
          int rank(Note note) {
            final title = note.title.toLowerCase();
            final prefix = normalized.isNotEmpty && title.startsWith(normalized);
            if (note.projectId == sourceProjectId &&
                note.folderPath.trim() == sourceFolderPath.trim()) {
              return prefix ? 0 : 1;
            }
            if (note.projectId == sourceProjectId) return prefix ? 2 : 3;
            return prefix ? 4 : 5;
          }

          final rankCompare = rank(left).compareTo(rank(right));
          if (rankCompare != 0) return rankCompare;
          return left.title.toLowerCase().compareTo(right.title.toLowerCase());
        });
        final visible = candidates.take(6).toList(growable: false);
        if (visible.isEmpty) {
          return const SizedBox.shrink();
        }

        return Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: SizedBox(
            height: 54,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              itemCount: visible.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final note = visible[index];
                final project = store.projectById(note.projectId);
                final duplicateTitle = store.notesByTitle(note.title).length > 1;
                final label =
                    duplicateTitle && project != null
                        ? '${note.title} · ${project.title}'
                        : note.title;
                return Tooltip(
                  message: _noteLocationLabel(store, note),
                  child: ActionChip(
                    avatar: Text(noteTypeIcon(note.noteType)),
                    label: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => _complete(query, note),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _complete(NoteWikiAutocompleteQuery query, Note note) {
    final value = controller.value;
    if (query.end > value.text.length) return;
    final target = NoteWikiTarget.exactId(note.id);
    final completion = NoteWikiLinkSyntax.complete(
      value.text,
      query,
      target,
      label: note.title,
    );
    controller.value = value.copyWith(
      text: completion.text,
      selection: TextSelection.collapsed(offset: completion.cursor),
      composing: TextRange.empty,
    );
  }
}

String _wikiTargetDisplayName(String rawTarget) {
  final parsed = NoteWikiTarget.parse(rawTarget);
  return parsed.noteTitle.isEmpty ? rawTarget : parsed.noteTitle;
}

String _noteLocationLabel(AppStore store, Note note) {
  final project = store.projectById(note.projectId);
  return [
    project?.title ?? 'Без проекта',
    if (note.folderPath.trim().isNotEmpty) note.folderPath.trim(),
  ].join(' · ');
}

class _LinkSection extends StatelessWidget {
  const _LinkSection({
    required this.title,
    required this.emptyText,
    required this.links,
    required this.resolve,
    required this.onOpen,
    this.subtitle,
    this.onMissing,
    this.missingActionLabel,
  });

  final String title;
  final String emptyText;
  final List<NoteLink> links;
  final Note? Function(NoteLink link) resolve;
  final String? Function(NoteLink link, Note? note)? subtitle;
  final ValueChanged<Note?> onOpen;
  final ValueChanged<NoteLink>? onMissing;
  final String Function(NoteLink link)? missingActionLabel;

  @override
  Widget build(BuildContext context) {
    return _ContextCard(
      title: title,
      child:
          links.isEmpty
              ? Text(emptyText)
              : Column(
                children: [
                  for (final link in links) _buildLink(link),
                ],
              ),
    );
  }

  Widget _buildLink(NoteLink link) {
    final note = resolve(link);
    final detail = subtitle?.call(link, note);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        note == null ? Icons.link_off_rounded : Icons.description_outlined,
      ),
      title: Text(
        note?.title ?? _wikiTargetDisplayName(link.targetTitle),
      ),
      subtitle:
          detail == null || detail.trim().isEmpty
              ? null
              : Text(
                detail,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
      trailing:
          note == null && onMissing != null
              ? TextButton(
                onPressed: () => onMissing!(link),
                child: Text(missingActionLabel?.call(link) ?? 'Открыть'),
              )
              : const Icon(Icons.chevron_right_rounded),
      onTap:
          note != null
              ? () => onOpen(note)
              : onMissing == null
              ? null
              : () => onMissing!(link),
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


enum _WikiRenameDecision { cancel, renameOnly, updateLinks }

class _WikiRenamePreviewDialog extends StatelessWidget {
  const _WikiRenamePreviewDialog({required this.plan});

  final NoteWikiRenamePlan plan;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Безопасное переименование'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '«${plan.oldTitle}» → «${plan.newTitle}»',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Chronicle может обновить ${plan.occurrenceCount} '
                'ссылок в ${plan.changedNoteCount} заметках. Перед операцией '
                'для каждой изменяемой заметки будет сохранена версия.',
              ),
              if (plan.skippedAmbiguousOccurrences > 0) ...[
                const SizedBox(height: 10),
                Text(
                  'Не будут изменены неоднозначные ссылки: '
                  '${plan.skippedAmbiguousOccurrences}. Их можно исправить '
                  'через «Проверить ссылки».',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              for (final change in plan.sourceChanges.take(12))
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  leading: const Icon(Icons.description_outlined),
                  title: Text(change.sourceTitle),
                  subtitle: Text(
                    'Ссылок: ${change.occurrenceCount}',
                  ),
                  children: [
                    for (final occurrence in change.occurrences.take(3))
                      ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.only(left: 16),
                        leading: const Icon(Icons.link_rounded, size: 18),
                        title: Text(
                          occurrence.snippet.isEmpty
                              ? '[[${occurrence.rawTarget}]]'
                              : occurrence.snippet,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              if (plan.sourceChanges.length > 12)
                Text(
                  'И ещё заметок: ${plan.sourceChanges.length - 12}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            _WikiRenameDecision.cancel,
          ),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            _WikiRenameDecision.renameOnly,
          ),
          child: const Text('Только название'),
        ),
        FilledButton.icon(
          onPressed:
              plan.skippedAmbiguousOccurrences > 0
                  ? null
                  : () => Navigator.pop(
                    context,
                    _WikiRenameDecision.updateLinks,
                  ),
          icon: const Icon(Icons.link_rounded),
          label: Text(
            plan.skippedAmbiguousOccurrences > 0
                ? 'Сначала исправить неоднозначные'
                : 'Обновить ${plan.occurrenceCount} ссылок',
          ),
        ),
      ],
    );
  }
}

class _LinkHealthSelection {
  const _LinkHealthSelection({
    required this.issue,
    required this.repair,
  });

  final NoteWikiLinkIssue issue;
  final bool repair;
}

class _LinkHealthDialog extends StatelessWidget {
  const _LinkHealthDialog({required this.store, required this.issues});

  final AppStore store;
  final List<NoteWikiLinkIssue> issues;

  @override
  Widget build(BuildContext context) {
    final missing = issues
        .where((issue) => issue.kind == NoteWikiLinkIssueKind.missing)
        .length;
    final ambiguous = issues.length - missing;
    final dialogHeight = (MediaQuery.sizeOf(context).height * 0.62)
        .clamp(300.0, 520.0)
        .toDouble();
    return AlertDialog(
      title: const Text('Проверка связей'),
      content: SizedBox(
        width: 680,
        height: dialogHeight,
        child:
            issues.isEmpty
                ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_outlined, size: 52),
                      SizedBox(height: 10),
                      Text('Все вики-ссылки разрешаются однозначно.'),
                    ],
                  ),
                )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Не найдены: $missing · Неоднозначны: $ambiguous',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        itemCount: issues.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final issue = issues[index];
                          final source = store.noteById(issue.sourceNoteId);
                          final exactMissing =
                              issue.kind == NoteWikiLinkIssueKind.missing &&
                              NoteWikiTarget.parse(issue.rawTarget).noteId !=
                                  null;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              issue.kind == NoteWikiLinkIssueKind.missing
                                  ? Icons.link_off_rounded
                                  : Icons.call_split_rounded,
                            ),
                            title: Text(
                              '[[${issue.rawTarget}]]',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              [
                                source?.title ?? issue.sourceTitle,
                                if (issue.snippet.isNotEmpty) issue.snippet,
                              ].join('\n'),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => Navigator.pop(
                              context,
                              _LinkHealthSelection(
                                issue: issue,
                                repair: false,
                              ),
                            ),
                            trailing:
                                exactMissing
                                    ? const Tooltip(
                                      message:
                                          'Точная ссылка ведёт на удалённую '
                                          'заметку; открой источник для '
                                          'ручного решения.',
                                      child: Icon(Icons.info_outline_rounded),
                                    )
                                    : TextButton(
                                      onPressed: () => Navigator.pop(
                                        context,
                                        _LinkHealthSelection(
                                          issue: issue,
                                          repair: true,
                                        ),
                                      ),
                                      child: Text(
                                        issue.kind ==
                                                NoteWikiLinkIssueKind.missing
                                            ? 'Создать'
                                            : 'Выбрать',
                                      ),
                                    ),
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

class _NewNoteSheet extends StatefulWidget {
  const _NewNoteSheet({
    required this.store,
    this.initialTemplateId,
  });

  final AppStore store;
  final String? initialTemplateId;

  static Future<_NewNoteRequest?> show(
    BuildContext context, {
    required AppStore store,
    String? initialTemplateId,
  }) {
    return showModalBottomSheet<_NewNoteRequest>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 700),
      builder: (_) => _NewNoteSheet(
        store: store,
        initialTemplateId: initialTemplateId,
      ),
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
    projectId = widget.store.activeProjects.first.id;
    final requestedTemplateId = widget.initialTemplateId;
    if (requestedTemplateId != null &&
        widget.store.availableNoteTemplates.any(
          (template) => template.id == requestedTemplateId,
        )) {
      templateId = requestedTemplateId;
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    folderController.dispose();
    super.dispose();
  }

  Future<void> _manageTemplates() async {
    await _showCustomNoteTemplateManager(context, widget.store);
    if (!mounted) return;
    final availableIds = widget.store.availableNoteTemplates
        .map((template) => template.id)
        .toSet();
    setState(() {
      if (!availableIds.contains(templateId)) templateId = 'blank';
    });
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
                    widget.store.activeProjects
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
                  for (final template in widget.store.availableNoteTemplates)
                    ChoiceChip(
                      avatar: Text(template.icon),
                      label: Text(template.title),
                      selected: templateId == template.id,
                      onSelected:
                          (_) => setState(() => templateId = template.id),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _manageTemplates,
                icon: const Icon(Icons.dashboard_customize_outlined),
                label: const Text('Мои шаблоны'),
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
