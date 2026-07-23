import 'package:chronicle/reliability/undo_journal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('undo journal restores the latest action once', () async {
    final journal = ChronicleUndoJournal(maxEntries: 3);
    var value = 0;

    journal.push(
      ChronicleUndoEntry(
        label: 'Первое действие',
        restore: () async {
          value = 1;
        },
      ),
    );
    journal.push(
      ChronicleUndoEntry(
        label: 'Второе действие',
        restore: () async {
          value = 2;
        },
      ),
    );

    expect(journal.nextLabel, 'Второе действие');
    expect(await journal.undoLast(), 'Второе действие');
    expect(value, 2);
    expect(journal.length, 1);
    expect(await journal.undoLast(), 'Первое действие');
    expect(value, 1);
    expect(await journal.undoLast(), isNull);
  });

  test('undo journal keeps a failed restoration available', () async {
    final journal = ChronicleUndoJournal();
    journal.push(
      ChronicleUndoEntry(
        label: 'Небезопасная операция',
        restore: () async {
          throw StateError('restore failed');
        },
      ),
    );

    await expectLater(journal.undoLast(), throwsStateError);
    expect(journal.canUndo, isTrue);
    expect(journal.nextLabel, 'Небезопасная операция');
  });

  test('undo journal bounds session history', () {
    final journal = ChronicleUndoJournal(maxEntries: 2);
    for (var index = 0; index < 4; index += 1) {
      journal.push(
        ChronicleUndoEntry(
          label: 'Действие $index',
          restore: () async {},
        ),
      );
    }

    expect(journal.length, 2);
    expect(journal.entries.map((entry) => entry.label), <String>[
      'Действие 3',
      'Действие 2',
    ]);
  });
}
