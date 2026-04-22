import '../../../../core/enums/subscription_status.dart';

class SubscriptionEntity {
  const SubscriptionEntity({
    required this.id,
    required this.planId,
    this.status = SubscriptionStatus.inactive,
    this.expiresAt,
  });

  final String id;
  final String planId;
  final SubscriptionStatus status;
  final DateTime? expiresAt;
}
