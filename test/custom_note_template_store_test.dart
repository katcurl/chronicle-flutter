import 'package:chronicle/features/notes/custom_note_template_store.dart';
import 'package:chronicle/features/notes/note_templates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const template = NoteTemplate(
    id: 'custom_test-template',
    title: 'Подготовка образца',
    icon: '🧫',
    noteType: 'sample',
    content: '# Подготовка образца\n\n## Шаги\n',
    category: 'Лаборатория',
    defaultTags: <String>['лаборатория', 'образец'],
    defaultProperties: <String, String>{'operator': ''},
    isCustom: true,
  );

  test('custom templates survive deterministic JSON round trip', () {
    final encoded = CustomNoteTemplateStore.encode(const <NoteTemplate>[
      template,
    ]);
    final decoded = CustomNoteTemplateStore.decode(encoded);

    expect(decoded, hasLength(1));
    expect(decoded.single.id, template.id);
    expect(decoded.single.title, template.title);
    expect(decoded.single.content, template.content);
    expect(decoded.single.category, template.category);
    expect(decoded.single.defaultTags, template.defaultTags);
    expect(decoded.single.defaultProperties, template.defaultProperties);
    expect(decoded.single.isCustom, isTrue);
  });

  test('invalid and built-in entries are ignored during decoding', () {
    final decoded = CustomNoteTemplateStore.decode('''[
      {"id":"lecture","title":"Built in","icon":"🎓","noteType":"lecture","content":"# Lecture","isCustom":false},
      {"id":"custom_empty","title":"","icon":"📝","noteType":"note","content":"","isCustom":true},
      {"id":"custom_valid","title":"Valid","icon":"📝","noteType":"note","content":"# Valid","isCustom":true}
    ]''');

    expect(decoded.map((item) => item.id), <String>['custom_valid']);
  });

  test('corrupt payload safely produces an empty template list', () {
    expect(CustomNoteTemplateStore.decode('{not-json'), isEmpty);
    expect(CustomNoteTemplateStore.decode(null), isEmpty);
  });


  test('export bundle preserves category and portable metadata', () {
    final encoded = CustomNoteTemplateStore.encodeExportBundle(
      const <NoteTemplate>[template],
    );
    final decoded = CustomNoteTemplateStore.decodeImportBundle(encoded);

    expect(decoded, hasLength(1));
    expect(decoded.single.title, template.title);
    expect(decoded.single.category, 'Лаборатория');
    expect(decoded.single.defaultProperties, template.defaultProperties);
  });

  test('legacy JSON list remains importable', () {
    final legacy = CustomNoteTemplateStore.encode(
      const <NoteTemplate>[template],
    );
    final decoded = CustomNoteTemplateStore.decodeImportBundle(legacy);

    expect(decoded.single.id, template.id);
    expect(decoded.single.category, template.category);
  });

  test('foreign export bundle is rejected', () {
    expect(
      () => CustomNoteTemplateStore.decodeImportBundle(
        '{"format":"other.app","version":1,"templates":[]}',
      ),
      throwsFormatException,
    );
  });
}
