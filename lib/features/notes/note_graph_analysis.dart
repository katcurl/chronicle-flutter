import '../../models/app_models.dart';

class NoteGraphDegree {
  const NoteGraphDegree({required this.incoming, required this.outgoing});

  final int incoming;
  final int outgoing;

  int get total => incoming + outgoing;
}

class NoteGraphAnalysis {
  const NoteGraphAnalysis({
    required this.degrees,
    required this.neighbors,
    required this.components,
    required this.isolatedNoteIds,
    required this.resolvedEdgeCount,
    required this.unresolvedLinkCount,
  });

  final Map<String, NoteGraphDegree> degrees;
  final Map<String, Set<String>> neighbors;
  final List<Set<String>> components;
  final Set<String> isolatedNoteIds;
  final int resolvedEdgeCount;
  final int unresolvedLinkCount;

  static NoteGraphAnalysis build({
    required List<Note> notes,
    required List<NoteLink> links,
  }) {
    final notesById = <String, Note>{for (final note in notes) note.id: note};
    final incoming = <String, Set<String>>{
      for (final note in notes) note.id: <String>{},
    };
    final outgoing = <String, Set<String>>{
      for (final note in notes) note.id: <String>{},
    };
    final neighbors = <String, Set<String>>{
      for (final note in notes) note.id: <String>{},
    };
    final edgeKeys = <String>{};
    var unresolved = 0;

    for (final link in links) {
      if (!notesById.containsKey(link.sourceNoteId)) {
        continue;
      }
      final targetId = link.targetNoteId;
      if (targetId == null || !notesById.containsKey(targetId)) {
        unresolved += 1;
        continue;
      }
      if (targetId == link.sourceNoteId) {
        continue;
      }
      final edgeKey = '${link.sourceNoteId}\u0000$targetId';
      if (!edgeKeys.add(edgeKey)) {
        continue;
      }
      outgoing[link.sourceNoteId]!.add(targetId);
      incoming[targetId]!.add(link.sourceNoteId);
      neighbors[link.sourceNoteId]!.add(targetId);
      neighbors[targetId]!.add(link.sourceNoteId);
    }

    final degrees = <String, NoteGraphDegree>{
      for (final note in notes)
        note.id: NoteGraphDegree(
          incoming: incoming[note.id]!.length,
          outgoing: outgoing[note.id]!.length,
        ),
    };
    final isolated = <String>{
      for (final note in notes)
        if (neighbors[note.id]!.isEmpty) note.id,
    };
    final components = _components(
      noteIds: notesById.keys,
      neighbors: neighbors,
    );

    return NoteGraphAnalysis(
      degrees: Map<String, NoteGraphDegree>.unmodifiable(degrees),
      neighbors: Map<String, Set<String>>.unmodifiable({
        for (final entry in neighbors.entries)
          entry.key: Set<String>.unmodifiable(entry.value),
      }),
      components: List<Set<String>>.unmodifiable(
        components.map((component) => Set<String>.unmodifiable(component)),
      ),
      isolatedNoteIds: Set<String>.unmodifiable(isolated),
      resolvedEdgeCount: edgeKeys.length,
      unresolvedLinkCount: unresolved,
    );
  }

  Set<String> neighborhood(String noteId, {int depth = 1}) {
    if (!neighbors.containsKey(noteId)) {
      return const <String>{};
    }
    final boundedDepth = depth.clamp(0, 4);
    final visited = <String>{noteId};
    var frontier = <String>{noteId};
    for (var step = 0; step < boundedDepth; step += 1) {
      final next = <String>{};
      for (final current in frontier) {
        for (final neighbor in neighbors[current] ?? const <String>{}) {
          if (visited.add(neighbor)) {
            next.add(neighbor);
          }
        }
      }
      if (next.isEmpty) {
        break;
      }
      frontier = next;
    }
    return Set<String>.unmodifiable(visited);
  }

  List<String> shortestPath(String sourceNoteId, String targetNoteId) {
    if (!neighbors.containsKey(sourceNoteId) ||
        !neighbors.containsKey(targetNoteId)) {
      return const <String>[];
    }
    if (sourceNoteId == targetNoteId) {
      return <String>[sourceNoteId];
    }

    final queue = <String>[sourceNoteId];
    final previous = <String, String?>{sourceNoteId: null};
    var cursor = 0;
    while (cursor < queue.length) {
      final current = queue[cursor];
      cursor += 1;
      for (final neighbor in neighbors[current] ?? const <String>{}) {
        if (previous.containsKey(neighbor)) {
          continue;
        }
        previous[neighbor] = current;
        if (neighbor == targetNoteId) {
          final path = <String>[targetNoteId];
          String? step = current;
          while (step != null) {
            path.add(step);
            step = previous[step];
          }
          return path.reversed.toList(growable: false);
        }
        queue.add(neighbor);
      }
    }
    return const <String>[];
  }

  List<String> hubNoteIds({int limit = 8}) {
    final ids = degrees.keys.toList(growable: false)..sort((left, right) {
      final byDegree = degrees[right]!.total.compareTo(degrees[left]!.total);
      if (byDegree != 0) {
        return byDegree;
      }
      return left.compareTo(right);
    });
    return ids
        .where((id) => degrees[id]!.total > 0)
        .take(limit)
        .toList(growable: false);
  }

  static List<Set<String>> _components({
    required Iterable<String> noteIds,
    required Map<String, Set<String>> neighbors,
  }) {
    final remaining = noteIds.toSet();
    final components = <Set<String>>[];
    while (remaining.isNotEmpty) {
      final seed = remaining.first;
      final component = <String>{seed};
      final queue = <String>[seed];
      remaining.remove(seed);
      var cursor = 0;
      while (cursor < queue.length) {
        final current = queue[cursor];
        cursor += 1;
        for (final neighbor in neighbors[current] ?? const <String>{}) {
          if (remaining.remove(neighbor)) {
            component.add(neighbor);
            queue.add(neighbor);
          }
        }
      }
      components.add(component);
    }
    components.sort((left, right) {
      final bySize = right.length.compareTo(left.length);
      if (bySize != 0) {
        return bySize;
      }
      return left.first.compareTo(right.first);
    });
    return components;
  }
}
