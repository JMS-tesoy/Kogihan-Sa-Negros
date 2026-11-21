import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kogihan_sa_negros/features/subscription/presentation/screens/subscription_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('subscription screen exposes real store actions', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const MaterialApp(home: SubscriptionPage()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Store billing is not configured'),
      findsNothing,
    );
    await tester.scrollUntilVisible(
      find.text('Monthly Premium'),
      200,
      scrollable: find.byType(Scrollable),
    );
    final Iterable<ElevatedButton> upgradeButtons = tester
        .widgetList<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Upgrade'),
        );
    expect(upgradeButtons, isNotEmpty);
    expect(upgradeButtons.any((button) => button.onPressed != null), isTrue);
    await tester.scrollUntilVisible(
      find.text('Restore Purchase'),
      200,
      scrollable: find.byType(Scrollable),
    );
    final OutlinedButton restore = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Restore Purchase'),
    );
    expect(restore.onPressed, isNotNull);
  });
}
