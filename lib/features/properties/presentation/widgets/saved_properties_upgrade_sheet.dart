import 'package:flutter/material.dart';

import '../../../subscription/data/services/subscription_service.dart';

class SavedPropertiesUpgradeSheet extends StatelessWidget {
  final VoidCallback onViewPlans;

  const SavedPropertiesUpgradeSheet({super.key, required this.onViewPlans});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Premium feature',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              'Free users can save up to $freeSavedPropertiesLimit lots. Upgrade to premium for unlimited saved listings.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onViewPlans();
                },
                child: const Text('View Plans'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Not Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
