import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/app_models.dart';
import '../../services/app_store.dart';
import 'note_document.dart';
import 'note_templates.dart';
import 'research_canvas_dialogs.dart';
import 'research_canvas_models.dart';
import 'research_canvas_store.dart';

typedef ResearchCanvasOpenNote = Future<void> Function(Note note);

class ResearchCanvasScreen extends StatefulWidget {
  const ResearchCanvasScreen({
    super.key,
    required this.store,
    required this.onOpenNote,
    ResearchCanvasStore? canvasStore,
  }) : canvasStore = canvasStore ?? const ResearchCanvasStore();

  final AppStore store;
  final ResearchCanvasOpenNote onOpenNote;
  final ResearchCanvasStore canvasStore;

  @override
  State<ResearchCanvasScreen> createState() => _ResearchCanvasScreenState();
}


enum _CanvasBoardAction { create, edit, duplicate, delete }

class _ResearchCanvasScreenState extends State<ResearchCanvasScreen> {
  static const Size _canvasSize = Size(3600, 2400);
  static const Uuid _uuid = Uuid();

  final TransformationController _transformationController =
      TransformationController();
  ResearchCanvasPreferences _preferences =
      ResearchCanvasPreferences.defaults();
  bool _loading = true;
  Object? _loadError;
  String? _selectedItemId;
  String? _connectionSourceItemId;
  Timer? _saveTimer;

