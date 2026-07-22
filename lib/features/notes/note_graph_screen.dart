import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../services/app_store.dart';
import 'note_graph_analysis.dart';
import 'note_graph_layout.dart';
import 'note_templates.dart';

typedef NoteGraphOpenNote = Future<void> Function(Note note);

class NoteGraphScreen extends StatefulWidget {
  const NoteGraphScreen({
    super.key,
    required this.store,
    required this.onOpenNote,
  });

  final AppStore store;
  final NoteGraphOpenNote onOpenNote;

  @override
  State<NoteGraphScreen> createState() => _NoteGraphScreenState();
}

class _NoteGraphScreenState extends State<NoteGraphScreen> {
  final TransformationController _transformationController =
      TransformationController();
  final ValueNotifier<String?> _hoveredNoteId = ValueNotifier<String?>(null);

  String query = '';
  String? projectFilter;
  String? noteTypeFilter;
  String? tagFilter;
  String? selectedNoteId;
  bool connectedOnly = false;
  bool showDirections = true;
  bool focusMode = false;
  int focusDepth = 1;

  @override
  void dispose() {
    _hoveredNoteId.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allNotes = widget.store.data.notes;
    final projects = List<Project>.from(widget.store.data.projects)
      ..sort(
        (left, right) => left.title.toLowerCase().compareTo(
          right.title.toLowerCase(),
        ),
      );
    final allNotesById = <String, Note>{
      for (final note in allNotes) note.id: note,
    };
    final analysis = NoteGraphAnalysis.build(
      notes: allNotes,
      links: widget.store.data.noteLinks,
    );
    final selectedNote =
        selectedNoteId == null ? null : allNotesById[selectedNoteId!];
    final focusIds =
        focusMode && selectedNote != null
            ? analysis.neighborhood(selectedNote.id, depth: focusDepth)
            : null;

    final visibleNotes = allNotes.where((note) {
      if (focusIds != null) {
        return focusIds.contains(note.id);
      }
      if (projectFilter != null && note.projectId != projectFilter) {
        return false;
      }
      if (noteTypeFilter != null && note.noteType != noteTypeFilter) {
        return false;
      }
      if (tagFilter != null && !note.tags.contains(tagFilter)) {
        return false;
      }
      if (connectedOnly && analysis.isolatedNoteIds.contains(note.id)) {
        return false;
      }
      return true;
    }).toList(growable: false);

    final visibleAnalysis = NoteGraphAnalysis.build(
      notes: visibleNotes,
      links: widget.store.data.noteLinks,
    );
    final projectOrder = [for (final project in projects) project.id];
    final layout = NoteGraphLayoutEngine.build(
      allNotes: allNotes,
      visibleNotes: visibleNotes,
      links: widget.store.data.noteLinks,
      projectOrder: projectOrder,
    );
    final normalizedQuery = query.trim().toLowerCase();
    final matches = <String>{
      if (normalizedQuery.isNotEmpty)
        for (final note in visibleNotes)
          if (_matches(note, normalizedQuery)) note.id,
    };
    final visibleNotesById = <String, Note>{
      for (final note in visibleNotes) note.id: note,
    };
    final noteTypes = allNotes.map((note) => note.noteType).toSet().toList()
      ..sort((left, right) => noteTypeLabel(left).compareTo(noteTypeLabel(right)));
    final tags = allNotes.expand((note) => note.tags).toSet().toList()
      ..sort((left, right) => left.toLowerCase().compareTo(right.toLowerCase()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Карта знаний'),
        actions: [
          IconButton(
            tooltip: 'Структура графа',
            onPressed: () => _showInsights(
              context,
              analysis: analysis,
              notesById: allNotesById,
              projects: projects,
            ),
            icon: const Icon(Icons.analytics_outlined),
          ),
          IconButton(
            tooltip: 'Сбросить масштаб и положение',
            onPressed: _resetView,
            icon: const Icon(Icons.center_focus_strong_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _GraphControls(
            projects: projects,
            noteTypes: noteTypes,
            tags: tags,
            projectFilter: projectFilter,
            noteTypeFilter: noteTypeFilter,
            tagFilter: tagFilter,
            connectedOnly: connectedOnly,
            showDirections: showDirections,
            focusMode: focusMode,
            focusDepth: focusDepth,
            selectedNote: selectedNote,
            onQueryChanged: (value) => setState(() => query = value),
            onQuerySubmitted: (value) {
              final normalized = value.trim().toLowerCase();
              if (normalized.isEmpty) {
                return;
              }
              for (final note in visibleNotes) {
                if (_matches(note, normalized)) {
                  setState(() => selectedNoteId = note.id);
                  return;
                }
              }
            },
            onProjectChanged: (value) => _changeFilters(
              project: value,
              updateProject: true,
            ),
            onNoteTypeChanged: (value) => _changeFilters(
              noteType: value,
              updateNoteType: true,
            ),
            onTagChanged: (value) => _changeFilters(
              tag: value,
              updateTag: true,
            ),
            onConnectedOnlyChanged: (value) {
              setState(() {
                connectedOnly = value;
                focusMode = false;
                selectedNoteId = null;
              });
              _resetView();
            },
            onDirectionsChanged: (value) {
              setState(() => showDirections = value);
            },
            onFocusDepthChanged: (value) {
              setState(() => focusDepth = value);
              _resetView();
            },
            onClearFocus: _clearFocus,
            noteCount: visibleNotes.length,
            linkCount: layout.edges.length,
            componentCount: visibleAnalysis.components.length,
            isolatedCount: visibleAnalysis.isolatedNoteIds.length,
            unresolvedCount: layout.unresolvedLinkCount,
            hiddenCount: layout.hiddenLinkCount,
          ),
          const Divider(height: 1),
          Expanded(
            child: visibleNotes.isEmpty
                ? const _EmptyGraph()
                : Stack(
                    children: [
                      Positioned.fill(
                        child: InteractiveViewer(
                          transformationController: _transformationController,
                          constrained: false,
                          minScale: 0.35,
                          maxScale: 2.4,
                          boundaryMargin: const EdgeInsets.all(240),
                          clipBehavior: Clip.none,
                          child: SizedBox(
                            width: layout.canvasSize.width,
                            height: layout.canvasSize.height,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                for (final cluster in layout.clusters)
                                  _clusterPlate(
                                    context,
                                    cluster,
                                    projects,
                                  ),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: ValueListenableBuilder<String?>(
                                      valueListenable: _hoveredNoteId,
                                      builder: (context, hoveredNoteId, _) {
                                        return CustomPaint(
                                          painter: _NoteGraphEdgePainter(
                                            layout: layout,
                                            baseColor: Theme.of(context)
                                                .colorScheme
                                                .outlineVariant,
                                            activeColor: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            hoveredNoteId: hoveredNoteId,
                                            selectedNoteId: selectedNoteId,
                                            showDirections: showDirections,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                for (final entry in layout.nodeBounds.entries)
                                  Positioned.fromRect(
                                    rect: entry.value,
                                    child: _NoteGraphNode(
                                      note: visibleNotesById[entry.key]!,
                                      project: widget.store.projectById(
                                        visibleNotesById[entry.key]!.projectId,
                                      ),
                                      degree: analysis.degrees[entry.key] ??
                                          const NoteGraphDegree(
                                            incoming: 0,
                                            outgoing: 0,
                                          ),
                                      highlighted: normalizedQuery.isNotEmpty &&
                                          matches.contains(entry.key),
                                      selected: selectedNoteId == entry.key,
                                      dimmed: selectedNoteId != null &&
                                          selectedNoteId != entry.key &&
                                          !(analysis.neighbors[selectedNoteId!] ??
                                                  const <String>{})
                                              .contains(entry.key),
                                      onHoverChanged: (hovered) {
                                        if (hovered) {
                                          _hoveredNoteId.value = entry.key;
                                        } else if (_hoveredNoteId.value ==
                                            entry.key) {
                                          _hoveredNoteId.value = null;
                                        }
                                      },
                                      onSelect: () => setState(
                                        () => selectedNoteId = entry.key,
                                      ),
                                      onOpen: () => _open(
                                        visibleNotesById[entry.key]!,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (normalizedQuery.isNotEmpty)
                        Positioned(
                          left: 16,
                          bottom: 16,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Text(
                                matches.isEmpty
                                    ? 'Совпадений нет'
                                    : 'Подсвечено: ${matches.length}',
                              ),
                            ),
                          ),
                        ),
                      if (selectedNote != null)
                        Positioned(
                          top: 16,
                          right: 16,
                          bottom: 16,
                          width: 330,
                          child: _GraphSelectionPanel(
                            note: selectedNote,
                            project: widget.store.projectById(
                              selectedNote.projectId,
                            ),
                            degree: analysis.degrees[selectedNote.id] ??
                                const NoteGraphDegree(
                                  incoming: 0,
                                  outgoing: 0,
                                ),
                            neighbors: _neighborNotes(
                              selectedNote.id,
                              analysis,
                              allNotesById,
                            ),
                            focusMode: focusMode,
                            focusDepth: focusDepth,
                            onClose: () => setState(
                              () => selectedNoteId = null,
                            ),
                            onOpen: () => _open(selectedNote),
                            onFocus: (depth) => _focusOn(
                              selectedNote.id,
                              depth: depth,
                            ),
                            onSelectNeighbor: (note) => setState(
                              () => selectedNoteId = note.id,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _clusterPlate(
    BuildContext context,
    NoteGraphClusterLayout cluster,
    List<Project> projects,
  ) {
    Project? project;
    for (final candidate in projects) {
      if (candidate.id == cluster.projectId) {
        project = candidate;
        break;
      }
    }
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned.fromRect(
      rect: cluster.bounds,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 17, 24, 0),
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(
              '${project?.emoji ?? '📁'} '
              '${project?.title ?? 'Без проекта'} · ${cluster.noteCount}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _matches(Note note, String normalizedQuery) {
    return note.title.toLowerCase().contains(normalizedQuery) ||
        note.folderPath.toLowerCase().contains(normalizedQuery) ||
        noteTypeLabel(note.noteType).toLowerCase().contains(normalizedQuery) ||
        note.tags.any((tag) => tag.toLowerCase().contains(normalizedQuery));
  }

  List<Note> _neighborNotes(
    String noteId,
    NoteGraphAnalysis analysis,
    Map<String, Note> notesById,
  ) {
    final result = <Note>[
      for (final id in analysis.neighbors[noteId] ?? const <String>{})
        if (notesById[id] != null) notesById[id]!,
    ];
    result.sort((left, right) {
      final byDegree = (analysis.degrees[right.id]?.total ?? 0).compareTo(
        analysis.degrees[left.id]?.total ?? 0,
      );
      if (byDegree != 0) {
        return byDegree;
      }
      return left.title.toLowerCase().compareTo(right.title.toLowerCase());
    });
    return result;
  }

  Future<void> _open(Note note) async {
    await widget.onOpenNote(note);
    if (mounted) {
      setState(() {});
    }
  }

  void _changeFilters({
    String? project,
    String? noteType,
    String? tag,
    bool updateProject = false,
    bool updateNoteType = false,
    bool updateTag = false,
  }) {
    setState(() {
      if (updateProject) {
        projectFilter = project;
      }
      if (updateNoteType) {
        noteTypeFilter = noteType;
      }
      if (updateTag) {
        tagFilter = tag;
      }
      focusMode = false;
      selectedNoteId = null;
      _hoveredNoteId.value = null;
    });
    _resetView();
  }

  void _focusOn(String noteId, {required int depth}) {
    setState(() {
      selectedNoteId = noteId;
      focusMode = true;
      focusDepth = depth;
      projectFilter = null;
      noteTypeFilter = null;
      tagFilter = null;
      connectedOnly = false;
    });
    _resetView();
  }

  void _clearFocus() {
    setState(() => focusMode = false);
    _resetView();
  }

  void _resetView() {
    _transformationController.value = Matrix4.identity();
  }

  Future<void> _showInsights(
    BuildContext context, {
    required NoteGraphAnalysis analysis,
    required Map<String, Note> notesById,
    required List<Project> projects,
  }) async {
    final projectById = <String, Project>{
      for (final project in projects) project.id: project,
    };
    final hubs = <Note>[
      for (final id in analysis.hubNoteIds(limit: 10))
        if (notesById[id] != null) notesById[id]!,
    ];
    final isolated = <Note>[
      for (final id in analysis.isolatedNoteIds)
        if (notesById[id] != null) notesById[id]!,
    ]..sort(
        (left, right) => left.title.toLowerCase().compareTo(
          right.title.toLowerCase(),
        ),
      );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Структура карты знаний'),
        content: SizedBox(
          width: 620,
          child: ListView(
            shrinkWrap: true,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _GraphMetric(
                    icon: Icons.account_tree_outlined,
                    label: '${analysis.components.length} компонентов',
                  ),
                  _GraphMetric(
                    icon: Icons.hub_outlined,
                    label: '${analysis.resolvedEdgeCount} связей',
                  ),
                  _GraphMetric(
                    icon: Icons.radio_button_unchecked,
                    label: '${analysis.isolatedNoteIds.length} изолированных',
                  ),
                  if (analysis.unresolvedLinkCount > 0)
                    _GraphMetric(
                      icon: Icons.link_off_rounded,
                      label: '${analysis.unresolvedLinkCount} без цели',
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text('Наиболее связанные',
                  style: Theme.of(dialogContext).textTheme.titleMedium),
              const SizedBox(height: 6),
              if (hubs.isEmpty)
                const Text('В графе пока нет связей.')
              else
                for (final note in hubs)
                  ListTile(
                    dense: true,
                    leading: Text(
                      projectById[note.projectId]?.emoji ?? '📄',
                      style: const TextStyle(fontSize: 20),
                    ),
                    title: Text(note.title),
                    subtitle: Text(
                      '${noteTypeLabel(note.noteType)} · '
                      '${analysis.degrees[note.id]?.total ?? 0} связей',
                    ),
                    onTap: () {
                      Navigator.of(dialogContext).pop();
                      setState(() => selectedNoteId = note.id);
                    },
                  ),
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('Изолированные заметки · ${isolated.length}'),
                children: [
                  if (isolated.isEmpty)
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Все заметки участвуют в связях.'),
                    )
                  else
                    for (final note in isolated.take(30))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(note.title),
                        subtitle: Text(
                          projectById[note.projectId]?.title ?? 'Без проекта',
                        ),
                        onTap: () {
                          Navigator.of(dialogContext).pop();
                          setState(() => selectedNoteId = note.id);
                        },
                      ),
                  if (isolated.length > 30)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Ещё ${isolated.length - 30} заметок'),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
}

class _GraphControls extends StatelessWidget {
  const _GraphControls({
    required this.projects,
    required this.noteTypes,
    required this.tags,
    required this.projectFilter,
    required this.noteTypeFilter,
    required this.tagFilter,
    required this.connectedOnly,
    required this.showDirections,
    required this.focusMode,
    required this.focusDepth,
    required this.selectedNote,
    required this.onQueryChanged,
    required this.onQuerySubmitted,
    required this.onProjectChanged,
    required this.onNoteTypeChanged,
    required this.onTagChanged,
    required this.onConnectedOnlyChanged,
    required this.onDirectionsChanged,
    required this.onFocusDepthChanged,
    required this.onClearFocus,
    required this.noteCount,
    required this.linkCount,
    required this.componentCount,
    required this.isolatedCount,
    required this.unresolvedCount,
    required this.hiddenCount,
  });

  final List<Project> projects;
  final List<String> noteTypes;
  final List<String> tags;
  final String? projectFilter;
  final String? noteTypeFilter;
  final String? tagFilter;
  final bool connectedOnly;
  final bool showDirections;
  final bool focusMode;
  final int focusDepth;
  final Note? selectedNote;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onQuerySubmitted;
  final ValueChanged<String?> onProjectChanged;
  final ValueChanged<String?> onNoteTypeChanged;
  final ValueChanged<String?> onTagChanged;
  final ValueChanged<bool> onConnectedOnlyChanged;
  final ValueChanged<bool> onDirectionsChanged;
  final ValueChanged<int> onFocusDepthChanged;
  final VoidCallback onClearFocus;
  final int noteCount;
  final int linkCount;
  final int componentCount;
  final int isolatedCount;
  final int unresolvedCount;
  final int hiddenCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final controlWidth = constraints.maxWidth < 320
              ? constraints.maxWidth
              : 270.0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: controlWidth + 40,
                    child: SearchBar(
                      hintText: 'Название, тег, тип или папка',
                      leading: const Icon(Icons.search_rounded),
                      onChanged: onQueryChanged,
                      onSubmitted: onQuerySubmitted,
                    ),
                  ),
                  if (!focusMode) ...[
                    _GraphDropdown<String?>(
                      width: controlWidth,
                      value: projectFilter,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Все проекты'),
                        ),
                        for (final project in projects)
                          DropdownMenuItem<String?>(
                            value: project.id,
                            child: Text(
                              '${project.emoji} ${project.title}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: onProjectChanged,
                    ),
                    _GraphDropdown<String?>(
                      width: controlWidth,
                      value: noteTypeFilter,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Все типы заметок'),
                        ),
                        for (final type in noteTypes)
                          DropdownMenuItem<String?>(
                            value: type,
                            child: Text(
                              '${noteTypeIcon(type)} ${noteTypeLabel(type)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: onNoteTypeChanged,
                    ),
                    _GraphDropdown<String?>(
                      width: controlWidth,
                      value: tagFilter,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Все теги'),
                        ),
                        for (final tag in tags.take(120))
                          DropdownMenuItem<String?>(
                            value: tag,
                            child: Text(
                              '#$tag',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: onTagChanged,
                    ),
                    FilterChip(
                      selected: connectedOnly,
                      onSelected: onConnectedOnlyChanged,
                      avatar: const Icon(Icons.hub_outlined, size: 17),
                      label: const Text('Только связанные'),
                    ),
                  ] else ...[
                    Chip(
                      avatar: const Icon(Icons.center_focus_strong, size: 17),
                      label: Text(
                        'Фокус: ${selectedNote?.title ?? 'заметка'}',
                        overflow: TextOverflow.ellipsis,
                      ),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: onClearFocus,
                    ),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment<int>(value: 1, label: Text('1 шаг')),
                        ButtonSegment<int>(value: 2, label: Text('2 шага')),
                      ],
                      selected: <int>{focusDepth},
                      onSelectionChanged: (selection) {
                        onFocusDepthChanged(selection.first);
                      },
                    ),
                  ],
                  FilterChip(
                    selected: showDirections,
                    onSelected: onDirectionsChanged,
                    avatar: const Icon(Icons.trending_flat_rounded, size: 17),
                    label: const Text('Направления'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _GraphMetric(
                    icon: Icons.description_outlined,
                    label: '$noteCount заметок',
                  ),
                  _GraphMetric(
                    icon: Icons.hub_outlined,
                    label: '$linkCount связей',
                  ),
                  _GraphMetric(
                    icon: Icons.account_tree_outlined,
                    label: '$componentCount компонентов',
                  ),
                  if (isolatedCount > 0)
                    _GraphMetric(
                      icon: Icons.radio_button_unchecked,
                      label: '$isolatedCount изолированных',
                    ),
                  if (unresolvedCount > 0)
                    _GraphMetric(
                      icon: Icons.link_off_rounded,
                      label: '$unresolvedCount без цели',
                    ),
                  if (hiddenCount > 0)
                    _GraphMetric(
                      icon: Icons.visibility_off_outlined,
                      label: '$hiddenCount внешних',
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GraphDropdown<T> extends StatelessWidget {
  const _GraphDropdown({
    required this.width,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final double width;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InputDecorator(
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _NoteGraphNode extends StatefulWidget {
  const _NoteGraphNode({
    required this.note,
    required this.project,
    required this.degree,
    required this.highlighted,
    required this.selected,
    required this.dimmed,
    required this.onHoverChanged,
    required this.onSelect,
    required this.onOpen,
  });

  final Note note;
  final Project? project;
  final NoteGraphDegree degree;
  final bool highlighted;
  final bool selected;
  final bool dimmed;
  final ValueChanged<bool> onHoverChanged;
  final VoidCallback onSelect;
  final VoidCallback onOpen;

  @override
  State<_NoteGraphNode> createState() => _NoteGraphNodeState();
}

class _NoteGraphNodeState extends State<_NoteGraphNode> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final emphasized = widget.highlighted || _hovered || widget.selected;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 140),
      opacity: widget.dimmed ? 0.42 : 1,
      child: MouseRegion(
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: Tooltip(
          message: 'Щелчок — выбрать · двойной щелчок — открыть',
          child: Material(
            elevation: emphasized ? 5 : 1,
            color: emphasized
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: emphasized
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
                width: emphasized ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onSelect,
              onDoubleTap: widget.onOpen,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                child: Row(
                  children: [
                    Text(
                      noteTypeIcon(widget.note.noteType),
                      style: const TextStyle(fontSize: 22),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.note.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          if (widget.note.tags.isNotEmpty)
                            Text(
                              '#${widget.note.tags.take(2).join('  #')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                        ],
                      ),
                    ),
                    if (widget.degree.total > 0) ...[
                      const SizedBox(width: 6),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.link_rounded, size: 16),
                          Text(
                            '${widget.degree.total}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _setHovered(bool value) {
    if (_hovered == value) {
      return;
    }
    setState(() => _hovered = value);
    widget.onHoverChanged(value);
  }
}

class _GraphSelectionPanel extends StatelessWidget {
  const _GraphSelectionPanel({
    required this.note,
    required this.project,
    required this.degree,
    required this.neighbors,
    required this.focusMode,
    required this.focusDepth,
    required this.onClose,
    required this.onOpen,
    required this.onFocus,
    required this.onSelectNeighbor,
  });

  final Note note;
  final Project? project;
  final NoteGraphDegree degree;
  final List<Note> neighbors;
  final bool focusMode;
  final int focusDepth;
  final VoidCallback onClose;
  final VoidCallback onOpen;
  final ValueChanged<int> onFocus;
  final ValueChanged<Note> onSelectNeighbor;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
            child: Row(
              children: [
                Text(noteTypeIcon(note.noteType),
                    style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    note.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'Закрыть карточку',
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Chip(
                  avatar: Text(project?.emoji ?? '📁'),
                  label: Text(project?.title ?? 'Без проекта'),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(noteTypeLabel(note.noteType)),
                  visualDensity: VisualDensity.compact,
                ),
                if (note.folderPath.trim().isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.folder_outlined, size: 16),
                    label: Text(note.folderPath),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
            child: Row(
              children: [
                Expanded(
                  child: _DegreeTile(
                    label: 'Исходящих',
                    value: degree.outgoing,
                    icon: Icons.call_made_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DegreeTile(
                    label: 'Входящих',
                    value: degree.incoming,
                    icon: Icons.call_received_rounded,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Открыть заметку'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onFocus(1),
                    child: Text(focusMode && focusDepth == 1
                        ? 'Фокус: 1 шаг'
                        : 'Показать 1 шаг'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onFocus(2),
                    child: Text(focusMode && focusDepth == 2
                        ? 'Фокус: 2 шага'
                        : 'Показать 2 шага'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              'Соседние заметки · ${neighbors.length}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: neighbors.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'У этой заметки пока нет связей.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    itemCount: neighbors.length,
                    itemBuilder: (context, index) {
                      final neighbor = neighbors[index];
                      return ListTile(
                        dense: true,
                        leading: Text(noteTypeIcon(neighbor.noteType)),
                        title: Text(
                          neighbor.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(noteTypeLabel(neighbor.noteType)),
                        onTap: () => onSelectNeighbor(neighbor),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DegreeTile extends StatelessWidget {
  const _DegreeTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$value',
                      style: Theme.of(context).textTheme.titleSmall),
                  Text(label, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GraphMetric extends StatelessWidget {
  const _GraphMetric({required this.icon, required this.label});

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

class _EmptyGraph extends StatelessWidget {
  const _EmptyGraph();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hub_outlined,
              size: 58,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              'По выбранным фильтрам заметок нет',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteGraphEdgePainter extends CustomPainter {
  const _NoteGraphEdgePainter({
    required this.layout,
    required this.baseColor,
    required this.activeColor,
    required this.hoveredNoteId,
    required this.selectedNoteId,
    required this.showDirections,
  });

  final NoteGraphLayout layout;
  final Color baseColor;
  final Color activeColor;
  final String? hoveredNoteId;
  final String? selectedNoteId;
  final bool showDirections;

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()
      ..color = baseColor.withValues(alpha: 0.72)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final activePaint = Paint()
      ..color = activeColor.withValues(alpha: 0.94)
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke;

    for (final edge in layout.edges) {
      final source = layout.nodeBounds[edge.sourceNoteId];
      final target = layout.nodeBounds[edge.targetNoteId];
      if (source == null || target == null) {
        continue;
      }
      final active = _isActive(edge, hoveredNoteId) ||
          _isActive(edge, selectedNoteId);
      final paint = active ? activePaint : basePaint;
      final start = _rectBoundaryPoint(source, target.center);
      final end = _rectBoundaryPoint(target, source.center);
      canvas.drawLine(start, end, paint);
      if (showDirections) {
        _drawArrow(canvas, start, end, paint);
      }
    }
  }

  bool _isActive(NoteGraphEdgeLayout edge, String? noteId) {
    return noteId != null &&
        (edge.sourceNoteId == noteId || edge.targetNoteId == noteId);
  }

  Offset _rectBoundaryPoint(Rect rect, Offset toward) {
    final delta = toward - rect.center;
    if (delta.distanceSquared == 0) {
      return rect.center;
    }
    final xScale = delta.dx == 0
        ? double.infinity
        : rect.width / 2 / delta.dx.abs();
    final yScale = delta.dy == 0
        ? double.infinity
        : rect.height / 2 / delta.dy.abs();
    final scale = math.min(xScale, yScale);
    return rect.center + delta * scale;
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    final delta = end - start;
    if (delta.distanceSquared < 144) {
      return;
    }
    final angle = math.atan2(delta.dy, delta.dx);
    const arrowLength = 10.0;
    const arrowSpread = 0.52;
    final first = Offset(
      end.dx - arrowLength * math.cos(angle - arrowSpread),
      end.dy - arrowLength * math.sin(angle - arrowSpread),
    );
    final second = Offset(
      end.dx - arrowLength * math.cos(angle + arrowSpread),
      end.dy - arrowLength * math.sin(angle + arrowSpread),
    );
    final path = Path()
      ..moveTo(first.dx, first.dy)
      ..lineTo(end.dx, end.dy)
      ..lineTo(second.dx, second.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _NoteGraphEdgePainter oldDelegate) {
    return oldDelegate.layout != layout ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.hoveredNoteId != hoveredNoteId ||
        oldDelegate.selectedNoteId != selectedNoteId ||
        oldDelegate.showDirections != showDirections;
  }
}
