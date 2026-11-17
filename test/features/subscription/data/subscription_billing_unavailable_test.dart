import 'package:flutter_test/flutter_test.dart';
import 'package:kogihan_sa_negros/features/subscription/data/datasources/subscription_local_datasource.dart';

void main() {
  test('local datasource throws for unimplemented methods', () async {
    final localDs = SubscriptionLocalDatasource();
    
    await expectLater(
      localDs.restoreSubscription(),
      throwsUnsupportedError,
    );
  });
}
