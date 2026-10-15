import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finfamily_mobile/config/theme.dart';

void main() {
  testWidgets('FinFamily theme and widget smoke test initializes cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Center(
            child: Text('FinFamily'),
          ),
        ),
      ),
    );
    expect(find.text('FinFamily'), findsOneWidget);
  });
}
