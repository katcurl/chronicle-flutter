import 'package:chronicle/features/notes/debounced_text_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('rapid editor changes produce one delayed value', (tester) async {
    final notifier = DebouncedTextNotifier(
      'initial',
      delay: const Duration(milliseconds: 100),
    );
    final values = <String>[];
    notifier.addListener(() => values.add(notifier.value));

    notifier.schedule('first');
    notifier.schedule('second');
    notifier.schedule('final');

    await tester.pump(const Duration(milliseconds: 99));
    expect(notifier.value, 'initial');
    expect(values, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    expect(notifier.value, 'final');
    expect(values, ['final']);

    notifier.dispose();
  });

  testWidgets('paused notifier waits until preview scrolling ends', (
    tester,
  ) async {
    final notifier = DebouncedTextNotifier(
      'before',
      delay: const Duration(milliseconds: 80),
    );

    notifier.pause();
    notifier.schedule('during scroll');
    await tester.pump(const Duration(milliseconds: 200));
    expect(notifier.value, 'before');
    expect(notifier.hasPendingValue, isTrue);

    notifier.resume();
    await tester.pump(const Duration(milliseconds: 79));
    expect(notifier.value, 'before');
    await tester.pump(const Duration(milliseconds: 1));
    expect(notifier.value, 'during scroll');

    notifier.dispose();
  });

  testWidgets('immediate synchronization cancels pending refresh', (
    tester,
  ) async {
    final notifier = DebouncedTextNotifier(
      'old',
      delay: const Duration(milliseconds: 100),
    );

    notifier.pause();
    notifier.schedule('stale');
    notifier.setImmediate('current');
    await tester.pump(const Duration(milliseconds: 200));

    expect(notifier.value, 'current');
    expect(notifier.hasPendingValue, isFalse);

    notifier.dispose();
  });
}
