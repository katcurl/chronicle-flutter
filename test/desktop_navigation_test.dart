import 'package:chronicle/widgets/desktop_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Escape closes the current Chronicle route', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder:
                              (_) => const EscapeToClose(
                                child: Scaffold(
                                  body: Center(child: Text('Nested screen')),
                                ),
                              ),
                        ),
                      );
                    },
                    child: const Text('Open screen'),
                  ),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Open screen'));
    await tester.pumpAndSettle();
    expect(find.text('Nested screen'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Nested screen'), findsNothing);
    expect(find.text('Open screen'), findsOneWidget);
  });
}
