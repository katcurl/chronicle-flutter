import 'package:chronicle/features/notes/note_image_syntax.dart';
import 'package:chronicle/features/notes/note_markdown_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('resize keeps the requested width while Markdown catches up', (
    tester,
  ) async {
    NoteImagePresentation? requestedPresentation;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: NoteMarkdownView(
              markdown:
                  '![pixel](data:image/png;base64,'
                  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
                  '+A8AAQUBAScY42YAAAAASUVORK5CYII= '
                  '"chronicle-image width=100 align=center")',
              onResizeImage: (_, presentation) {
                requestedPresentation = presentation;
              },
            ),
          ),
        ),
      ),
    );
    for (var attempt = 0; attempt < 20; attempt += 1) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
      if (find.byType(Image).evaluate().isNotEmpty) {
        break;
      }
    }

    final image = find.byType(Image).first;
    final initialWidth = tester.getSize(image).width;
    final resizeGesture = find.byWidgetPredicate(
      (widget) =>
          widget is GestureDetector &&
          widget.onHorizontalDragUpdate != null &&
          widget.onHorizontalDragEnd != null,
      description: 'image resize gesture detector',
    );

    expect(resizeGesture, findsOneWidget);
    final detector = tester.widget<GestureDetector>(resizeGesture);

    detector.onHorizontalDragUpdate!(
      DragUpdateDetails(
        globalPosition: Offset(initialWidth, 0),
        delta: Offset(-initialWidth / 2, 0),
        primaryDelta: -initialWidth / 2,
      ),
    );
    await tester.pump();

    expect(tester.getSize(image).width, closeTo(initialWidth / 2, 1));

    detector.onHorizontalDragEnd!(DragEndDetails());
    await tester.pumpAndSettle();

    expect(requestedPresentation?.widthPercent, 50);
    expect(tester.getSize(image).width, closeTo(initialWidth / 2, 1));
  });
}
