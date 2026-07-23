import 'package:chronicle/features/notes/note_home_preferences.dart';
import 'package:chronicle/features/notes/note_home_preferences_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('note home defaults expose every section in a stable order', () {
    final preferences = NoteHomePreferences.defaults();

    expect(preferences.orderedSections, NoteHomeSection.values);
    expect(preferences.hiddenSectionIds, isEmpty);
    expect(preferences.itemLimit, 4);
    expect(preferences.compactCards, isFalse);
    expect(preferences.openOnHome, isTrue);
  });

  test('normalization removes invalid duplicates and appends new sections', () {
    final preferences = NoteHomePreferences.normalized(
      sectionIds: const <String>['recent', 'unknown', 'recent', 'pinned'],
      hiddenSectionIds: const <String>['pinned', 'missing'],
      itemLimit: 99,
      compactCards: true,
      openOnHome: false,
    );

    expect(preferences.sectionIds.take(2), const <String>['recent', 'pinned']);
    expect(preferences.sectionIds.toSet(), <String>{
      for (final section in NoteHomeSection.values) section.id,
    });
    expect(preferences.hiddenSectionIds, const <String>{'pinned'});
    expect(preferences.itemLimit, NoteHomePreferences.maxItemLimit);
    expect(preferences.compactCards, isTrue);
    expect(preferences.openOnHome, isFalse);
  });

  test('preferences survive JSON encoding and decoding', () {
    final original = NoteHomePreferences.normalized(
      sectionIds: const <String>[
        'templates',
        'continue_work',
        'recent',
        'projects',
        'folders',
        'pinned',
      ],
      hiddenSectionIds: const <String>['folders'],
      itemLimit: 6,
      compactCards: true,
      openOnHome: false,
    );

    final decoded = NoteHomePreferencesStore.decode(
      NoteHomePreferencesStore.encode(original),
    );

    expect(decoded.sectionIds, original.sectionIds);
    expect(decoded.hiddenSectionIds, original.hiddenSectionIds);
    expect(decoded.itemLimit, 6);
    expect(decoded.compactCards, isTrue);
    expect(decoded.openOnHome, isFalse);
  });

  test('corrupt storage falls back to safe defaults', () {
    final preferences = NoteHomePreferencesStore.decode('{not-json');
    final defaults = NoteHomePreferences.defaults();

    expect(preferences.sectionIds, defaults.sectionIds);
    expect(preferences.hiddenSectionIds, defaults.hiddenSectionIds);
    expect(preferences.itemLimit, defaults.itemLimit);
    expect(preferences.openOnHome, defaults.openOnHome);
  });
}
