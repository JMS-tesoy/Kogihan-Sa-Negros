import 'package:flutter/material.dart';

import 'subscription.dart';

String _formatSubscriptionDate(DateTime value) {
  final DateTime localValue = value.toLocal();
  const List<String> months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${months[localValue.month - 1]} ${localValue.day}, ${localValue.year}';
}

int _subscriptionDaysRemaining(DateTime value) {
  final Duration difference = value.toLocal().difference(DateTime.now());
  if (difference.isNegative) return 0;
  if (difference.inHours < 24) return 1;
  return difference.inDays + (difference.inHours % 24 == 0 ? 0 : 1);
}

class SubscriptionPage extends StatelessWidget {
  const SubscriptionPage({super.key});

  Future<void> _upgradePlan(BuildContext context, SubscriptionPlan plan) async {
    final UserSubscription subscription =
        await SubscriptionService.purchasePlan(plan.tier);
    if (!context.mounted) return;

    final String message = subscription.isPremium
        ? '${subscription.planName} activated locally. Connect store billing in SubscriptionService.purchasePlan to replace this placeholder.'
        : 'Subscription updated.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _restorePurchases(BuildContext context) async {
    final UserSubscription subscription =
        await SubscriptionService.restorePurchases();
    if (!context.mounted) return;

    final String message = subscription.isPremium
        ? '${subscription.planName} restored from local placeholder state.'
        : 'No premium purchase found yet. Wire restore logic in SubscriptionService.restorePurchases.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _cancelSubscription(BuildContext context) async {
    final bool? shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel Subscription'),
          content: const Text(
            'Do you want to cancel your current subscription and switch back to the Free plan?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep Plan'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Cancel Subscription'),
            ),
          ],
        );
      },
    );
    if (shouldCancel != true || !context.mounted) return;

    final UserSubscription subscription =
        await SubscriptionService.cancelSubscription();
    if (!context.mounted) return;

    final String message = subscription.isPremium
        ? 'Subscription updated.'
        : 'Subscription cancelled. Your account is now on the Free plan.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription'), centerTitle: true),
      body: ValueListenableBuilder<UserSubscription>(
        valueListenable: appSubscriptionNotifier,
        builder: (context, subscription, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            subscription.isPremium
                                ? Icons.workspace_premium
                                : Icons.lock_open_outlined,
                            color: subscription.isPremium
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              subscription.planName,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        subscription.isPremium
                            ? 'Premium access is active.'
                            : 'You are currently on the free plan.',
                      ),
                      const SizedBox(height: 16),
                      _SubscriptionDetailRow(
                        icon: Icons.verified_outlined,
                        label: 'Status',
                        value: subscription.isPremium ? 'Active' : 'Inactive',
                      ),
                      const SizedBox(height: 10),
                      _SubscriptionDetailRow(
                        icon: Icons.badge_outlined,
                        label: 'Plan',
                        value: subscription.planName,
                      ),
                      if (subscription.expiresAt != null) ...[
                        const SizedBox(height: 10),
                        _SubscriptionDetailRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Expires on',
                          value: _formatSubscriptionDate(
                            subscription.expiresAt!,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _SubscriptionDetailRow(
                          icon: Icons.timelapse_outlined,
                          label: 'Time left',
                          value:
                              '${_subscriptionDaysRemaining(subscription.expiresAt!)} day(s) remaining',
                        ),
                      ],
                      const SizedBox(height: 10),
                      _SubscriptionDetailRow(
                        icon: Icons.bookmark_border,
                        label: 'Saved lots',
                        value: subscription.isPremium
                            ? 'Unlimited'
                            : 'Up to $freeSavedPropertiesLimit',
                      ),
                      if (subscription.isPremium) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _cancelSubscription(context),
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Cancel Subscription'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'Billing is in placeholder mode for now. Replace the marked methods in lib/subscription.dart when you connect store purchases.',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...subscriptionPlans.map(
                (plan) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SubscriptionPlanCard(
                    plan: plan,
                    isActive:
                        subscription.tier == plan.tier &&
                        (plan.tier == SubscriptionTier.free ||
                            subscription.isPremium),
                    onUpgrade: plan.tier == SubscriptionTier.free
                        ? null
                        : () => _upgradePlan(context, plan),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _restorePurchases(context),
                icon: const Icon(Icons.restore),
                label: const Text('Restore Purchase'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SubscriptionDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SubscriptionDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SubscriptionPlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isActive;
  final VoidCallback? onUpgrade;

  const _SubscriptionPlanCard({
    required this.plan,
    required this.isActive,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Active',
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              plan.priceLabel,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              plan.billingLabel,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            ...plan.features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(feature)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isActive ? null : onUpgrade,
                child: Text(
                  plan.tier == SubscriptionTier.free
                      ? 'Current Plan'
                      : 'Upgrade',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
