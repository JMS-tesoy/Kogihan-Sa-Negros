import '../../../../core/enums/subscription_tier.dart';
import '../../domain/entities/plan_entity.dart';

class PlanModel extends PlanEntity {
  const PlanModel({
    required super.id,
    required super.tier,
    required super.title,
    required super.priceLabel,
    required super.billingLabel,
    required super.features,
  });

  factory PlanModel.fromMap(Map<String, dynamic> map) {
    return PlanModel(
      id: map['id'] ?? '',
      tier: _tierFromString(map['tier']),
      title: map['title'] ?? '',
      priceLabel: map['price_label'] ?? '',
      billingLabel: map['billing_label'] ?? '',
      features: List<String>.from(map['features'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tier': tier.name,
      'title': title,
      'price_label': priceLabel,
      'billing_label': billingLabel,
      'features': features,
    };
  }

  static SubscriptionTier _tierFromString(String? value) {
    return SubscriptionTier.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SubscriptionTier.free,
    );
  }
}
