import 'package:flutter_test/flutter_test.dart';
import 'package:kogihan_sa_negros/core/enums/subscription_status.dart';
import 'package:kogihan_sa_negros/core/enums/subscription_tier.dart';
import 'package:kogihan_sa_negros/features/subscription/data/datasources/subscription_local_datasource.dart';
import 'package:kogihan_sa_negros/features/subscription/domain/entities/subscription_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('cache is isolated by authenticated user', () async {
    final SubscriptionLocalDatasource datasource =
        SubscriptionLocalDatasource();
    const SubscriptionEntity firstUser = SubscriptionEntity(
      id: 'subscription-1',
      tier: SubscriptionTier.monthly,
      status: SubscriptionStatus.active,
    );

    await datasource.saveSubscription('user-1', firstUser);

    final SubscriptionEntity? stored = await datasource.getCachedSubscription(
      'user-1',
    );
    final SubscriptionEntity? otherUser = await datasource
        .getCachedSubscription('user-2');
    expect(stored?.id, 'subscription-1');
    expect(otherUser, isNull);
  });

  test('malformed or unverified cache is rejected', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'cached_subscription_user-1': '{"tier":"yearly"}',
    });
    final SubscriptionLocalDatasource datasource =
        SubscriptionLocalDatasource();

    expect(await datasource.getCachedSubscription('user-1'), isNull);
  });
}
