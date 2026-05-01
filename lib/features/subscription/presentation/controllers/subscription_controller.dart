import 'package:flutter/foundation.dart';

import '../../data/repositories/subscription_repository_impl.dart';
import '../../data/services/subscription_service.dart';
import '../../domain/entities/plan_entity.dart';
import '../../domain/entities/subscription_entity.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../../domain/usecases/get_available_plans_usecase.dart';
import '../../domain/usecases/get_current_subscription_usecase.dart';
import '../../domain/usecases/restore_subscription_usecase.dart';
import '../../domain/usecases/subscribe_usecase.dart';

class SubscriptionController extends ChangeNotifier {
  SubscriptionController({SubscriptionRepository? repository})
    : _getCurrentSubscription = GetCurrentSubscriptionUsecase(
        repository ?? SubscriptionRepositoryImpl(),
      ),
      _getAvailablePlans = GetAvailablePlansUsecase(
        repository ?? SubscriptionRepositoryImpl(),
      ),
      _subscribe = SubscribeUsecase(repository ?? SubscriptionRepositoryImpl()),
      _restore = RestoreSubscriptionUsecase(
        repository ?? SubscriptionRepositoryImpl(),
      );

  final GetCurrentSubscriptionUsecase _getCurrentSubscription;
  final GetAvailablePlansUsecase _getAvailablePlans;
  final SubscribeUsecase _subscribe;
  final RestoreSubscriptionUsecase _restore;

  SubscriptionEntity? _subscription;
  List<PlanEntity> _plans = const <PlanEntity>[];
  bool _isLoading = false;
  bool _isActing = false;
  String? _error;

  SubscriptionEntity? get subscription => _subscription;
  List<PlanEntity> get plans => _plans;
  bool get isLoading => _isLoading;
  bool get isActing => _isActing;
  String? get error => _error;

  bool get isPremium => _subscription?.isPremium ?? false;

  Future<void> init() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await Future.wait(<Future<void>>[_loadSubscription(), _loadPlans()]);
    } catch (_) {
      _error = 'Failed to load subscription. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> subscribe(String planId) async {
    _isActing = true;
    _error = null;
    notifyListeners();
    try {
      await _subscribe.call(planId);
      await _loadSubscription();
      // Sync into global appSubscriptionNotifier so all widgets react
      if (_subscription != null) {
        await SubscriptionService.syncFromEntity(_subscription!);
      }
    } catch (_) {
      _error = 'Purchase failed. Please try again.';
    } finally {
      _isActing = false;
      notifyListeners();
    }
  }

  Future<void> restoreSubscription() async {
    _isActing = true;
    _error = null;
    notifyListeners();
    try {
      await _restore.call();
      await _loadSubscription();
      if (_subscription != null) {
        await SubscriptionService.syncFromEntity(_subscription!);
      }
    } catch (_) {
      _error = 'Restore failed. Please try again.';
    } finally {
      _isActing = false;
      notifyListeners();
    }
  }

  Future<void> cancelSubscription() async {
    _isActing = true;
    _error = null;
    notifyListeners();
    try {
      final UserSubscription cancelled =
          await SubscriptionService.cancelSubscription();
      _subscription = SubscriptionEntity(
        id: _subscription?.id ?? '',
        tier: cancelled.tier,
        expiresAt: cancelled.expiresAt,
      );
    } catch (_) {
      _error = 'Cancellation failed. Please try again.';
    } finally {
      _isActing = false;
      notifyListeners();
    }
  }

  Future<void> _loadSubscription() async {
    _subscription = await _getCurrentSubscription.call();
  }

  Future<void> _loadPlans() async {
    _plans = await _getAvailablePlans.call();
  }
}
