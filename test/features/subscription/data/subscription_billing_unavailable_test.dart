import 'package:flutter_test/flutter_test.dart';
import 'package:kogihan_sa_negros/features/subscription/data/datasources/subscription_local_datasource.dart';
import 'package:kogihan_sa_negros/features/subscription/data/datasources/subscription_remote_datasource.dart';
import 'package:kogihan_sa_negros/features/subscription/data/services/subscription_service.dart';

void main() {
  test('mock purchase cannot grant a subscription', () async {
    await expectLater(
      SubscriptionRemoteDatasource().subscribe('monthly_plan'),
      throwsUnsupportedError,
    );
    await expectLater(
      SubscriptionService.purchasePlan(SubscriptionTier.monthly),
      throwsUnsupportedError,
    );
  });

  test('mock purchase restore and cancellation fail explicitly', () async {
    await expectLater(
      SubscriptionLocalDatasource().restoreSubscription(),
      throwsUnsupportedError,
    );
    await expectLater(
      SubscriptionService.restorePurchases(),
      throwsUnsupportedError,
    );
    await expectLater(
      SubscriptionService.cancelSubscription(),
      throwsUnsupportedError,
    );
  });
}
