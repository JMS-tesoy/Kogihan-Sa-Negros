import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kogihan_sa_negros/features/admin/presentation/screens/moderation_screen.dart';
import 'package:kogihan_sa_negros/features/inquiries/presentation/screens/inquiries_screen.dart';

void main() {
  testWidgets('inquiries does not present its stub as an empty inbox', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: InquiriesScreen()));

    expect(find.text('Inquiries are not available yet.'), findsOneWidget);
  });

  testWidgets('moderation indicates its queue is not available', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ModerationScreen()));

    expect(find.text('Moderation is not available yet.'), findsOneWidget);
  });
}
