import '../entities/plan_entity.dart';
import '../repositories/subscription_repository.dart';

class GetAvailablePlansUsecase {
  const GetAvailablePlansUsecase(this.repository);

  final SubscriptionRepository repository;

  Future<List<PlanEntity>> call() {
    return repository.getAvailablePlans();
  }
}
