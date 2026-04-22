import '../entities/subscription_entity.dart';
import '../repositories/subscription_repository.dart';

class GetCurrentSubscriptionUsecase {
  const GetCurrentSubscriptionUsecase(this.repository);

  final SubscriptionRepository repository;

  Future<SubscriptionEntity?> call() {
    return repository.getCurrentSubscription();
  }
}
