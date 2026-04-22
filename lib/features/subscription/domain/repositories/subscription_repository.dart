import '../entities/plan_entity.dart';
import '../entities/subscription_entity.dart';

abstract interface class SubscriptionRepository {
  Future<SubscriptionEntity?> getCurrentSubscription();

  Future<List<PlanEntity>> getAvailablePlans();

  Future<void> subscribe(String planId);

  Future<void> restoreSubscription();
}
