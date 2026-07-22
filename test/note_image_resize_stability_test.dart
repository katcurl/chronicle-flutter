import 'dart:ui';

import 'package:chronicle/features/notes/note_image_syntax.dart';
import 'package:chronicle/features/notes/note_markdown_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('quick resize keeps the requested width while Markdown catches up', (
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
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(image));
    await tester.pump();

    expect(find.text('100%'), findsOneWidget);
    await tester.tap(find.text('100%'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('50%').last);
    await tester.pumpAndSettle();

    expect(requestedPresentation?.widthPercent, 50);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('100%'), findsNothing);

    await mouse.removePointer();
  });
}
