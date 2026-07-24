part of 'notes_screen.dart';

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
            onPressed:
                widget.store.activeProjects.isEmpty ? null : () => _add(),
            icon: const Icon(Icons.note_add_outlined),
          ),
        ],
      ),
      body:
          _showHome
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
                onCreateFromTemplate:
                    (template) => _add(initialTemplateId: template.id),
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
                          onChanged:
                              (value) => setState(() => projectFilter = value),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Все папки'),
                          selected: folderFilter == null,
                          onSelected:
                              (_) => setState(() => folderFilter = null),
                        ),
                        for (final folder in folders) ...[
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text(folder),
                            selected: folderFilter == folder,
                            onSelected:
                                (_) => setState(() => folderFilter = folder),
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
                                  itemBuilder:
                                      (_, index) => _NoteCard(
                                        store: widget.store,
                                        note: notes[index],
                                        appearanceController:
                                            widget.appearanceController,
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
            (context) => _LinkHealthDialog(store: widget.store, issues: issues),
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

  Future<void> _repairLinkIssue(NoteWikiLinkIssue issue, Note source) async {
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
      await widget.store.addNote(target);
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
        builder: (_) => NoteGraphScreen(store: widget.store, onOpenNote: _open),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openResearchCanvas() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (_) => ResearchCanvasScreen(store: widget.store, onOpenNote: _open),
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
    await widget.store.addNote(note);
    await _open(note);
  }

  Future<void> _open(Note note) async {
    if (PublicationWorkspaceCodec.isPublication(note)) {
      final project = widget.store.projectById(note.projectId);
      if (project == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не найден проект этого документа.')),
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
          builder:
              (_) => NoteWorkspaceScreen(
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
