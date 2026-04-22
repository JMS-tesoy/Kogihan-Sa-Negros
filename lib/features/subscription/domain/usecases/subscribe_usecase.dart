import '../repositories/subscription_repository.dart';

class SubscribeUsecase {
  const SubscribeUsecase(this.repository);

  final SubscriptionRepository repository;

  Future<void> call(String planId) {
    return repository.subscribe(planId);
  }
}
