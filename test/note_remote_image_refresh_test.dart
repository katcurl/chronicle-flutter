import 'dart:convert';
import 'dart:io';

import 'package:chronicle/features/notes/note_markdown_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('remote Vault image is reloaded after store notification', (
    tester,
  ) async {
    final root = await Directory.systemTemp.createTemp(
      'chronicle-remote-image-',
    );
    addTearDown(() => root.delete(recursive: true));
    final notifier = ChangeNotifier();
    addTearDown(notifier.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteMarkdownView(
            markdown: '![remote](../Attachments/remote.png)',
            vaultRootPath: root.path,
            assetListenable: notifier,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);

    final attachment = File('${root.path}/Attachments/remote.png');
    await attachment.parent.create(recursive: true);
    await attachment.writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
        '+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
      flush: true,
    );

    notifier.notifyListeners();

    // Vault reads use dart:io. A single pumpAndSettle can stop before that
    // real asynchronous read completes because no frame is scheduled yet.
    // Give the I/O event loop a bounded chance to finish, pumping the widget
    // tree after each wait so the completed FutureBuilder can rebuild.
    for (var attempt = 0; attempt < 20; attempt += 1) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
      if (find.byType(Image).evaluate().isNotEmpty &&
          find.byIcon(Icons.broken_image_outlined).evaluate().isEmpty) {
        break;
      }
    }

    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });
}
