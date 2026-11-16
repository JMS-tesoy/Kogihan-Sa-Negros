import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kogihan_sa_negros/features/admin/presentation/widgets/admin_stats_header.dart';

void main() {
  testWidgets('shows dashboard metrics', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdminStatsHeader(
            properties: 12,
            agents: 3,
            pendingRequests: 2,
            users: 25,
          ),
        ),
      ),
    );

    expect(find.text('Listings'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Agents'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Pending requests'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Users'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
  });

  testWidgets('marks unavailable listing count as unknown', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdminStatsHeader(
            properties: null,
            agents: 0,
            pendingRequests: 0,
            users: 0,
          ),
        ),
      ),
    );

    expect(find.text('—'), findsOneWidget);
  });
}
