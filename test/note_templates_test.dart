import 'package:chronicle/features/notes/note_templates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('laboratory templates have stable unique identifiers', () {
    expect(laboratoryNoteTemplates, hasLength(6));

    final ids = laboratoryNoteTemplates.map((template) => template.id).toSet();
    expect(ids, hasLength(laboratoryNoteTemplates.length));
    expect(ids, {
      'lab_day',
      'experiment',
      'sample',
      'protein_purification',
      'nmr_experiment',
      'solution',
    });
  });

  test('laboratory templates are included without replacing existing ones', () {
    final ids = noteTemplates.map((template) => template.id).toSet();

    expect(
      ids,
      containsAll(<String>[
        'blank',
        'lecture',
        'research',
        'literature',
        'meeting',
      ]),
    );
    expect(ids, containsAll(laboratoryNoteTemplates.map((item) => item.id)));
  });

  test('laboratory templates provide structured metadata and content', () {
    for (final template in laboratoryNoteTemplates) {
      expect(template.defaultTags, isNotEmpty, reason: template.id);
      expect(template.defaultProperties, isNotEmpty, reason: template.id);
      expect(template.content, startsWith('# '), reason: template.id);
      expect(template.content, contains('## '), reason: template.id);
      expect(noteTypeLabel(template.noteType), isNot('Заметка'));
      expect(noteTypeIcon(template.noteType), template.icon);
    }
  });

  test('specialized templates retain their defining laboratory sections', () {
    final byId = {
      for (final template in laboratoryNoteTemplates) template.id: template,
    };

    expect(byId['sample']!.content, contains('## История образца'));
    expect(byId['protein_purification']!.content, contains('## Хроматография'));
    expect(byId['nmr_experiment']!.content, contains('## Спектрометр и зонд'));
    expect(byId['solution']!.content, contains('## Расчёт состава'));
  });
}
