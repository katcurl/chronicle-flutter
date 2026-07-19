import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../services/app_store.dart';
import 'note_graph_layout.dart';

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

  @override
  void dispose() {
    _hoveredNoteId.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projects = List<Project>.from(widget.store.data.projects)
      ..sort(
        (left, right) => left.title.toLowerCase().compareTo(
          right.title.toLowerCase(),
        ),
      );
    final visibleNotes =
        widget.store.data.notes
            .where(
              (note) =>
                  projectFilter == null || note.projectId == projectFilter,
            )
            .toList(growable: false);
    final projectOrder = [
      for (final project in projects) project.id,
    ];
    final layout = NoteGraphLayoutEngine.build(
      allNotes: widget.store.data.notes,
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
    final notesById = <String, Note>{
      for (final note in visibleNotes) note.id: note,
    };
    final connectionCounts = <String, int>{
      for (final note in visibleNotes) note.id: 0,
    };
    for (final edge in layout.edges) {
      connectionCounts.update(
        edge.sourceNoteId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      connectionCounts.update(
        edge.targetNoteId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Карта знаний'),
        actions: [
          IconButton(
            tooltip: 'Сбросить масштаб и положение',
            onPressed: _resetView,
            icon: const Icon(Icons.center_focus_strong_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final controlWidth =
                    constraints.maxWidth < 320
                        ? constraints.maxWidth
                        : 320.0;
                return Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: controlWidth,
                      child: SearchBar(
                        hintText: 'Подсветить заметку, тег или папку',
                        leading: const Icon(Icons.search_rounded),
                        onChanged: (value) => setState(() => query = value),
                      ),
                    ),
                    SizedBox(
                      width: controlWidth,
                      child: DropdownButton<String?>(
                        value: projectFilter,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
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
                        onChanged:
                            (value) => setState(() {
                              projectFilter = value;
                              _hoveredNoteId.value = null;
                              _resetView();
                            }),
                      ),
                    ),
                    _GraphMetric(
                      icon: Icons.description_outlined,
                      label: '${visibleNotes.length} заметок',
                    ),
                    _GraphMetric(
                      icon: Icons.hub_outlined,
                      label: '${layout.edges.length} связей',
                    ),
                    if (layout.unresolvedLinkCount > 0)
                      _GraphMetric(
                        icon: Icons.link_off_rounded,
                        label: '${layout.unresolvedLinkCount} без цели',
                      ),
                    if (layout.hiddenLinkCount > 0)
                      _GraphMetric(
                        icon: Icons.visibility_off_outlined,
                        label: '${layout.hiddenLinkCount} внешних',
                      ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child:
                visibleNotes.isEmpty
                    ? const _EmptyGraph()
                    : Stack(
                      children: [
                        Positioned.fill(
                          child: InteractiveViewer(
                            transformationController:
                                _transformationController,
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
                                        builder: (context, activeNoteId, _) {
                                          return CustomPaint(
                                            painter: _NoteGraphEdgePainter(
                                              layout: layout,
                                              baseColor:
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .outlineVariant,
                                              activeColor:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                              activeNoteId: activeNoteId,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  for (final entry
                                      in layout.nodeBounds.entries)
                                    Positioned.fromRect(
                                      rect: entry.value,
                                      child: _NoteGraphNode(
                                        note: notesById[entry.key]!,
                                        project: widget.store.projectById(
                                          notesById[entry.key]!.projectId,
                                        ),
                                        connectionCount:
                                            connectionCounts[entry.key] ?? 0,
                                        highlighted:
                                            normalizedQuery.isNotEmpty &&
                                            matches.contains(entry.key),
                                        onHoverChanged:
                                            (hovered) {
                                              if (hovered) {
                                                _hoveredNoteId.value =
                                                    entry.key;
                                              } else if (_hoveredNoteId.value ==
                                                  entry.key) {
                                                _hoveredNoteId.value = null;
                                              }
                                            },
                                        onOpen:
                                            () => _open(
                                              notesById[entry.key]!,
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }

  bool _matches(Note note, String normalizedQuery) {
    return note.title.toLowerCase().contains(normalizedQuery) ||
        note.folderPath.toLowerCase().contains(normalizedQuery) ||
        note.tags.any(
          (tag) => tag.toLowerCase().contains(normalizedQuery),
        );
  }

  Future<void> _open(Note note) async {
    await widget.onOpenNote(note);
    if (mounted) {
      setState(() {});
    }
  }

  void _resetView() {
    _transformationController.value = Matrix4.identity();
  }
}

class _NoteGraphNode extends StatefulWidget {
  const _NoteGraphNode({
    required this.note,
    required this.project,
    required this.connectionCount,
    required this.highlighted,
    required this.onHoverChanged,
    required this.onOpen,
  });

  final Note note;
  final Project? project;
  final int connectionCount;
  final bool highlighted;
  final ValueChanged<bool> onHoverChanged;
  final VoidCallback onOpen;

  @override
  State<_NoteGraphNode> createState() => _NoteGraphNodeState();
}

class _NoteGraphNodeState extends State<_NoteGraphNode> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final emphasized = widget.highlighted || _hovered;
    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: Material(
        elevation: emphasized ? 5 : 1,
        color:
            emphasized
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color:
                emphasized ? colorScheme.primary : colorScheme.outlineVariant,
            width: emphasized ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            child: Row(
              children: [
                Text(
                  widget.project?.emoji ?? '📄',
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    widget.note.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (widget.connectionCount > 0) ...[
                  const SizedBox(width: 6),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.link_rounded, size: 16),
                      Text(
                        '${widget.connectionCount}',
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
              'В этом проекте пока нет заметок',
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
    required this.activeNoteId,
  });

  final NoteGraphLayout layout;
  final Color baseColor;
  final Color activeColor;
  final String? activeNoteId;

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint =
        Paint()
          ..color = baseColor.withValues(alpha: 0.72)
          ..strokeWidth = 1.4
          ..style = PaintingStyle.stroke;
    final activePaint =
        Paint()
          ..color = activeColor.withValues(alpha: 0.92)
          ..strokeWidth = 2.8
          ..style = PaintingStyle.stroke;

    for (final edge in layout.edges) {
      final source = layout.nodeBounds[edge.sourceNoteId];
      final target = layout.nodeBounds[edge.targetNoteId];
      if (source == null || target == null) {
        continue;
      }
      final active =
          activeNoteId != null &&
          (edge.sourceNoteId == activeNoteId ||
              edge.targetNoteId == activeNoteId);
      canvas.drawLine(
        source.center,
        target.center,
        active ? activePaint : basePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NoteGraphEdgePainter oldDelegate) {
    return oldDelegate.layout != layout ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.activeNoteId != activeNoteId;
  }
}
