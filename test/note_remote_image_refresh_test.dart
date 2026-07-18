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
    final fallbackKey = ValueKey(
      'vault-image-fallback:../Attachments/remote.png',
    );
    final imageKey = ValueKey('vault-image:../Attachments/remote.png');

    for (var attempt = 0; attempt < 20; attempt += 1) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
      if (find.byKey(fallbackKey).evaluate().isNotEmpty) {
        break;
      }
    }
    expect(find.byKey(fallbackKey), findsOneWidget);

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

    // Vault reads use dart:io. Give the real I/O event loop a bounded chance
    // to finish and pump after each wait. The image widget explicitly calls
    // setState when the newest guarded read completes.
    for (var attempt = 0; attempt < 20; attempt += 1) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
      if (find.byKey(imageKey).evaluate().isNotEmpty &&
          find.byKey(fallbackKey).evaluate().isEmpty) {
        break;
      }
    }

    expect(find.byKey(fallbackKey), findsNothing);
    expect(find.byKey(imageKey), findsOneWidget);
  });
}
