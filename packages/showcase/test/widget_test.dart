import 'package:flutter_test/flutter_test.dart';
import 'package:showcase/main.dart';

void main() {
  testWidgets('shows the comparison controls', (tester) async {
    await tester.pumpWidget(const PixerShowcase());

    expect(find.text('FULL HD  →  4K'), findsOneWidget);
    expect(find.text('Dart image'), findsOneWidget);
    expect(find.text('Pixer · Rust'), findsOneWidget);
    expect(find.text('RUN COMPARISON'), findsOneWidget);
  });
}
