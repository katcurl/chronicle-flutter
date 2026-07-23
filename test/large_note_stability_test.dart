import 'package:chronicle/features/notes/debounced_text_notifier.dart';
import 'package:chronicle/features/notes/note_document.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('large note survives parse, serialize and reparse without truncation', () {
    final buffer = StringBuffer('# Long experiment history\n\n');
    for (var index = 0; index < 30000; index += 1) {
      buffer.writeln(
        '- Frame $index: RMSD ${(index % 37) / 10} nm; state ${index % 4}.',
      );
    }
    final content = buffer.toString();
    final note = Note(
      id: 'large-note',
      title: 'Long trajectory',
      projectId: 'project-1',
      body: content,
      noteType: 'experiment',
      tags: const <String>['md', 'trajectory'],
    );

    final encoded = NoteDocument.serialize(note, content);
    final parsed = NoteDocument.parse(encoded);
    final encodedAgain = NoteDocument.serialize(note, parsed.content);
    final reparsed = NoteDocument.parse(encodedAgain);

    expect(content.length, greaterThan(1_000_000));
    expect(parsed.content, content.trimLeft());
    expect(reparsed.content, parsed.content);
    expect(reparsed.frontMatter['type'], 'experiment');
    expect(
      NoteDocument.wordCount(reparsed.content),
      greaterThan(100000),
    );
  });

  test('preview notifier coalesces rapid updates for a large note', () {
    final notifier = DebouncedTextNotifier(
      'initial',
      delay: const Duration(hours: 1),
    );
    addTearDown(notifier.dispose);
    final large = List<String>.filled(100000, 'result').join(' ');

    notifier.schedule('$large first');
    notifier.schedule('$large final');
    expect(notifier.value, 'initial');

    notifier.flush();

    expect(notifier.value, endsWith('final'));
    expect(notifier.hasPendingValue, isFalse);
  });
}
