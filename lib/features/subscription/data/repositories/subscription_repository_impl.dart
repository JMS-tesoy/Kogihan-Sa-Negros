import '../../domain/entities/plan_entity.dart';
import '../../domain/entities/subscription_entity.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../datasources/subscription_local_datasource.dart';
import '../datasources/subscription_remote_datasource.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  SubscriptionRepositoryImpl({
    SubscriptionRemoteDatasource? remoteDatasource,
    SubscriptionLocalDatasource? localDatasource,
  }) : _remoteDatasource = remoteDatasource ?? SubscriptionRemoteDatasource(),
       _localDatasource = localDatasource ?? SubscriptionLocalDatasource();

  final SubscriptionRemoteDatasource _remoteDatasource;
  final SubscriptionLocalDatasource _localDatasource;

  @override
  Future<List<PlanEntity>> getAvailablePlans() {
    return _remoteDatasource.getAvailablePlans();
  }

  @override
  Future<SubscriptionEntity?> getCurrentSubscription() async {
    final SubscriptionEntity? cached = await _localDatasource
        .getCachedSubscription();
    if (cached != null) return cached;

    final SubscriptionEntity? remote = await _remoteDatasource
        .getCurrentSubscription();
    if (remote != null) {
      await _localDatasource.saveSubscription(remote);
    }
    return remote;
  }

  @override
  Future<void> restoreSubscription() async {
    await _localDatasource.restoreSubscription();
  }

  @override
  Future<void> subscribe(String planId) async {
    final SubscriptionEntity subscription = await _remoteDatasource.subscribe(
      planId,
    );
    await _localDatasource.saveSubscription(subscription);
  }
}
