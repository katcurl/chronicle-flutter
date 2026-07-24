import 'dart:io';

import 'package:chronicle/features/notes/note_editor_profile.dart';
import 'package:chronicle/features/notes/note_markdown_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('default preview blocks remote images without network access', (
    tester,
  ) async {
    final overrides = _RecordingHttpOverrides();
    HttpOverrides.global = overrides;
    addTearDown(() => HttpOverrides.global = null);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NoteMarkdownView(
            markdown:
                '![tracking pixel](https://tracker.invalid/pixel?id=secret)',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(overrides.createdClientCount, 0);
    expect(
      find.byKey(
        const ValueKey<String>('remote-image-blocked:tracker.invalid'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('tracker.invalid'), findsOneWidget);
    expect(find.text('Загрузить один раз'), findsOneWidget);
    expect(find.text('Разрешить домен'), findsOneWidget);
  });

  test('default profiles persist a blocked remote-image policy', () {
    final defaults = NoteEditorPreferences.defaults();

    expect(defaults.activeProfile.remoteImagePolicy, RemoteImagePolicy.block);
    expect(
      NoteEditorProfile.fromJson(<String, Object?>{
        'id': 'legacy',
        'name': 'Legacy',
      })!.remoteImagePolicy,
      RemoteImagePolicy.block,
    );
  });

  test('data URI budgets reject oversized payloads before decoding', () {
    expect(
      noteDataImageEncodedPayloadFits(
        encodedPayloadLength: noteDataImageMaxEncodedBytes + 1,
      ),
      isFalse,
    );
    expect(
      noteDataImageDecodedLengthFits(noteDataImageMaxDecodedBytes + 1),
      isFalse,
    );
  });

  test('data image dimensions are bounded before rendering', () {
    expect(noteDataImageDimensionsFit(width: 1, height: 1), isTrue);
    expect(
      noteDataImageDimensionsFit(
        width: noteDataImageMaxDimension + 1,
        height: 1,
      ),
      isFalse,
    );
    expect(noteDataImageDimensionsFit(width: 8000, height: 8000), isFalse);
  });
}

final class _RecordingHttpOverrides extends HttpOverrides {
  int createdClientCount = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    createdClientCount += 1;
    return super.createHttpClient(context);
  }
}
