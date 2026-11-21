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
    final String? userId = _remoteDatasource.currentUserId;
    if (userId == null) return null;

    try {
      final SubscriptionEntity? remote = await _remoteDatasource
          .getCurrentSubscription();
      if (remote != null) {
        await _localDatasource.saveSubscription(userId, remote);
      } else {
        await _localDatasource.clearCache(userId);
      }
      return remote;
    } catch (_) {
      final SubscriptionEntity? cached = await _localDatasource
          .getCachedSubscription(userId);
      if (cached != null && cached.isPremium) {
        return cached;
      }
      rethrow;
    }
  }

  @override
  Future<void> restoreSubscription() async {
    await getCurrentSubscription();
  }

  @override
  Future<void> subscribe(String planId) async {
    throw UnsupportedError(
      'Use the store purchase flow to subscribe to $planId.',
    );
  }
}
