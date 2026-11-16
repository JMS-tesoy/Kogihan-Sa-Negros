import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kogihan_sa_negros/features/admin/data/models/agent_profile.dart';
import 'package:kogihan_sa_negros/features/admin/presentation/widgets/agents_tab.dart';

void main() {
  testWidgets('reloads agents and reports deletion to the dashboard', (
    tester,
  ) async {
    const profile = AgentProfile(
      id: '1',
      fullName: 'Test Agent',
      email: 'agent@example.test',
      phone: '123',
    );
    final profiles = <AgentProfile>[];
    var count = -1;
    var deletions = 0;

    Widget tab(int version) => MaterialApp(
      home: Scaffold(
        body: AgentsTab(
          refreshVersion: version,
          fetchProfiles: () async => List<AgentProfile>.of(profiles),
          upsertProfile:
              ({
                required id,
                required fullName,
                required email,
                required phone,
                avatarUrl,
                teamId,
                role,
              }) async {},
          deleteProfile: (id) async => profiles.removeWhere((p) => p.id == id),
          onCountChanged: (value) => count = value,
          onProfileDeleted: () => deletions++,
        ),
      ),
    );

    await tester.pumpWidget(tab(0));
    await tester.pumpAndSettle();
    expect(count, 0);

    profiles.add(profile);
    await tester.pumpWidget(tab(1));
    await tester.pumpAndSettle();
    expect(count, 1);
    expect(find.text('Test Agent'), findsOneWidget);

    await tester.tap(find.text('Test Agent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(deletions, 1);
    expect(count, 0);
    expect(find.text('Test Agent'), findsNothing);
  });
}
