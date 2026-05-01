import '../../../../core/enums/subscription_tier.dart';

class PlanEntity {
  const PlanEntity({
    required this.id,
    required this.tier,
    required this.title,
    required this.priceLabel,
    required this.billingLabel,
    required this.features,
  });

  final String id;
  final SubscriptionTier tier;
  final String title;
  final String priceLabel;
  final String billingLabel;
  final List<String> features;
}
