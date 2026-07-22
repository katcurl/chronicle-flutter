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
    await tester.pumpAndSettle();

    final image = find.byType(Image).first;
    final initialWidth = tester.getSize(image).width;
    final resizeHandle = find.byIcon(Icons.drag_handle_rounded);

    expect(resizeHandle, findsOneWidget);
    await tester.drag(resizeHandle, Offset(-initialWidth / 2, 0));
    await tester.pumpAndSettle();

    expect(requestedPresentation?.widthPercent, 50);
    expect(tester.getSize(image).width, closeTo(initialWidth / 2, 1));
    expect(find.text('50%'), findsOneWidget);
  });
}
