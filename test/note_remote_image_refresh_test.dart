import 'dart:convert';
import 'dart:typed_data';

import 'package:chronicle/features/notes/note_markdown_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('remote Vault image is reloaded after store notification', (
    tester,
  ) async {
    final notifier = ChangeNotifier();
    addTearDown(notifier.dispose);

    Uint8List? availableBytes;
    var loadCount = 0;
    Future<Uint8List?> loader(String rootPath, String markdownPath) async {
      loadCount += 1;
      return availableBytes;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteMarkdownView(
            markdown: '![remote](../Attachments/remote.png)',
            vaultRootPath: '/test-vault',
            assetListenable: notifier,
            assetLoader: loader,
          ),
        ),
      ),
    );
    await tester.pump();

    const fallbackKey = ValueKey(
      'vault-image-fallback:../Attachments/remote.png',
    );
    const imageKey = ValueKey('vault-image:../Attachments/remote.png');

    expect(find.byKey(fallbackKey), findsOneWidget);
    expect(find.byKey(imageKey), findsNothing);
    expect(loadCount, 1);

    availableBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
      '+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    notifier.notifyListeners();
    await tester.pump();
    await tester.pump();

    expect(loadCount, 2);
    expect(find.byKey(fallbackKey), findsNothing);
    expect(find.byKey(imageKey), findsOneWidget);
  });
}
