import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kogihan_sa_negros/features/admin/presentation/widgets/admin_overview_tab.dart';

void main() {
  testWidgets('shows existing metrics and shortcuts to admin sections', (
    WidgetTester tester,
  ) async {
    final List<int> selectedTabs = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminOverviewTab(
            properties: 12,
            agents: 3,
            pendingRequests: 2,
            users: 25,
            onSelectTab: selectedTabs.add,
          ),
        ),
      ),
    );

    expect(find.text('Listings'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('2 pending requests need review.'), findsOneWidget);

    await tester.tap(find.text('Review team requests'));
    await tester.tap(find.text('Manage agents'));
    await tester.ensureVisible(find.text('Browse users'));
    await tester.tap(find.text('Browse users'));

    expect(selectedTabs, <int>[2, 1, 3]);
  });

  testWidgets('shows an empty pending-request summary', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminOverviewTab(
            properties: 0,
            agents: 0,
            pendingRequests: 0,
            users: 0,
            onSelectTab: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('No pending requests to review.'), findsOneWidget);
  });
}
