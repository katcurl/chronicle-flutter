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
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });
}
