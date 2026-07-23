import 'package:chronicle/features/notes/note_edit_history.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('rapid changes are coalesced into one undo step', (tester) async {
    final controller = TextEditingController(text: 'start');
    final history = NoteEditHistory(
      controller: controller,
      coalesceDelay: const Duration(milliseconds: 80),
    );

    controller.value = const TextEditingValue(
      text: 'start a',
      selection: TextSelection.collapsed(offset: 7),
    );
    controller.value = const TextEditingValue(
      text: 'start ab',
      selection: TextSelection.collapsed(offset: 8),
    );
    controller.value = const TextEditingValue(
      text: 'start abc',
      selection: TextSelection.collapsed(offset: 9),
    );

    expect(history.canUndo, isTrue);
    await tester.pump(const Duration(milliseconds: 80));
    expect(history.committedEntryCount, 2);

    expect(history.undo(), isTrue);
    expect(controller.text, 'start');

    expect(history.redo(), isTrue);
    expect(controller.text, 'start abc');
    expect(controller.selection, const TextSelection.collapsed(offset: 9));

    history.dispose();
    controller.dispose();
  });

  testWidgets('programmatic edits participate in undo and preserve selection', (
    tester,
  ) async {
    final controller = TextEditingController.fromValue(
      const TextEditingValue(
        text: 'alpha beta',
        selection: TextSelection(baseOffset: 6, extentOffset: 10),
      ),
    );
    final history = NoteEditHistory(
      controller: controller,
      coalesceDelay: const Duration(milliseconds: 40),
    );

    controller.value = controller.value.copyWith(
      text: 'alpha **beta**',
      selection: const TextSelection.collapsed(offset: 14),
      composing: TextRange.empty,
    );
    await tester.pump(const Duration(milliseconds: 40));

    history.undo();
    expect(controller.text, 'alpha beta');
    expect(
      controller.selection,
      const TextSelection(baseOffset: 6, extentOffset: 10),
    );

    history.redo();
    expect(controller.text, 'alpha **beta**');
    expect(controller.selection, const TextSelection.collapsed(offset: 14));

    history.dispose();
    controller.dispose();
  });

  testWidgets('a new edit after undo clears the redo branch', (tester) async {
    final controller = TextEditingController(text: 'one');
    final history = NoteEditHistory(
      controller: controller,
      coalesceDelay: const Duration(milliseconds: 30),
    );

    controller.text = 'two';
    await tester.pump(const Duration(milliseconds: 30));
    controller.text = 'three';
    await tester.pump(const Duration(milliseconds: 30));

    expect(history.undo(), isTrue);
    expect(controller.text, 'two');
    expect(history.canRedo, isTrue);

    controller.value = const TextEditingValue(
      text: 'branch',
      selection: TextSelection.collapsed(offset: 6),
    );
    expect(history.canRedo, isFalse);
    await tester.pump(const Duration(milliseconds: 30));
    expect(history.canRedo, isFalse);

    history.dispose();
    controller.dispose();
  });

  test('reset starts a clean history session', () {
    final controller = TextEditingController(text: 'before');
    final history = NoteEditHistory(controller: controller);

    controller.value = const TextEditingValue(
      text: 'restored',
      selection: TextSelection.collapsed(offset: 8),
    );
    history.reset();

    expect(history.canUndo, isFalse);
    expect(history.canRedo, isFalse);
    expect(history.committedEntryCount, 1);

    history.dispose();
    controller.dispose();
  });
}
