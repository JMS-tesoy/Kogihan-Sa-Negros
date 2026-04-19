import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Basic smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Smoke Test'),
          ),
        ),
      ),
    );

    expect(find.text('Smoke Test'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}