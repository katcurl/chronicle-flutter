part of 'notes_screen.dart';

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
  bool _saveBusy = false;
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
    _editorScrollController =
        ScrollController()..addListener(_rememberEditorScrollOffset);
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
        unawaited(_save(createVersion: false));
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
      final target =
          _editorScrollOffset
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
        canPop: !dirty && !_saveBusy && !_renameReviewBusy,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop || _saveBusy || _renameReviewBusy) {
            return;
          }
          await _saveWithRenameReview(createVersion: false);
          if (mounted && !dirty) {
            Navigator.of(this.context).pop(result);
          }
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
                      effectiveMode == 0
                          ? Icons.edit_rounded
                          : Icons.edit_outlined,
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
                            onPressed:
                                () => Scaffold.of(context).openEndDrawer(),
                            icon: const Icon(Icons.tune_rounded),
                          ),
                    ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'copy_stable_link':
                          unawaited(_copyStableNoteLink());
                          break;
                        case 'link_mentions':
                          unawaited(_linkUnlinkedMentions());
                          break;
                        case 'delete':
                          await widget.store.deleteNote(widget.note.id);
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
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
              floatingActionButton:
                  editorProfile.showTimerButton
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
                        onSubmitted:
                            (_) => unawaited(
                              _saveWithRenameReview(createVersion: false),
                            ),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
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
                        onPressed:
                            _renameReviewBusy
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
            onActivateToolbarProfile:
                (id) => unawaited(_activateToolbarProfile(id)),
            onManageToolbarProfiles:
                () => unawaited(_openToolbarProfileManager()),
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
                    maxWidth:
                        profile.contentWidth > 0
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
                        hintText:
                            r'Markdown, $LaTeX$, [[ссылки]], изображения…',
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
                  maxWidth:
                      profile.contentWidth > 0
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
                      remoteImagePolicy: profile.remoteImagePolicy,
                      allowedRemoteImageDomains:
                          _editorPreferences.allowedRemoteImageDomains.toSet(),
                      onAllowRemoteImageDomain:
                          (domain) =>
                              unawaited(_allowRemoteImageDomain(domain)),
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
      _previewScrollResumeTimer = Timer(const Duration(milliseconds: 140), () {
        _previewTextNotifier.resume();
        if (dirty) {
          _scheduleAutosave();
        }
      });
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

  Future<void> _allowRemoteImageDomain(String domain) async {
    final next = _editorPreferences.allowRemoteImageDomain(domain);
    if (next.allowedRemoteImageDomains.length ==
        _editorPreferences.allowedRemoteImageDomains.length) {
      return;
    }
    setState(() => _editorPreferences = next);
    await _saveEditorPreferences(next);
  }

  Widget _editorProfileSwitcher() {
    final profile = _editorPreferences.activeProfile;
    final colors = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip:
          _editorProfileLoaded
              ? 'Профиль редактора: ${profile.name}'
              : 'Профиль редактора',
      onSelected: (value) {
        if (value == '__manage__') {
          unawaited(_openEditorProfileManager());
        } else {
          unawaited(_activateEditorProfile(value));
        }
      },
      itemBuilder:
          (context) => <PopupMenuEntry<String>>[
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
        SnackBar(content: Text('Не удалось сохранить панель действий: $error')),
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
                          onChanged: (value) async {
                            await widget.store.updateTaskStatus(
                              task,
                              value == true ? 'done' : 'next',
                            );
                          },
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

  Future<void> _save({required bool createVersion}) async {
    if (_saveBusy) {
      return;
    }
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

    if (mounted) {
      setState(() => _saveBusy = true);
    }
    try {
      if (createVersion && dirty && !needsReview) {
        await _recordCurrentVersion('Ручное сохранение');
      }
      final savedTitle = needsReview ? widget.note.title : proposedTitle;
      await _writeEditorState(savedTitle: savedTitle);
      _lastContentText = contentController.text;
      if (needsReview) {
        _lastTitleText = widget.note.title;
        if (mounted) setState(() => dirty = true);
      } else {
        _lastTitleText = titleController.text;
        if (mounted) setState(() => dirty = false);
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => dirty = true);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Заметка не сохранена. Изменения остаются в редакторе: $error',
            ),
            duration: const Duration(seconds: 10),
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _saveBusy = false);
      }
    }
  }

  Future<void> _saveWithRenameReview({required bool createVersion}) async {
    if (_renameReviewBusy) return;
    final proposedTitle = _proposedTitle;
    if (proposedTitle == widget.note.title) {
      await _save(createVersion: createVersion);
      return;
    }

    setState(() => _renameReviewBusy = true);
    try {
      final oldTitle = widget.note.title;
      await _writeEditorState(savedTitle: oldTitle);
      _lastContentText = contentController.text;
      _lastTitleText = oldTitle;
      final plan = widget.store.buildWikiRenamePlan(widget.note, proposedTitle);

      if (!plan.requiresReview) {
        final previous = NoteWikiSnapshot(
          noteId: widget.note.id,
          title: oldTitle,
          body: widget.note.body,
        );
        if (createVersion) {
          await _recordCurrentVersion('Перед переименованием заметки');
        }
        final updated = _buildEditorSnapshot(savedTitle: proposedTitle);
        await widget.store.updateNote(updated);
        final committed = widget.store.noteById(updated.id);
        if (committed != null) {
          _adoptCommittedNote(committed);
        }
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

      if (!mounted) {
        return;
      }
      final decision = await showDialog<_WikiRenameDecision>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _WikiRenamePreviewDialog(plan: plan),
      );
      if (!mounted ||
          decision == null ||
          decision == _WikiRenameDecision.cancel) {
        await widget.store.updateNote(widget.note);
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
        await _recordCurrentVersion(
          'Перед переименованием без обновления ссылок',
        );
        final updated = _buildEditorSnapshot(savedTitle: proposedTitle);
        await widget.store.updateNote(updated);
        final committed = widget.store.noteById(updated.id);
        if (committed != null) {
          _adoptCommittedNote(committed);
        }
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

  Note _buildEditorSnapshot({required String savedTitle}) {
    final snapshot = Note.fromJson(<String, dynamic>{
      ...widget.note.toJson(),
      'title': savedTitle,
      'projectId': projectId,
      'status': status,
      'folderPath': folderPath.trim(),
      'noteType': noteType,
      'tags': List<String>.from(tags),
      'properties': Map<String, String>.from(properties),
      'pinned': pinned,
    });
    snapshot.body = NoteDocument.serialize(snapshot, contentController.text);
    return snapshot;
  }

  Future<void> _writeEditorState({required String savedTitle}) async {
    final snapshot = _buildEditorSnapshot(savedTitle: savedTitle);
    await widget.store.updateNote(snapshot);
    final committed = widget.store.noteById(snapshot.id);
    if (committed != null) {
      _adoptCommittedNote(committed);
    }
  }

  void _adoptCommittedNote(Note committed) {
    widget.note.title = committed.title;
    widget.note.projectId = committed.projectId;
    widget.note.body = committed.body;
    widget.note.tags = List<String>.from(committed.tags);
    widget.note.status = committed.status;
    widget.note.folderPath = committed.folderPath;
    widget.note.noteType = committed.noteType;
    widget.note.properties = Map<String, String>.from(committed.properties);
    widget.note.pinned = committed.pinned;
    widget.note.revision = committed.revision;
    widget.note.createdAt = committed.createdAt;
    widget.note.updatedAt = committed.updatedAt;
    widget.note.deletedAt = committed.deletedAt;
  }

  Future<void> _recordCurrentVersion(String reason) {
    return widget.store.addNoteVersion(
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
        const SnackBar(
          content: Text('Переименование и изменения ссылок отменены.'),
        ),
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
                widget.store.projectById(note.projectId)?.title ??
                'Без проекта',
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
      projectTitle: widget.store.projectById(projectId)?.title ?? 'Без проекта',
      folderPath: folderPath,
      noteType: noteType,
      tags: List<String>.from(tags),
    );
  }

  Future<void> _insertNoteLinks() async {
    final targets = _availableNoteLinkTargets();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Других заметок пока нет.')));
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
    final markdown = NoteLinkTools.compose(result.targets, style: result.style);
    if (result.style == NoteLinkInsertStyle.inline) {
      _insertInlineMarkdown(markdown);
    } else {
      _insertMarkdownAtSelection(markdown);
    }
  }

  Future<void> _linkUnlinkedMentions() async {
    final targets = _availableNoteLinkTargets();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Других заметок пока нет.')));
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
    final cursor =
        originalValue.selection.isValid
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
      SnackBar(content: Text('Создано устойчивых ссылок: ${selected.length}.')),
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
    final offset =
        selection.isValid ? selection.extentOffset : value.text.length;
    ScientificTableReference? currentReference;
    for (final table in ScientificReferenceSyntax.tables(value.text)) {
      final selectionIntersects =
          selection.isValid &&
          !selection.isCollapsed &&
          selection.start < table.end &&
          selection.end > table.start;
      if ((offset >= table.start && offset <= table.end) ||
          selectionIntersects) {
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
    final currentKey =
        currentReference == null
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
      builder:
          (context) =>
              _CitationPickerDialog(sources: widget.store.data.citationSources),
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
      final markdown = NoteDocument.parse(draft.body).content;
      final payload = switch (format) {
        ChronicleExportFormat.docx ||
        ChronicleExportFormat.pdf => await PublicationDocumentExporter(
          readAttachment: widget.store.readManagedAttachment,
        ).export(format: format, title: draft.title, markdown: markdown),
        _ => await NoteExportComposer(
          readAttachment: widget.store.readManagedAttachment,
        ).exportNote(note: draft, projectTitle: projectTitle, format: format),
      };
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
          existingObjectKeys: {for (final object in index.objects) object.key},
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
      final duplicateCount =
          results.where((result) => result.alreadyExisted).length;
      final duplicateSuffix =
          duplicateCount == 0 ? '' : '; $duplicateCount уже были в Vault';
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
      initial: const NoteColumnsLayout(columnCount: 2, widths: [40, 60]),
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
      initialContents: [for (final column in current.columns) column.markdown],
      editingExisting: true,
    );
    if (result == null || !mounted) {
      return;
    }
    if (result.unwrap) {
      _unwrapColumnsReference(current, contents: result.contents);
      return;
    }
    _replaceColumnsLayout(current, result.layout, contents: result.contents);
  }

  void _replaceColumnsWidths(NoteColumnsReference reference, List<int> widths) {
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
      current.toMarkdown(widths: widths, contents: contents),
    );
  }

  void _replaceColumnsText(NoteColumnsReference reference, String replacement) {
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
    await widget.store.addTask(task);
    if (mounted) setState(() {});
  }

  Future<void> _openWikiLink(String rawTarget) async {
    _save(createVersion: false);
    final reference = NoteWikiTarget.parse(rawTarget);
    final candidates = widget.store.notesForWikiTarget(
      rawTarget,
      source: widget.note,
    );
    var target = widget.store.resolveWikiTarget(rawTarget, source: widget.note);

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
      await widget.store.addNote(target);
      await widget.store.rebuildAllNoteLinks();
    }
    if (!mounted) return;
    await _openNote(target);
  }

  Future<Note?> _chooseWikiTarget(String title, List<Note> candidates) {
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
    await _restoreVersion(selected);
  }

  Future<void> _openNote(Note? note) async {
    if (note == null || note.id == widget.note.id) return;
    _save(createVersion: false);
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
    if (mounted) setState(() {});
  }

  Future<void> _restoreVersion(NoteVersion version) async {
    final current = _currentVersionSnapshot();
    await widget.store.addNoteVersion(
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
