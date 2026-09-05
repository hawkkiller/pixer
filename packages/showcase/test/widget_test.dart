import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:showcase/main.dart';

void main() {
  testWidgets('shows and runs the Pixer operations', (tester) async {
    await tester.pumpWidget(const PixerShowcase());
    await tester.pumpAndSettle();

    expect(find.text('Pixer'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(14));
    expect(find.text('Result'), findsOneWidget);
  });
}
