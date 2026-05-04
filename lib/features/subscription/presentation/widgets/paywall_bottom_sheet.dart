import 'package:flutter/material.dart';

import '../../../../core/widgets/app_snack_bar.dart';
import '../../data/services/subscription_service.dart';
import '../../domain/entities/plan_entity.dart';
import '../controllers/subscription_controller.dart';
import '../screens/subscription_screen.dart';

/// Shows a premium upgrade paywall bottom sheet
///
/// Usage:
/// ```dart
/// final bool? upgraded = await showPaywallBottomSheet(
///   context,
///   feature: 'Agent Teams',
/// );
/// if (upgraded == true) {
///   // User upgraded, proceed with premium feature
/// }
/// ```
Future<bool?> showPaywallBottomSheet(
  BuildContext context, {
  required String feature,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => _PaywallBottomSheet(feature: feature),
  );
}

class _PaywallBottomSheet extends StatefulWidget {
  const _PaywallBottomSheet({required this.feature});

  final String feature;

  @override
  State<_PaywallBottomSheet> createState() => _PaywallBottomSheetState();
}

class _PaywallBottomSheetState extends State<_PaywallBottomSheet> {
  late final SubscriptionController _controller;
  SubscriptionTier _selectedTier = SubscriptionTier.monthly;

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

  Future<void> _upgrade() async {
    final PlanEntity plan = _controller.plans.firstWhere(
      (PlanEntity p) => p.tier == _selectedTier,
      orElse: () => _controller.plans.first,
    );

    await _controller.subscribe(plan.id);

    if (!mounted) return;

    if (_controller.error != null) {
      AppSnackBar.error(context, _controller.error!);
      return;
    }

    if (_controller.isPremium) {
      Navigator.of(context).pop(true);
      AppSnackBar.success(
        context,
        '${plan.title} activated! Enjoy ${widget.feature}.',
      );
    }
  }

  void _viewAllPlans() {
    Navigator.of(context).pop();
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SubscriptionScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: _controller.isLoading
            ? const SizedBox(
                height: 400,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: <Widget>[
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.workspace_premium_rounded,
                            size: 32,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Unlock ${widget.feature}',
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Upgrade to Premium to access ${widget.feature} and unlock unlimited features.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        ValueListenableBuilder<UserSubscription>(
                          valueListenable: appSubscriptionNotifier,
                          builder:
                              (
                                BuildContext context,
                                UserSubscription subscription,
                                _,
                              ) {
                                return _PlanComparison(
                                  plans: _controller.plans,
                                  currentTier: subscription.tier,
                                  selectedTier: _selectedTier,
                                  onSelectTier: (SubscriptionTier tier) {
                                    setState(() => _selectedTier = tier);
                                  },
                                );
                              },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            onPressed: _controller.isActing ? null : _upgrade,
                            child: _controller.isActing
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Upgrade to Premium',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _viewAllPlans,
                          child: const Text('View All Plans'),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PlanComparison extends StatelessWidget {
  const _PlanComparison({
    required this.plans,
    required this.currentTier,
    required this.selectedTier,
    required this.onSelectTier,
  });

  final List<PlanEntity> plans;
  final SubscriptionTier currentTier;
  final SubscriptionTier selectedTier;
  final ValueChanged<SubscriptionTier> onSelectTier;

  @override
  Widget build(BuildContext context) {
    final List<PlanEntity> premiumPlans = plans
        .where((PlanEntity p) => p.tier != SubscriptionTier.free)
        .toList();

    return Column(
      children: <Widget>[
        ...premiumPlans.map(
          (PlanEntity plan) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PlanOptionCard(
              plan: plan,
              isSelected: selectedTier == plan.tier,
              isCurrent: currentTier == plan.tier,
              onTap: () => onSelectTier(plan.tier),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanOptionCard extends StatelessWidget {
  const _PlanOptionCard({
    required this.plan,
    required this.isSelected,
    required this.isCurrent,
    required this.onTap,
  });

  final PlanEntity plan;
  final bool isSelected;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? cs.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? cs.primary : cs.outline,
                  width: 2,
                ),
                color: isSelected ? cs.primary : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(Icons.check, size: 16, color: cs.onPrimary)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        plan.title,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? cs.onPrimaryContainer
                              : cs.onSurface,
                        ),
                      ),
                      if (isCurrent) ...<Widget>[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cs.secondary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Current',
                            style: TextStyle(
                              color: cs.onSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${plan.priceLabel} • ${plan.billingLabel}',
                    style: textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? cs.onPrimaryContainer.withValues(alpha: 0.8)
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
