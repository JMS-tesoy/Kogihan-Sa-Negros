import 'package:flutter/material.dart';

import '../../../../core/widgets/app_snack_bar.dart';
import '../controllers/subscription_controller.dart';
import '../../data/services/subscription_service.dart';
import '../../domain/entities/plan_entity.dart';

String _formatDate(DateTime value) {
  final DateTime local = value.toLocal();
  const List<String> months = <String>[
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
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}

int _daysRemaining(DateTime value) {
  final Duration diff = value.toLocal().difference(DateTime.now());
  if (diff.isNegative) return 0;
  if (diff.inHours < 24) return 1;
  return diff.inDays + (diff.inHours % 24 == 0 ? 0 : 1);
}

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  late final SubscriptionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SubscriptionController();
    _controller.addListener(_rebuild);
    _controller.init();
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _subscribe(PlanEntity plan) async {
    await _controller.subscribe(plan.id);
    if (!mounted) return;

    if (_controller.error != null) {
      AppSnackBar.error(context, _controller.error!);
      return;
    }

    AppSnackBar.success(
      context,
      _controller.isPremium
          ? '${plan.title} activated.'
          : 'Subscription updated.',
    );
  }

  Future<void> _restore() async {
    await _controller.restoreSubscription();
    if (!mounted) return;

    if (_controller.error != null) {
      AppSnackBar.error(context, _controller.error!);
      return;
    }

    if (_controller.isPremium) {
      AppSnackBar.success(context, 'Purchase restored.');
    } else {
      AppSnackBar.info(context, 'No active purchase found.');
    }
  }

  Future<void> _cancel() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Subscription'),
        content: const Text(
          'Cancel your current plan and switch back to Free?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Plan'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    await _controller.cancelSubscription();

    if (!mounted) return;

    if (_controller.error != null) {
      AppSnackBar.error(context, _controller.error!);
      return;
    }

    AppSnackBar.success(context, 'Subscription cancelled. Now on Free plan.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription'), centerTitle: true),
      body: _controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _SubscriptionBody(
              controller: _controller,
              onSubscribe: _subscribe,
              onRestore: _restore,
              onCancel: _cancel,
            ),
    );
  }
}

// ─── Body ────────────────────────────────────────────────────────────────────

class _SubscriptionBody extends StatelessWidget {
  const _SubscriptionBody({
    required this.controller,
    required this.onSubscribe,
    required this.onRestore,
    required this.onCancel,
  });

  final SubscriptionController controller;
  final Future<void> Function(PlanEntity plan) onSubscribe;
  final VoidCallback onRestore;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserSubscription>(
      valueListenable: appSubscriptionNotifier,
      builder: (context, subscription, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _StatusCard(
              subscription: subscription,
              isActing: controller.isActing,
              onCancel: onCancel,
            ),
            const SizedBox(height: 16),
            ...controller.plans.map(
              (plan) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PlanCard(
                  plan: plan,
                  isActive:
                      subscription.tier == plan.tier &&
                      (plan.tier == SubscriptionTier.free ||
                          subscription.isPremium),
                  isActing: controller.isActing,
                  onSubscribe: () => onSubscribe(plan),
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: controller.isActing ? null : onRestore,
              icon: const Icon(Icons.restore),
              label: const Text('Restore Purchase'),
            ),
            if (controller.error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                controller.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );
      },
    );
  }
}

// ─── Status Card ─────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.subscription,
    required this.isActing,
    required this.onCancel,
  });

  final UserSubscription subscription;
  final bool isActing;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  subscription.isPremium
                      ? Icons.workspace_premium
                      : Icons.lock_open_outlined,
                  color: subscription.isPremium
                      ? cs.primary
                      : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    subscription.planName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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
            _DetailRow(
              icon: Icons.verified_outlined,
              label: 'Status',
              value: subscription.isPremium ? 'Active' : 'Inactive',
            ),
            const SizedBox(height: 10),
            _DetailRow(
              icon: Icons.badge_outlined,
              label: 'Plan',
              value: subscription.planName,
            ),
            if (subscription.expiresAt != null) ...<Widget>[
              const SizedBox(height: 10),
              _DetailRow(
                icon: Icons.calendar_today_outlined,
                label: 'Expires on',
                value: _formatDate(subscription.expiresAt!),
              ),
              const SizedBox(height: 10),
              _DetailRow(
                icon: Icons.timelapse_outlined,
                label: 'Time left',
                value:
                    '${_daysRemaining(subscription.expiresAt!)} day(s) remaining',
              ),
            ],
            const SizedBox(height: 10),
            _DetailRow(
              icon: Icons.bookmark_border,
              label: 'Saved lots',
              value: subscription.isPremium
                  ? 'Unlimited'
                  : 'Up to $freeSavedPropertiesLimit',
            ),
            if (subscription.isPremium) ...<Widget>[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isActing ? null : onCancel,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel Subscription'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: <TextSpan>[
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

// ─── Plan Card ───────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isActive,
    required this.isActing,
    required this.onSubscribe,
  });

  final PlanEntity plan;
  final bool isActive;
  final bool isActing;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
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
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Active',
                      style: TextStyle(
                        color: cs.onPrimaryContainer,
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
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            ...plan.features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: cs.primary,
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
                onPressed: isActive || isActing ? null : onSubscribe,
                child: isActing && !isActive
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
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

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) => const SubscriptionPage();
}
