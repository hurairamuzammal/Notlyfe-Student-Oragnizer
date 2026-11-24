import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notlyfe/widgets/m3_expressive_widgets.dart';

void main() {
  testWidgets('M3MorphingPillButton renders label and handles tap',
      (WidgetTester tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: M3MorphingPillButton(
              icon: Icons.add_rounded,
              onPressed: () => tapped = true,
              label: const Text('New Note'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('New Note'), findsOneWidget);
    await tester.tap(find.text('New Note'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });
}
