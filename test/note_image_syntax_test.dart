import 'package:chronicle/features/notes/note_document.dart';
import 'package:chronicle/features/notes/note_image_syntax.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ordinary Markdown image receives safe defaults', () {
    final reference = NoteImageSyntax.first(
      'Текст\n\n![model.png](../../Attachments/model.png)\n',
    );

    expect(reference, isNotNull);
    final image = reference!;
    expect(image.alt, 'model.png');
    expect(image.target, '../../Attachments/model.png');
    expect(image.presentation.widthPercent, 100);
    expect(image.presentation.alignment, NoteImageAlignment.center);
    expect(image.presentation.caption, isEmpty);
  });

  test('Chronicle image presentation survives Markdown round-trip', () {
    const presentation = NoteImagePresentation(
      widthPercent: 55,
      alignment: NoteImageAlignment.right,
      caption: 'Метастабильное состояние Orf9b — кадр 1200',
      figureId: 'orf9b-frame-1200',
    );
    const source = '![Orf9b](../../Attachments/orf9b.png)';
    final initial = NoteImageSyntax.first(source)!;

    final markdown = initial.toMarkdown(presentation: presentation);
    final restored = NoteImageSyntax.first(markdown)!;

    expect(restored.presentation.widthPercent, 55);
    expect(restored.presentation.alignment, NoteImageAlignment.right);
    expect(
      restored.presentation.caption,
      'Метастабильное состояние Orf9b — кадр 1200',
    );
    expect(markdown, contains('chronicle-image'));
    expect(restored.presentation.figureId, 'orf9b-frame-1200');
    expect(markdown, contains('caption='));
    expect(markdown, contains('figure=orf9b-frame-1200'));
  });

  test('image on current editor line can be found and relocated', () {
    const source = '''Введение

![Схема](../../Attachments/schema.png)

Вывод
''';
    final cursor = source.indexOf('schema.png');
    final reference = NoteImageSyntax.findAtOffset(source, cursor)!;

    expect(reference.alt, 'Схема');

    final shiftedSource = 'Префикс\n$source';
    final relocated = NoteImageSyntax.relocate(shiftedSource, reference);

    expect(relocated, isNotNull);
    expect(relocated!.target, '../../Attachments/schema.png');
    expect(relocated.start, reference.start + 'Префикс\n'.length);
  });

  test('image metadata does not inflate note word count', () {
    final image = NoteImageSyntax.first(
      '![Orf9b](../../Attachments/orf9b.png)',
    )!;
    final markdown = image.toMarkdown(
      presentation: const NoteImagePresentation(
        widthPercent: 50,
        caption: 'Состояние после МД',
      ),
    );

    expect(NoteDocument.wordCount(markdown), 4);
  });

  test('image presentation survives note save and reload', () {
    final image = NoteImageSyntax.first(
      '![Orf9b](../../Attachments/orf9b.png)',
    )!;
    final configured = image.toMarkdown(
      presentation: const NoteImagePresentation(
        widthPercent: 45,
        alignment: NoteImageAlignment.left,
        caption: 'Кадр после МД',
      ),
    );
    final note = Note(
      id: 'note-1',
      title: 'Orf9b',
      projectId: 'project-1',
      body: '',
    );

    final serialized = NoteDocument.serialize(note, configured);
    final restoredDocument = NoteDocument.parse(serialized);
    final restored = NoteImageSyntax.first(restoredDocument.content)!;

    expect(restored.presentation.widthPercent, 45);
    expect(restored.presentation.alignment, NoteImageAlignment.left);
    expect(restored.presentation.caption, 'Кадр после МД');
  });

  test('width is restricted to the supported responsive range', () {
    final tooSmall = NoteImagePresentation.fromMarkdownTitle(
      'chronicle-image width=1 align=left',
    );
    final tooLarge = NoteImagePresentation.fromMarkdownTitle(
      'chronicle-image width=500 align=right',
    );

    expect(tooSmall.widthPercent, 20);
    expect(tooLarge.widthPercent, 100);
  });
}
