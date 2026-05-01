import '../../../../core/enums/subscription_status.dart';
import '../../../../core/enums/subscription_tier.dart';
import '../models/plan_model.dart';
import '../models/subscription_model.dart';

class SubscriptionRemoteDatasource {
  Future<SubscriptionModel?> getCurrentSubscription() async {
    // In a real app, fetch from Supabase/Backend
    return null;
  }

  Future<List<PlanModel>> getAvailablePlans() async {
    // These match the ones in the old SubscriptionService
    return [
      const PlanModel(
        id: 'free_plan',
        tier: SubscriptionTier.free,
        title: 'Free',
        priceLabel: '₱0',
        billingLabel: 'Current starter access',
        features: [
          'Browse lot listings',
          'Message agents',
          'Save up to 3 lots',
        ],
      ),
      const PlanModel(
        id: 'monthly_plan',
        tier: SubscriptionTier.monthly,
        title: 'Monthly Premium',
        priceLabel: '₱199',
        billingLabel: 'Per month',
        features: [
          'Unlimited saved lots',
          'Premium-only feature gates',
          'Ready for store billing hookup',
        ],
      ),
      const PlanModel(
        id: 'yearly_plan',
        tier: SubscriptionTier.yearly,
        title: 'Yearly Premium',
        priceLabel: '₱1,999',
        billingLabel: 'Per year',
        features: [
          'Everything in Monthly Premium',
          'Longer subscription window',
          'Best value',
        ],
      ),
    ];
  }

  Future<SubscriptionModel> subscribe(String planId) async {
    // Mock subscription logic
    final tier = planId == 'yearly_plan'
        ? SubscriptionTier.yearly
        : planId == 'monthly_plan'
        ? SubscriptionTier.monthly
        : SubscriptionTier.free;

    return SubscriptionModel(
      id: 'sub_mock_${DateTime.now().millisecondsSinceEpoch}',
      tier: tier,
      status: SubscriptionStatus.active,
      expiresAt: tier == SubscriptionTier.free
          ? null
          : DateTime.now().add(
              Duration(days: tier == SubscriptionTier.yearly ? 365 : 30),
            ),
    );
  }
}
