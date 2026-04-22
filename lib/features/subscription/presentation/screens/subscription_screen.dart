import 'package:flutter/material.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/widgets/app_scaffold_shell.dart';
import '../widgets/current_subscription_banner.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffoldShell(
      title: 'Subscription',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const CurrentSubscriptionBanner(message: 'No active subscription.'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pushNamed(RouteNames.plans),
            child: const Text('View plans'),
          ),
        ],
      ),
    );
  }
}
