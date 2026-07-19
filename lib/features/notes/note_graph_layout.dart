import 'dart:math' as math;
import 'dart:ui';

import '../../models/app_models.dart';

class NoteGraphEdgeLayout {
  const NoteGraphEdgeLayout({
    required this.sourceNoteId,
    required this.targetNoteId,
  });

  final String sourceNoteId;
  final String targetNoteId;
}

class NoteGraphClusterLayout {
  const NoteGraphClusterLayout({
    required this.projectId,
    required this.bounds,
    required this.noteCount,
  });

  final String projectId;
  final Rect bounds;
  final int noteCount;
}

class NoteGraphLayout {
  const NoteGraphLayout({
    required this.canvasSize,
    required this.nodeBounds,
    required this.clusters,
    required this.edges,
    required this.unresolvedLinkCount,
    required this.hiddenLinkCount,
  });

  final Size canvasSize;
  final Map<String, Rect> nodeBounds;
  final List<NoteGraphClusterLayout> clusters;
  final List<NoteGraphEdgeLayout> edges;
  final int unresolvedLinkCount;
  final int hiddenLinkCount;
}

class NoteGraphLayoutEngine {
  const NoteGraphLayoutEngine._();

  static const double _outerMargin = 80;
  static const double _clusterWidth = 500;
  static const double _clusterGap = 70;
  static const double _clusterPadding = 26;
  static const double _clusterHeaderHeight = 58;
  static const double _nodeHeight = 68;
  static const double _nodeGap = 18;

  static NoteGraphLayout build({
    required List<Note> allNotes,
    required List<Note> visibleNotes,
    required List<NoteLink> links,
    required List<String> projectOrder,
  }) {
    if (visibleNotes.isEmpty) {
      return const NoteGraphLayout(
        canvasSize: Size(900, 620),
        nodeBounds: <String, Rect>{},
        clusters: <NoteGraphClusterLayout>[],
        edges: <NoteGraphEdgeLayout>[],
        unresolvedLinkCount: 0,
        hiddenLinkCount: 0,
      );
    }

    final notesByProject = <String, List<Note>>{};
    for (final note in visibleNotes) {
      notesByProject.putIfAbsent(note.projectId, () => <Note>[]).add(note);
    }
    for (final notes in notesByProject.values) {
      notes.sort(
        (left, right) => left.title.toLowerCase().compareTo(
          right.title.toLowerCase(),
        ),
      );
    }

    final orderedProjects = <String>[
      for (final projectId in projectOrder)
        if (notesByProject.containsKey(projectId)) projectId,
      for (final projectId in notesByProject.keys)
        if (!projectOrder.contains(projectId)) projectId,
    ];

    final clusterColumns = math
        .min(
          3,
          math.max(1, math.sqrt(orderedProjects.length).ceil()),
        )
        .toInt();
    final columnBottoms = List<double>.filled(clusterColumns, _outerMargin);
    final nodeBounds = <String, Rect>{};
    final clusters = <NoteGraphClusterLayout>[];

    for (var clusterIndex = 0;
        clusterIndex < orderedProjects.length;
        clusterIndex += 1) {
      final projectId = orderedProjects[clusterIndex];
      final projectNotes = notesByProject[projectId]!;
      final column = _shortestColumn(columnBottoms);
      final rows = (projectNotes.length / 2).ceil();
      final rowGaps = rows > 1 ? rows - 1 : 0;
      final clusterHeight =
          _clusterHeaderHeight +
          (_clusterPadding * 2) +
          (rows * _nodeHeight) +
          (rowGaps * _nodeGap);
      final left =
          _outerMargin + column * (_clusterWidth + _clusterGap);
      final top = columnBottoms[column];
      final clusterBounds = Rect.fromLTWH(
        left,
        top,
        _clusterWidth,
        clusterHeight,
      );
      clusters.add(
        NoteGraphClusterLayout(
          projectId: projectId,
          bounds: clusterBounds,
          noteCount: projectNotes.length,
        ),
      );

      final nodeWidth =
          (_clusterWidth - (_clusterPadding * 2) - _nodeGap) / 2;
      for (var index = 0; index < projectNotes.length; index += 1) {
        final row = index ~/ 2;
        final nodeColumn = index % 2;
        final nodeLeft =
            left + _clusterPadding + nodeColumn * (nodeWidth + _nodeGap);
        final nodeTop =
            top +
            _clusterHeaderHeight +
            _clusterPadding +
            row * (_nodeHeight + _nodeGap);
        nodeBounds[projectNotes[index].id] = Rect.fromLTWH(
          nodeLeft,
          nodeTop,
          nodeWidth,
          _nodeHeight,
        );
      }

      columnBottoms[column] = clusterBounds.bottom + _clusterGap;
    }

    final allById = <String, Note>{
      for (final note in allNotes) note.id: note,
    };
    final allByTitle = <String, Note>{};
    for (final note in allNotes) {
      allByTitle.putIfAbsent(_normalize(note.title), () => note);
    }
    final visibleIds = visibleNotes.map((note) => note.id).toSet();
    final edgeKeys = <String>{};
    final edges = <NoteGraphEdgeLayout>[];
    var unresolved = 0;
    var hidden = 0;

    for (final link in links) {
      if (!visibleIds.contains(link.sourceNoteId)) {
        continue;
      }
      final target =
          (link.targetNoteId == null ? null : allById[link.targetNoteId!]) ??
          allByTitle[_normalize(link.targetTitle)];
      if (target == null) {
        unresolved += 1;
        continue;
      }
      if (!visibleIds.contains(target.id)) {
        hidden += 1;
        continue;
      }
      if (target.id == link.sourceNoteId) {
        continue;
      }
      final key = '${link.sourceNoteId}\u0000${target.id}';
      if (!edgeKeys.add(key)) {
        continue;
      }
      edges.add(
        NoteGraphEdgeLayout(
          sourceNoteId: link.sourceNoteId,
          targetNoteId: target.id,
        ),
      );
    }

    final canvasWidth =
        (_outerMargin * 2) +
        (clusterColumns * _clusterWidth) +
        ((clusterColumns > 1 ? clusterColumns - 1 : 0) * _clusterGap);
    final lowestColumn = columnBottoms.reduce(
      (left, right) => left > right ? left : right,
    );
    final contentHeight = lowestColumn - _clusterGap + _outerMargin;
    final canvasHeight = contentHeight > 620.0 ? contentHeight : 620.0;

    return NoteGraphLayout(
      canvasSize: Size(canvasWidth, canvasHeight),
      nodeBounds: Map<String, Rect>.unmodifiable(nodeBounds),
      clusters: List<NoteGraphClusterLayout>.unmodifiable(clusters),
      edges: List<NoteGraphEdgeLayout>.unmodifiable(edges),
      unresolvedLinkCount: unresolved,
      hiddenLinkCount: hidden,
    );
  }

  static int _shortestColumn(List<double> bottoms) {
    var result = 0;
    for (var index = 1; index < bottoms.length; index += 1) {
      if (bottoms[index] < bottoms[result]) {
        result = index;
      }
    }
    return result;
  }

  static String _normalize(String value) => value.trim().toLowerCase();
}
