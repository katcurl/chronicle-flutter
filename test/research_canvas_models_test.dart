import 'package:chronicle/features/notes/research_canvas_models.dart';
import 'package:chronicle/features/notes/research_canvas_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ResearchCanvasItem noteItem(String id, String noteId) {
    return ResearchCanvasItem.normalized(
      id: id,
      type: ResearchCanvasItemType.note,
      noteId: noteId,
      title: 'Note $noteId',
      x: 120,
      y: 140,
      width: 290,
      height: 180,
      colorValue: 0xFF6750A4,
    );
  }

  test('research canvases survive JSON round trip', () {
    final source = ResearchCanvasPreferences.normalized(
      activeCanvasId: 'canvas',
      canvases: <ResearchCanvas>[
        ResearchCanvas.normalized(
          id: 'canvas',
          name: 'ORF9b map',
          emoji: '🧬',
          projectId: 'project',
          items: <ResearchCanvasItem>[
            noteItem('a', 'note-a'),
            ResearchCanvasItem.normalized(
              id: 'b',
              type: ResearchCanvasItemType.text,
              title: 'Hypothesis',
              body: 'The beta core has two metastable states.',
              x: 480,
              y: 140,
              width: 300,
              height: 190,
              colorValue: 0xFF006A6A,
            ),
          ],
          connections: const <ResearchCanvasConnection>[
            ResearchCanvasConnection(
              id: 'edge',
              sourceItemId: 'a',
              targetItemId: 'b',
            ),
          ],
        ),
      ],
    );

    final decoded = ResearchCanvasStore.decode(
      ResearchCanvasStore.encode(source),
    );

    expect(decoded.activeCanvas.name, 'ORF9b map');
    expect(decoded.activeCanvas.projectId, 'project');
    expect(decoded.activeCanvas.items, hasLength(2));
    expect(decoded.activeCanvas.connections, hasLength(1));
    expect(decoded.activeCanvas.items.last.body, contains('metastable'));
  });

  test('normalization drops broken and duplicate connections', () {
    final canvas = ResearchCanvas.normalized(
      id: 'canvas',
      name: 'Canvas',
      emoji: 'C',
      items: <ResearchCanvasItem>[
        noteItem('a', 'note-a'),
        noteItem('b', 'note-b'),
      ],
      connections: const <ResearchCanvasConnection>[
        ResearchCanvasConnection(
          id: 'one',
          sourceItemId: 'a',
          targetItemId: 'b',
        ),
        ResearchCanvasConnection(
          id: 'duplicate',
          sourceItemId: 'a',
          targetItemId: 'b',
        ),
        ResearchCanvasConnection(
          id: 'missing',
          sourceItemId: 'a',
          targetItemId: 'missing',
        ),
      ],
    );

    expect(canvas.connections, hasLength(1));
    expect(canvas.connections.single.id, 'one');
  });

  test('item geometry is clamped to the safe canvas bounds', () {
    final item = ResearchCanvasItem.normalized(
      id: 'item',
      type: ResearchCanvasItemType.text,
      title: 'Card',
      x: -500,
      y: 9000,
      width: 20,
      height: 5000,
      colorValue: 0xFF6750A4,
    );

    expect(item.x, ResearchCanvasItem.minX);
    expect(item.y, lessThanOrEqualTo(ResearchCanvasItem.maxY - item.height));
    expect(item.width, ResearchCanvasItem.minWidth);
    expect(item.height, ResearchCanvasItem.maxHeight);
  });

  test('duplicating a canvas remaps item and connection ids', () {
    final source = ResearchCanvas.normalized(
      id: 'source',
      name: 'Map',
      emoji: 'M',
      items: <ResearchCanvasItem>[
        noteItem('a', 'note-a'),
        noteItem('b', 'note-b'),
      ],
      connections: const <ResearchCanvasConnection>[
        ResearchCanvasConnection(
          id: 'edge',
          sourceItemId: 'a',
          targetItemId: 'b',
        ),
      ],
    );

    final copy = source.duplicate(newId: 'copy');

    expect(copy.id, 'copy');
    expect(copy.name, startsWith('Копия'));
    expect(copy.items.map((item) => item.id).toSet(), isNot(contains('a')));
    expect(copy.connections.single.id, isNot('edge'));
    expect(
      copy.items.map((item) => item.id),
      contains(copy.connections.single.sourceItemId),
    );
    expect(
      copy.items.map((item) => item.id),
      contains(copy.connections.single.targetItemId),
    );
  });

  test('malformed stored JSON falls back to a usable default canvas', () {
    final decoded = ResearchCanvasStore.decode('{broken json');

    expect(decoded.canvases, hasLength(1));
    expect(decoded.activeCanvas.name, 'Исследование');
  });
}
