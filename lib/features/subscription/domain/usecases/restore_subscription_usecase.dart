import '../repositories/subscription_repository.dart';

class RestoreSubscriptionUsecase {
  const RestoreSubscriptionUsecase(this.repository);

  final SubscriptionRepository repository;

  Future<void> call() {
    return repository.restoreSubscription();
  }
}
