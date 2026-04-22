import '../../domain/entities/plan_entity.dart';
import '../../domain/entities/subscription_entity.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../datasources/subscription_local_datasource.dart';
import '../datasources/subscription_remote_datasource.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  SubscriptionRepositoryImpl({
    SubscriptionRemoteDatasource? remoteDatasource,
    SubscriptionLocalDatasource? localDatasource,
  })  : _remoteDatasource = remoteDatasource ?? SubscriptionRemoteDatasource(),
        _localDatasource = localDatasource ?? SubscriptionLocalDatasource();

  final SubscriptionRemoteDatasource _remoteDatasource;
  final SubscriptionLocalDatasource _localDatasource;

  @override
  Future<List<PlanEntity>> getAvailablePlans() {
    return _remoteDatasource.getAvailablePlans();
  }

  @override
  Future<SubscriptionEntity?> getCurrentSubscription() {
    return _remoteDatasource.getCurrentSubscription();
  }

  @override
  Future<void> restoreSubscription() {
    return _localDatasource.restoreSubscription();
  }

  @override
  Future<void> subscribe(String planId) {
    return _remoteDatasource.subscribe(planId);
  }
}
