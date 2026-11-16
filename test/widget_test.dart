import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kogihan_sa_negros/app/bootstrap/land_finder_app_bootstrap.dart';

void main() {
  test('resolveMapboxAccessToken trims the env value', () {
    final token = resolveMapboxAccessToken(
      env: {'MAPBOX_ACCESS_TOKEN': '  token-value  '},
    );

    expect(token, 'token-value');
  });

  test('resolveMapboxAccessToken returns empty for missing token', () {
    final token = resolveMapboxAccessToken(env: {});

    expect(token, isEmpty);
  });

  testWidgets('Basic smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('Smoke Test'))),
      ),
    );

    expect(find.text('Smoke Test'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
