import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kogihan_sa_negros/features/admin/presentation/screens/admin_dashboard_screen.dart';

void main() {
  testWidgets('all badges update and cap large counts', (tester) async {
    Widget tabs(int agents, int requests, int users) => MaterialApp(
      home: Scaffold(
        body: AdminDashboardTabs(
          agentCount: agents,
          requestCount: requests,
          userCount: users,
          selectedIndex: 1,
          onSelected: (_) {},
        ),
      ),
    );

    Finder badge(String label, String count) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
      matching: find.text(count),
    );

    await tester.pumpWidget(tabs(0, 0, 0));
    expect(find.text('Overview'), findsOneWidget);
    for (final label in <String>['Agents', 'Requests', 'Users']) {
      expect(badge(label, '0'), findsOneWidget);
    }

    await tester.pumpWidget(tabs(5, 2, 101));
    expect(badge('Agents', '5'), findsOneWidget);
    expect(badge('Requests', '2'), findsOneWidget);
    expect(badge('Users', '99+'), findsOneWidget);
  });

  testWidgets('selects overview and management tabs by index', (tester) async {
    final List<int> selectedIndexes = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminDashboardTabs(
            agentCount: 0,
            requestCount: 0,
            userCount: 0,
            selectedIndex: 0,
            onSelected: selectedIndexes.add,
          ),
        ),
      ),
    );

    for (final (label, index) in <(String, int)>[
      ('Overview', 0),
      ('Agents', 1),
      ('Requests', 2),
      ('Users', 3),
    ]) {
      await tester.tap(find.text(label));
      expect(selectedIndexes.last, index);
    }
  });

  testWidgets('fits dashboard tabs on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminDashboardTabs(
            agentCount: 12,
            requestCount: 2,
            userCount: 25,
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
