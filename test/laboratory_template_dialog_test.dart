import 'package:chronicle/features/notes/laboratory_template_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const template = '# Эксперимент\n\n## Цель\n';

  test('empty note receives normalized template content', () {
    final result = applyLaboratoryTemplateContent(
      currentText: '  \n',
      templateContent: template,
      placement: LaboratoryTemplatePlacement.append,
    );

    expect(result, '# Эксперимент\n\n## Цель\n');
  });

  test('append preserves existing content and adds one blank separator', () {
    final result = applyLaboratoryTemplateContent(
      currentText: '# Текущая заметка\n\nНаблюдение.\n\n',
      templateContent: template,
      placement: LaboratoryTemplatePlacement.append,
    );

    expect(
      result,
      '# Текущая заметка\n\nНаблюдение.\n\n'
      '# Эксперимент\n\n## Цель\n',
    );
  });

  test('append preserves existing trailing whitespace byte-for-byte', () {
    const current = '# Наблюдение  \n';
    final result = applyLaboratoryTemplateContent(
      currentText: current,
      templateContent: template,
      placement: LaboratoryTemplatePlacement.append,
    );

    expect(result, '$current\n# Эксперимент\n\n## Цель\n');
  });

  test('replace discards current body only when explicitly requested', () {
    final result = applyLaboratoryTemplateContent(
      currentText: '# Старый текст\n',
      templateContent: template,
      placement: LaboratoryTemplatePlacement.replace,
    );

    expect(result, '# Эксперимент\n\n## Цель\n');
  });

  test('template trailing whitespace is normalized deterministically', () {
    final result = applyLaboratoryTemplateContent(
      currentText: '',
      templateContent: '# Буфер\n\n   \n',
      placement: LaboratoryTemplatePlacement.replace,
    );

    expect(result, '# Буфер\n');
  });
}