  ResearchCanvas get _canvas => _preferences.activeCanvas;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    if (!_loading) {
      unawaited(_save());
    }
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final loaded = await widget.canvasStore.load();
      if (!mounted) return;
      setState(() {
        _preferences = loaded;
        _loading = false;
        _loadError = null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Карта исследования')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 44),
                const SizedBox(height: 12),
                const Text('Не удалось открыть исследовательские карты.'),
                const SizedBox(height: 8),
                Text(_loadError.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _loadError = null;
                    });
                    unawaited(_load());
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final notesById = <String, Note>{
      for (final note in widget.store.data.notes) note.id: note,
    };
    final projectsById = <String, Project>{
      for (final project in widget.store.data.projects) project.id: project,
    };
    final selected = _selectedItemId == null
        ? null
        : _canvas.itemById(_selectedItemId!);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: Row(
          children: [
            const Text('Карта исследования'),
            const SizedBox(width: 16),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _canvas.id,
                borderRadius: BorderRadius.circular(14),
                items: [
                  for (final canvas in _preferences.canvases)
                    DropdownMenuItem<String>(
                      value: canvas.id,
                      child: Text('${canvas.emoji} ${canvas.name}'),
                    ),
                ],
                onChanged: (value) {
                  if (value == null || value == _canvas.id) return;
                  setState(() {
                    _preferences = _preferences.copyWith(
                      activeCanvasId: value,
                    );
                    _selectedItemId = null;
                    _connectionSourceItemId = null;
                  });
                  _resetView();
                  _scheduleSave();
                },
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Добавить заметки',
            onPressed: _addNotes,
            icon: const Icon(Icons.note_add_outlined),
          ),
          IconButton(
            tooltip: 'Добавить текстовую карточку',
            onPressed: _addTextItem,
            icon: const Icon(Icons.sticky_note_2_outlined),
          ),
          IconButton(
            tooltip: 'Добавить смысловую область',
            onPressed: _addGroup,
            icon: const Icon(Icons.crop_free_rounded),
          ),
          IconButton(
            tooltip: _connectionSourceItemId == null
                ? 'Связать две карточки'
                : 'Выбери вторую карточку или отмени связь',
            onPressed: () {
              setState(() {
                _connectionSourceItemId =
                    _connectionSourceItemId == null ? '' : null;
              });
            },
            icon: Icon(
              _connectionSourceItemId == null
                  ? Icons.timeline_outlined
                  : Icons.link_off_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Разложить карточки сеткой',
            onPressed: _arrangeGrid,
            icon: const Icon(Icons.grid_view_rounded),
          ),
          PopupMenuButton<_CanvasBoardAction>(
            tooltip: 'Управление картами',
            onSelected: _handleBoardAction,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _CanvasBoardAction.create,
                child: ListTile(
                  leading: Icon(Icons.add_rounded),
                  title: Text('Новая карта'),
                ),
              ),
              PopupMenuItem(
                value: _CanvasBoardAction.edit,
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Настроить текущую'),
                ),
              ),
              PopupMenuItem(
                value: _CanvasBoardAction.duplicate,
                child: ListTile(
                  leading: Icon(Icons.copy_all_outlined),
                  title: Text('Дублировать'),
                ),
              ),
              PopupMenuItem(
                value: _CanvasBoardAction.delete,
                child: ListTile(
                  leading: Icon(Icons.delete_outline_rounded),
                  title: Text('Удалить текущую'),
                ),
              ),
            ],
            icon: const Icon(Icons.dashboard_customize_outlined),
          ),
          IconButton(
            tooltip: 'Сбросить масштаб и положение',
            onPressed: _resetView,
            icon: const Icon(Icons.center_focus_strong_rounded),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final showInspector = selected != null && constraints.maxWidth >= 1120;
          return Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _CanvasStatusBar(
                      canvas: _canvas,
                      connecting: _connectionSourceItemId != null,
                      connectionSource: _connectionSourceItemId == null ||
                              _connectionSourceItemId!.isEmpty
                          ? null
                          : _canvas.itemById(_connectionSourceItemId!),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _buildCanvas(
                        notesById: notesById,
                        projectsById: projectsById,
                      ),
                    ),
                  ],
                ),
              ),
              if (showInspector) ...[
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 330,
                  child: _CanvasInspector(
                    item: selected,
                    note: selected.type == ResearchCanvasItemType.note
                        ? notesById[selected.noteId]
                        : null,
                    project: selected.type == ResearchCanvasItemType.note
                        ? projectsById[notesById[selected.noteId]?.projectId]
                        : null,
                    connections: _canvas.connections
                        .where(
                          (connection) =>
                              connection.sourceItemId == selected.id ||
                              connection.targetItemId == selected.id,
                        )
                        .toList(growable: false),
                    itemsById: <String, ResearchCanvasItem>{
                      for (final item in _canvas.items) item.id: item,
                    },
                    onOpenNote: () => _openItemNote(selected),
                    onEdit: () => _editItem(selected),
                    onDuplicate: () => _duplicateItem(selected),
                    onDelete: () => _deleteItem(selected),
                    onResize: (width, height) =>
                        _resizeItem(selected, width, height),
                    onDeleteConnection: _deleteConnection,
                    onStartConnection: () {
                      setState(() {
                        _connectionSourceItemId = selected.id;
                      });
                    },
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildCanvas({
    required Map<String, Note> notesById,
    required Map<String, Project> projectsById,
  }) {
    final itemsById = <String, ResearchCanvasItem>{
      for (final item in _canvas.items) item.id: item,
    };
    final groups = _canvas.items.where((item) => item.isGroup);
    final cards = _canvas.items.where((item) => !item.isGroup);
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: InteractiveViewer(
        transformationController: _transformationController,
        constrained: false,
        minScale: 0.3,
        maxScale: 2.5,
        boundaryMargin: const EdgeInsets.all(320),
        clipBehavior: Clip.none,
        child: SizedBox(
          width: _canvasSize.width,
          height: _canvasSize.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Positioned.fill(
                child: IgnorePointer(child: CustomPaint(painter: _GridPainter())),
              ),
              for (final item in groups)
                _positionedItem(
                  item: item,
                  note: null,
                  project: null,
                ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ConnectionPainter(
                      itemsById: itemsById,
                      connections: _canvas.connections,
                      selectedItemId: _selectedItemId,
                      color: Theme.of(context).colorScheme.outline,
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              for (final item in cards)
                _positionedItem(
                  item: item,
                  note: item.noteId == null ? null : notesById[item.noteId],
                  project: item.noteId == null
                      ? null
                      : projectsById[notesById[item.noteId]?.projectId],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _positionedItem({
    required ResearchCanvasItem item,
    required Note? note,
    required Project? project,
  }) {
    final selected = item.id == _selectedItemId;
    final connectionSource = item.id == _connectionSourceItemId;
    return Positioned(
      left: item.x,
      top: item.y,
      width: item.width,
      height: item.height,
      child: _ResearchCanvasCard(
        item: item,
        note: note,
        project: project,
        selected: selected,
        connectionSource: connectionSource,
        onTap: () => _handleItemTap(item),
        onDoubleTap: () => _openItemNote(item),
        onDragUpdate: (delta) => _moveItem(item, delta),
        onDragEnd: _scheduleSave,
        onEdit: () => _editItem(item),
        onDelete: () => _deleteItem(item),
      ),
    );
  }

  void _handleItemTap(ResearchCanvasItem item) {
    if (_connectionSourceItemId != null) {
      if (_connectionSourceItemId!.isEmpty) {
        setState(() {
          _connectionSourceItemId = item.id;
          _selectedItemId = item.id;
        });
        return;
      }
      if (_connectionSourceItemId == item.id) {
        setState(() => _connectionSourceItemId = null);
        return;
      }
      _createConnection(_connectionSourceItemId!, item.id);
      return;
    }
    setState(() => _selectedItemId = item.id);
  }

  void _moveItem(ResearchCanvasItem item, Offset delta) {
    final scale = math.max(
      0.1,
      _transformationController.value.getMaxScaleOnAxis(),
    );
    final moved = item.copyWith(
      x: item.x + delta.dx / scale,
      y: item.y + delta.dy / scale,
    );
    _replaceItem(moved, saveImmediately: false);
  }

  void _replaceItem(
    ResearchCanvasItem item, {
    bool saveImmediately = true,
  }) {
    final nextCanvas = _canvas.copyWith(
      items: <ResearchCanvasItem>[
        for (final current in _canvas.items)
          if (current.id == item.id) item else current,
      ],
    );
    setState(() {
      _preferences = _preferences.replaceCanvas(nextCanvas);
    });
    if (saveImmediately) {
      _scheduleSave();
    }
  }

  Future<void> _addNotes() async {
    final existing = <String>{
      for (final item in _canvas.items)
        if (item.noteId != null) item.noteId!,
    };
    final selected = await ResearchCanvasNotePickerDialog.show(
      context,
      notes: widget.store.data.notes,
      projects: widget.store.data.projects,
      excludedNoteIds: existing,
      initialProjectId: _canvas.projectId,
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    final nextItems = List<ResearchCanvasItem>.from(_canvas.items);
    for (var index = 0; index < selected.length; index += 1) {
      final note = selected[index];
      final position = _nextCardPosition(nextItems.length + index);
      final project = widget.store.projectById(note.projectId);
      nextItems.add(
        ResearchCanvasItem.normalized(
          id: _uuid.v4(),
          type: ResearchCanvasItemType.note,
          noteId: note.id,
          title: note.title,
          body: '',
          x: position.dx,
          y: position.dy,
          width: 290,
          height: 180,
          colorValue: project?.colorValue ?? 0xFF6750A4,
        ),
      );
    }
    _replaceCanvas(_canvas.copyWith(items: nextItems));
  }

  Future<void> _addTextItem() async {
    final draft = await ResearchCanvasItemDialog.show(
      context,
      type: ResearchCanvasItemType.text,
    );
    if (draft == null || !mounted) return;
    final position = _nextCardPosition(_canvas.items.length);
    final item = ResearchCanvasItem.normalized(
      id: _uuid.v4(),
      type: ResearchCanvasItemType.text,
      title: draft.title,
      body: draft.body,
      x: position.dx,
      y: position.dy,
      width: 300,
      height: 190,
      colorValue: draft.colorValue,
    );
    _replaceCanvas(
      _canvas.copyWith(items: <ResearchCanvasItem>[..._canvas.items, item]),
    );
    setState(() => _selectedItemId = item.id);
  }

  Future<void> _addGroup() async {
    final draft = await ResearchCanvasItemDialog.show(
      context,
      type: ResearchCanvasItemType.group,
    );
    if (draft == null || !mounted) return;
    final item = ResearchCanvasItem.normalized(
      id: _uuid.v4(),
      type: ResearchCanvasItemType.group,
      title: draft.title,
      body: draft.body,
      x: 80 + (_canvas.items.length % 5) * 46,
      y: 80 + (_canvas.items.length % 4) * 38,
      width: 660,
      height: 430,
      colorValue: draft.colorValue,
    );
    _replaceCanvas(
      _canvas.copyWith(items: <ResearchCanvasItem>[..._canvas.items, item]),
    );
    setState(() => _selectedItemId = item.id);
  }

  Future<void> _editItem(ResearchCanvasItem item) async {
    if (item.type == ResearchCanvasItemType.note) {
      final note = item.noteId == null ? null : widget.store.noteById(item.noteId!);
      if (note != null) await _openItemNote(item);
      return;
    }
    final draft = await ResearchCanvasItemDialog.show(
      context,
      type: item.type,
      initial: item,
    );
    if (draft == null || !mounted) return;
    _replaceItem(
      item.copyWith(
        title: draft.title,
        body: draft.body,
        colorValue: draft.colorValue,
      ),
    );
  }

  Future<void> _openItemNote(ResearchCanvasItem item) async {
    if (item.type != ResearchCanvasItemType.note || item.noteId == null) return;
    final note = widget.store.noteById(item.noteId!);
    if (note == null) return;
    await widget.onOpenNote(note);
    if (mounted) setState(() {});
  }

  void _duplicateItem(ResearchCanvasItem item) {
    final duplicate = item.copyWith(
      id: _uuid.v4(),
      title: item.type == ResearchCanvasItemType.note
          ? item.title
          : 'Копия — ${item.title}',
      x: item.x + 36,
      y: item.y + 36,
    );
    _replaceCanvas(
      _canvas.copyWith(
        items: <ResearchCanvasItem>[..._canvas.items, duplicate],
      ),
    );
    setState(() => _selectedItemId = duplicate.id);
  }

  Future<void> _deleteItem(ResearchCanvasItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Убрать карточку с карты?'),
        content: Text(
          item.type == ResearchCanvasItemType.note
              ? 'Сама заметка не будет удалена.'
              : 'Карточка и её ручные связи будут удалены только с этой карты.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Убрать'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _replaceCanvas(
      _canvas.copyWith(
        items: _canvas.items
            .where((current) => current.id != item.id)
            .toList(growable: false),
        connections: _canvas.connections
            .where(
              (connection) =>
                  connection.sourceItemId != item.id &&
                  connection.targetItemId != item.id,
            )
            .toList(growable: false),
      ),
    );
    setState(() {
      if (_selectedItemId == item.id) _selectedItemId = null;
      if (_connectionSourceItemId == item.id) _connectionSourceItemId = null;
    });
  }

  void _resizeItem(ResearchCanvasItem item, double width, double height) {
    _replaceItem(item.copyWith(width: width, height: height));
  }

  void _createConnection(String sourceId, String targetId) {
    final exists = _canvas.connections.any(
      (connection) =>
          connection.sourceItemId == sourceId &&
          connection.targetItemId == targetId,
    );
    if (!exists) {
      _replaceCanvas(
        _canvas.copyWith(
          connections: <ResearchCanvasConnection>[
            ..._canvas.connections,
            ResearchCanvasConnection(
              id: _uuid.v4(),
              sourceItemId: sourceId,
              targetItemId: targetId,
            ),
          ],
        ),
      );
    }
    setState(() {
      _selectedItemId = targetId;
      _connectionSourceItemId = null;
    });
  }

  void _deleteConnection(ResearchCanvasConnection connection) {
    _replaceCanvas(
      _canvas.copyWith(
        connections: _canvas.connections
            .where((current) => current.id != connection.id)
            .toList(growable: false),
      ),
    );
  }

  void _arrangeGrid() {
    final nonGroups = _canvas.items.where((item) => !item.isGroup).toList();
    final groups = _canvas.items.where((item) => item.isGroup).toList();
    final arranged = <ResearchCanvasItem>[...groups];
    for (var index = 0; index < nonGroups.length; index += 1) {
      final item = nonGroups[index];
      final column = index % 5;
      final row = index ~/ 5;
      arranged.add(
        item.copyWith(
          x: 140 + column * 340,
          y: 140 + row * 240,
        ),
      );
    }
    _replaceCanvas(_canvas.copyWith(items: arranged));
    _resetView();
  }

  Offset _nextCardPosition(int index) {
    final column = index % 5;
    final row = (index ~/ 5) % 7;
    return Offset(140 + column * 330, 140 + row * 225);
  }

  Future<void> _handleBoardAction(_CanvasBoardAction action) async {
    switch (action) {
      case _CanvasBoardAction.create:
        await _createBoard();
        return;
      case _CanvasBoardAction.edit:
        await _editBoard();
        return;
      case _CanvasBoardAction.duplicate:
        _duplicateBoard();
        return;
      case _CanvasBoardAction.delete:
        await _deleteBoard();
        return;
    }
  }

  Future<void> _createBoard() async {
    if (_preferences.canvases.length >= ResearchCanvas.maxCanvases) {
      _showMessage('Можно хранить не больше ${ResearchCanvas.maxCanvases} карт.');
      return;
    }
    final draft = await ResearchCanvasBoardDialog.show(
      context,
      projects: widget.store.data.projects,
    );
    if (draft == null || !mounted) return;
    final canvas = ResearchCanvas.empty(
      id: _uuid.v4(),
      name: draft.name,
      emoji: draft.emoji,
      projectId: draft.projectId,
    );
    setState(() {
      _preferences = _preferences.copyWith(
        activeCanvasId: canvas.id,
        canvases: <ResearchCanvas>[..._preferences.canvases, canvas],
      );
      _selectedItemId = null;
      _connectionSourceItemId = null;
    });
    _resetView();
    _scheduleSave();
  }

  Future<void> _editBoard() async {
    final draft = await ResearchCanvasBoardDialog.show(
      context,
      projects: widget.store.data.projects,
      initial: _canvas,
    );
    if (draft == null || !mounted) return;
    _replaceCanvas(
      _canvas.copyWith(
        name: draft.name,
        emoji: draft.emoji,
        projectId: draft.projectId,
        clearProjectId: draft.projectId == null,
      ),
    );
  }

  void _duplicateBoard() {
    if (_preferences.canvases.length >= ResearchCanvas.maxCanvases) {
      _showMessage('Можно хранить не больше ${ResearchCanvas.maxCanvases} карт.');
      return;
    }
    final duplicate = _canvas.duplicate(newId: _uuid.v4());
    setState(() {
      _preferences = _preferences.copyWith(
        activeCanvasId: duplicate.id,
        canvases: <ResearchCanvas>[..._preferences.canvases, duplicate],
      );
      _selectedItemId = null;
      _connectionSourceItemId = null;
    });
    _resetView();
    _scheduleSave();
  }

  Future<void> _deleteBoard() async {
    if (_preferences.canvases.length <= 1) {
      _showMessage('Последнюю карту удалить нельзя.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить карту «${_canvas.name}»?'),
        content: const Text(
          'Удалится только расположение карточек. Заметки, проекты и файлы останутся на месте.',
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
    if (confirmed != true || !mounted) return;
    final next = _preferences.canvases
        .where((canvas) => canvas.id != _canvas.id)
        .toList(growable: false);
    setState(() {
      _preferences = ResearchCanvasPreferences.normalized(
        activeCanvasId: next.first.id,
        canvases: next,
      );
      _selectedItemId = null;
      _connectionSourceItemId = null;
    });
    _resetView();
    _scheduleSave();
  }

  void _replaceCanvas(ResearchCanvas canvas) {
    setState(() {
      _preferences = _preferences.replaceCanvas(canvas);
    });
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(_save());
    });
  }

  Future<void> _save() async {
    try {
      await widget.canvasStore.save(_preferences);
    } on Object catch (error) {
      if (!mounted) return;
      _showMessage('Не удалось сохранить карту: $error');
    }
  }

  void _resetView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _transformationController.value = Matrix4.identity();
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CanvasStatusBar extends StatelessWidget {
  const _CanvasStatusBar({
    required this.canvas,
    required this.connecting,
    required this.connectionSource,
  });

  final ResearchCanvas canvas;
  final bool connecting;
  final ResearchCanvasItem? connectionSource;

  @override
  Widget build(BuildContext context) {
    final source = connectionSource;
    final noteCount = canvas.items
        .where((item) => item.type == ResearchCanvasItemType.note)
        .length;
    final textCount = canvas.items
        .where((item) => item.type == ResearchCanvasItemType.text)
        .length;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Text('$noteCount заметок · $textCount карточек'),
            const SizedBox(width: 16),
            Text('${canvas.connections.length} ручных связей'),
            const Spacer(),
            if (connecting)
              Chip(
                avatar: const Icon(Icons.timeline_rounded, size: 18),
                label: Text(
                  source == null
                      ? 'Выбери первую карточку'
                      : 'Источник: ${source.title}',
                ),
              )
            else
              const Text(
                'Перетаскивай карточки за верхнюю область',
                style: TextStyle(fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResearchCanvasCard extends StatelessWidget {
  const _ResearchCanvasCard({
    required this.item,
    required this.note,
    required this.project,
    required this.selected,
    required this.connectionSource,
    required this.onTap,
    required this.onDoubleTap,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onEdit,
    required this.onDelete,
  });

  final ResearchCanvasItem item;
  final Note? note;
  final Project? project;
  final bool selected;
  final bool connectionSource;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final currentNote = note;
    final currentProject = project;
    final color = Color(item.colorValue);
    if (item.isGroup) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        onPanUpdate: (details) => onDragUpdate(details.delta),
        onPanEnd: (_) => onDragEnd(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected || connectionSource
                  ? color
                  : color.withValues(alpha: 0.55),
              width: selected || connectionSource ? 3 : 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.drag_indicator_rounded, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    _CardMenu(onEdit: onEdit, onDelete: onDelete),
                  ],
                ),
                if (item.body.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.body,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final missingNote =
        item.type == ResearchCanvasItemType.note && currentNote == null;
    final title = currentNote?.title ?? item.title;
    final excerpt = currentNote == null
        ? item.body
        : _excerpt(NoteDocument.parse(currentNote.body).content);
    return Card(
      elevation: selected || connectionSource ? 7 : 2,
      color: color.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: connectionSource
              ? color
              : selected
                  ? Theme.of(context).colorScheme.primary
                  : color.withValues(alpha: 0.48),
          width: selected || connectionSource ? 2.5 : 1.2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) => onDragUpdate(details.delta),
              onPanEnd: (_) => onDragEnd(),
              child: ColoredBox(
                color: color.withValues(alpha: 0.16),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.drag_indicator_rounded, size: 18),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      _CardMenu(onEdit: onEdit, onDelete: onDelete),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.type == ResearchCanvasItemType.note)
                      Text(
                        missingNote
                            ? 'Исходная заметка недоступна'
                            : <String>[
                                if (currentProject != null)
                                  '${currentProject.emoji} ${currentProject.title}',
                                if (currentNote != null &&
                                    currentNote.noteType.trim().isNotEmpty)
                                  noteTypeLabel(currentNote.noteType),
                              ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (excerpt.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(
                          excerpt,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else
                      const Spacer(),
                    if (currentNote != null && currentNote.tags.isNotEmpty)
                      Text(
                        currentNote.tags.take(4).map((tag) => '#$tag').join(' '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _excerpt(String markdown) {
    final text = markdown
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
        .replaceAll(RegExp(r'[#>*_`\[\]()]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text.length <= 280 ? text : '${text.substring(0, 277)}…';
  }
}

class _CardMenu extends StatelessWidget {
  const _CardMenu({required this.onEdit, required this.onDelete});

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Действия с карточкой',
      padding: EdgeInsets.zero,
      onSelected: (value) {
        if (value == 'edit') onEdit();
        if (value == 'delete') onDelete();
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'edit', child: Text('Открыть или изменить')),
        PopupMenuItem(value: 'delete', child: Text('Убрать с карты')),
      ],
      icon: const Icon(Icons.more_horiz_rounded, size: 19),
    );
  }
}

class _CanvasInspector extends StatelessWidget {
  const _CanvasInspector({
    required this.item,
    required this.note,
    required this.project,
    required this.connections,
    required this.itemsById,
    required this.onOpenNote,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.onResize,
    required this.onDeleteConnection,
    required this.onStartConnection,
  });

  final ResearchCanvasItem item;
  final Note? note;
  final Project? project;
  final List<ResearchCanvasConnection> connections;
  final Map<String, ResearchCanvasItem> itemsById;
  final VoidCallback onOpenNote;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final void Function(double width, double height) onResize;
  final ValueChanged<ResearchCanvasConnection> onDeleteConnection;
  final VoidCallback onStartConnection;

  @override
  Widget build(BuildContext context) {
    final currentNote = note;
    final currentProject = project;
    final isGroup = item.type == ResearchCanvasItemType.group;
    final sizeOptions = isGroup
        ? const <(String, double, double)>[
            ('Компактная', 480, 300),
            ('Обычная', 660, 430),
            ('Большая', 860, 580),
          ]
        : const <(String, double, double)>[
            ('Компактная', 230, 145),
            ('Обычная', 300, 190),
            ('Широкая', 430, 220),
          ];
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            Icon(
              switch (item.type) {
                ResearchCanvasItemType.note => Icons.description_outlined,
                ResearchCanvasItemType.text => Icons.sticky_note_2_outlined,
                ResearchCanvasItemType.group => Icons.crop_free_rounded,
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                currentNote?.title ?? item.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        if (currentProject != null) ...[
          const SizedBox(height: 8),
          Text('${currentProject.emoji} ${currentProject.title}'),
        ],
        if (item.body.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(item.body),
        ],
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (item.type == ResearchCanvasItemType.note)
              FilledButton.icon(
                onPressed: currentNote == null ? null : onOpenNote,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Открыть'),
              )
            else
              FilledButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Изменить'),
              ),
            OutlinedButton.icon(
              onPressed: onDuplicate,
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('Копия'),
            ),
            OutlinedButton.icon(
              onPressed: onStartConnection,
              icon: const Icon(Icons.timeline_rounded),
              label: const Text('Связать'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Размер', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final option in sizeOptions)
          ListTile(
            dense: true,
            title: Text(option.$1),
            trailing: Text('${option.$2.toInt()}×${option.$3.toInt()}'),
            onTap: () => onResize(option.$2, option.$3),
          ),
        const Divider(height: 28),
        Row(
          children: [
            Expanded(
              child: Text(
                'Ручные связи',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Text('${connections.length}'),
          ],
        ),
        const SizedBox(height: 6),
        if (connections.isEmpty)
          const Text('У карточки пока нет ручных связей.')
        else
          for (final connection in connections)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                connection.sourceItemId == item.id
                    ? Icons.arrow_forward_rounded
                    : Icons.arrow_back_rounded,
              ),
              title: Text(
                itemsById[
                          connection.sourceItemId == item.id
                              ? connection.targetItemId
                              : connection.sourceItemId
                        ]
                        ?.title ??
                    'Карточка',
              ),
              trailing: IconButton(
                tooltip: 'Удалить связь',
                onPressed: () => onDeleteConnection(connection),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
        const Divider(height: 28),
        TextButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Убрать с карты'),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final minor = Paint()
      ..color = const Color(0x14000000)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 1.2;
    const step = 40.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        ((x / step).round() % 5 == 0) ? major : minor,
      );
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        ((y / step).round() % 5 == 0) ? major : minor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}

class _ConnectionPainter extends CustomPainter {
  const _ConnectionPainter({
    required this.itemsById,
    required this.connections,
    required this.selectedItemId,
    required this.color,
    required this.activeColor,
  });

  final Map<String, ResearchCanvasItem> itemsById;
  final List<ResearchCanvasConnection> connections;
  final String? selectedItemId;
  final Color color;
  final Color activeColor;

  @override
  void paint(Canvas canvas, Size size) {
    for (final connection in connections) {
      final source = itemsById[connection.sourceItemId];
      final target = itemsById[connection.targetItemId];
      if (source == null || target == null) continue;
      final start = Offset(source.x + source.width / 2, source.y + source.height / 2);
      final end = Offset(target.x + target.width / 2, target.y + target.height / 2);
      final active = selectedItemId == source.id || selectedItemId == target.id;
      final paint = Paint()
        ..color = active
            ? activeColor.withValues(alpha: 0.88)
            : color.withValues(alpha: 0.48)
        ..strokeWidth = active ? 3 : 2
        ..style = PaintingStyle.stroke;
      final direction = end - start;
      if (direction.distance < 12) continue;
      final control = Offset(
        (start.dx + end.dx) / 2,
        (start.dy + end.dy) / 2 - math.min(90, direction.distance * 0.14),
      );
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
      canvas.drawPath(path, paint);
      _drawArrow(canvas, control, end, paint);
    }
  }

  void _drawArrow(Canvas canvas, Offset control, Offset end, Paint paint) {
    final angle = math.atan2(end.dy - control.dy, end.dx - control.dx);
    const length = 12.0;
    const spread = 0.55;
    final first = Offset(
      end.dx - length * math.cos(angle - spread),
      end.dy - length * math.sin(angle - spread),
    );
    final second = Offset(
      end.dx - length * math.cos(angle + spread),
      end.dy - length * math.sin(angle + spread),
    );
    canvas.drawLine(end, first, paint);
    canvas.drawLine(end, second, paint);
  }

  @override
  bool shouldRepaint(covariant _ConnectionPainter oldDelegate) {
    return oldDelegate.itemsById != itemsById ||
        oldDelegate.connections != connections ||
        oldDelegate.selectedItemId != selectedItemId ||
        oldDelegate.color != color ||
        oldDelegate.activeColor != activeColor;
  }
}
