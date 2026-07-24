part of 'notes_screen.dart';

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
                        canConvert && block?.type != NoteBlockType.bulletedList,
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
      tooltip:
          widget.toolbarPreferencesLoaded
              ? 'Панель действий: ${active.name}'
              : 'Панель быстрых действий',
      onSelected: (value) {
        if (value == '__manage__') {
          widget.onManageToolbarProfiles();
        } else {
          widget.onActivateToolbarProfile(value);
        }
      },
      itemBuilder:
          (context) => <PopupMenuEntry<String>>[
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
