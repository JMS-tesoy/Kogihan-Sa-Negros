import '../models/plan_model.dart';
import '../models/subscription_model.dart';

class SubscriptionRemoteDatasource {
  Future<SubscriptionModel?> getCurrentSubscription() async {
    return null;
  }

  Future<List<PlanModel>> getAvailablePlans() async {
    return const <PlanModel>[];
  }

  Future<void> subscribe(String planId) async {}
}
