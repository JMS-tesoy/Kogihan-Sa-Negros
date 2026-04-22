import 'package:flutter/foundation.dart';

import '../../domain/entities/subscription_entity.dart';
import '../../domain/usecases/get_current_subscription_usecase.dart';

class SubscriptionController extends ChangeNotifier {
  SubscriptionController({this.getCurrentSubscriptionUsecase});

  final GetCurrentSubscriptionUsecase? getCurrentSubscriptionUsecase;

  SubscriptionEntity? _subscription;

  SubscriptionEntity? get subscription => _subscription;

  Future<void> load() async {
    _subscription = await getCurrentSubscriptionUsecase?.call();
    notifyListeners();
  }
}
