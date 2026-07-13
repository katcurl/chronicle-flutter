import 'package:chronicle/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Chronicle starts', (tester) async {
    await tester.pumpWidget(const ChronicleApp());
    await tester.pump();
    expect(find.text('Chronicle'), findsNothing);
  });
}
