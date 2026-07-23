import 'package:chronicle/features/notes/note_toolbar_preferences_store.dart';
import 'package:chronicle/features/notes/note_toolbar_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default toolbar profiles cover laboratory, study and minimal use', () {
    final preferences = NoteToolbarPreferences.defaults();

    expect(preferences.profiles.map((profile) => profile.id), <String>[
      'laboratory',
      'study',
      'minimal',
    ]);
    expect(preferences.activeProfile.id, 'laboratory');
    expect(
      preferences.activeProfile.actions,
      contains(NoteToolbarAction.scientificTable),
    );
    expect(
      preferences.activeProfile.actions,
      contains(NoteToolbarAction.pasteImage),
    );
  });

  test('toolbar preferences round-trip through local JSON storage', () {
    final custom = NoteToolbarProfile(
      id: 'custom',
      name: 'Моя панель',
      emoji: '🧬',
      actionIds: const <String>[
        'bold',
        'note_link',
        'scientific_table',
      ],
    );
    final source = NoteToolbarPreferences.normalized(
      activeProfileId: custom.id,
      profiles: <NoteToolbarProfile>[custom],
    );

    final decoded = NoteToolbarPreferencesStore.decode(
      NoteToolbarPreferencesStore.encode(source),
    );

    expect(decoded.activeProfileId, custom.id);
    expect(decoded.activeProfile.name, custom.name);
    expect(decoded.activeProfile.emoji, custom.emoji);
    expect(decoded.activeProfile.actionIds, custom.actionIds);
  });

  test('unknown and duplicate actions are removed while order is preserved', () {
    final profile = NoteToolbarProfile.fromJson(<String, Object?>{
      'id': 'safe',
      'name': 'Safe',
      'emoji': 'S',
      'actionIds': <String>[
        'bold',
        'unknown-action',
        'bold',
        'paste_image',
        'heading',
      ],
    });

    expect(profile, isNotNull);
    expect(profile!.actionIds, <String>['bold', 'paste_image', 'heading']);
  });

  test('corrupt storage safely restores built-in profiles', () {
    final decoded = NoteToolbarPreferencesStore.decode('{broken json');

    expect(decoded.profiles, isNotEmpty);
    expect(decoded.activeProfile.id, 'laboratory');
  });

  test('normalization repairs duplicate profile ids and missing active id', () {
    final first = NoteToolbarProfile(
      id: 'same',
      name: 'First',
      emoji: '1',
      actionIds: const <String>['bold'],
    );
    final second = first.copyWith(name: 'Second');

    final normalized = NoteToolbarPreferences.normalized(
      activeProfileId: 'missing',
      profiles: <NoteToolbarProfile>[first, second],
    );

    expect(normalized.profiles, hasLength(1));
    expect(normalized.activeProfileId, 'same');
    expect(normalized.activeProfile.name, 'First');
  });
}
