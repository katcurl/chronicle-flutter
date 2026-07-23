import 'package:chronicle/features/notes/note_editor_preferences_store.dart';
import 'package:chronicle/features/notes/note_editor_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default editor profiles cover scientific, focus and compact use', () {
    final preferences = NoteEditorPreferences.defaults();

    expect(preferences.profiles.map((profile) => profile.id), containsAll(<String>[
      'scientific',
      'focus',
      'compact',
    ]));
    expect(preferences.activeProfile.id, 'scientific');
    expect(preferences.activeProfile.showToolbar, isTrue);
  });

  test('editor profiles round-trip through local JSON storage', () {
    final source = NoteEditorPreferences.normalized(
      activeProfileId: 'custom',
      profiles: <NoteEditorProfile>[
        NoteEditorProfile.defaults().first,
        const NoteEditorProfile(
          id: 'custom',
          name: 'Мой режим',
          emoji: '🧬',
          font: NoteEditorFont.serif,
          fontSize: 18,
          lineHeight: 1.8,
          contentWidth: 720,
          previewScale: 1.1,
          density: NoteEditorDensity.spacious,
          startMode: NoteEditorStartMode.preview,
          showTitle: false,
          showToolbar: false,
          showLinkSuggestions: false,
          showContextPanel: false,
          showTimerButton: false,
        ),
      ],
    );

    final decoded = NoteEditorPreferencesStore.decode(
      NoteEditorPreferencesStore.encode(source),
    );

    expect(decoded.activeProfile.id, 'custom');
    expect(decoded.activeProfile.font, NoteEditorFont.serif);
    expect(decoded.activeProfile.fontSize, 18);
    expect(decoded.activeProfile.contentWidth, 720);
    expect(decoded.activeProfile.showContextPanel, isFalse);
  });

  test('invalid numeric values are bounded during decoding', () {
    final profile = NoteEditorProfile.fromJson(<String, Object?>{
      'id': 'unsafe',
      'name': 'Unsafe',
      'fontSize': 100,
      'lineHeight': 0.2,
      'contentWidth': 40,
      'previewScale': 9,
    });

    expect(profile, isNotNull);
    final decoded = profile!;
    expect(decoded.fontSize, 24);
    expect(decoded.lineHeight, 1.2);
    expect(decoded.contentWidth, 560);
    expect(decoded.previewScale, 1.4);
  });

  test('corrupt preferences fall back to safe defaults', () {
    final decoded = NoteEditorPreferencesStore.decode('{not-json');

    expect(decoded.activeProfile.id, 'scientific');
    expect(decoded.profiles, isNotEmpty);
  });
}
