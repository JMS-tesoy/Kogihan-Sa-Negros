import '../../../../core/enums/subscription_status.dart';
import '../../../../core/enums/subscription_tier.dart';

class SubscriptionEntity {
  const SubscriptionEntity({
    required this.id,
    this.tier = SubscriptionTier.free,
    this.status = SubscriptionStatus.inactive,
    this.expiresAt,
  });

  final String id;
  final SubscriptionTier tier;
  final SubscriptionStatus status;
  final DateTime? expiresAt;

  bool get isPremium {
    return isPremiumAt(DateTime.now());
  }

  bool isPremiumAt(DateTime now) {
    if (status != SubscriptionStatus.active) return false;
    if (tier == SubscriptionTier.free) return false;
    final DateTime? expiry = expiresAt;
    return expiry != null && expiry.isAfter(now);
  }

  String get planName => switch (tier) {
    SubscriptionTier.free => 'Free',
    SubscriptionTier.monthly => 'Monthly Premium',
    SubscriptionTier.yearly => 'Yearly Premium',
  };
}
