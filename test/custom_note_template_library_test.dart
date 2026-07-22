import 'package:chronicle/features/notes/custom_note_template_library.dart';
import 'package:chronicle/features/notes/note_templates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const laboratory = NoteTemplate(
    id: 'custom_lab',
    title: 'Очистка белка',
    icon: '🧬',
    category: 'Лаборатория',
    noteType: 'protein_purification',
    content: '# Очистка\n',
    defaultTags: <String>['белок', 'очистка'],
    isCustom: true,
  );
  const study = NoteTemplate(
    id: 'custom_study',
    title: 'Конспект семинара',
    icon: '🎓',
    category: 'Учёба',
    noteType: 'lecture',
    content: '# Семинар\n',
    defaultTags: <String>['семинар'],
    isCustom: true,
  );
  const uncategorized = NoteTemplate(
    id: 'custom_plain',
    title: 'Быстрая заметка',
    icon: '📝',
    noteType: 'note',
    content: '# Заметка\n',
    isCustom: true,
  );

  test('library filters by category and searchable metadata', () {
    const templates = <NoteTemplate>[laboratory, study, uncategorized];

    expect(
      CustomNoteTemplateLibrary.filter(
        templates,
        category: 'Лаборатория',
      ).map((template) => template.id),
      <String>['custom_lab'],
    );
    expect(
      CustomNoteTemplateLibrary.filter(
        templates,
        query: 'очистка',
      ).map((template) => template.id),
      <String>['custom_lab'],
    );
    expect(
      CustomNoteTemplateLibrary.filter(
        templates,
        category: CustomNoteTemplateLibrary.uncategorizedKey,
      ).map((template) => template.id),
      <String>['custom_plain'],
    );
  });

  test('categories are stable and alphabetically sorted', () {
    final categories = CustomNoteTemplateLibrary.categories(
      const <NoteTemplate>[study, uncategorized, laboratory],
    );

    expect(categories, <String>[
      CustomNoteTemplateLibrary.uncategorizedKey,
      'Лаборатория',
      'Учёба',
    ]);
  });

  test('equivalence ignores ids but includes category and content', () {
    const copy = NoteTemplate(
      id: 'custom_copy',
      title: 'Очистка белка',
      icon: '🧬',
      category: 'лаборатория',
      noteType: 'protein_purification',
      content: '# Очистка\n\n',
      defaultTags: <String>['белок', 'очистка'],
      isCustom: true,
    );
    const differentCategory = NoteTemplate(
      id: 'custom_other',
      title: 'Очистка белка',
      icon: '🧬',
      category: 'Протоколы',
      noteType: 'protein_purification',
      content: '# Очистка\n',
      defaultTags: <String>['белок', 'очистка'],
      isCustom: true,
    );

    expect(CustomNoteTemplateLibrary.equivalent(laboratory, copy), isTrue);
    expect(
      CustomNoteTemplateLibrary.equivalent(laboratory, differentCategory),
      isFalse,
    );
  });
}
