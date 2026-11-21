import 'package:flutter_test/flutter_test.dart';
import 'package:kogihan_sa_negros/core/enums/subscription_status.dart';
import 'package:kogihan_sa_negros/core/enums/subscription_tier.dart';
import 'package:kogihan_sa_negros/features/subscription/data/models/subscription_model.dart';
import 'package:kogihan_sa_negros/features/subscription/domain/entities/subscription_entity.dart';

void main() {
  group('SubscriptionModel.fromMap', () {
    test('maps the database subscription contract', () {
      final SubscriptionModel model = SubscriptionModel.fromMap(
        <String, dynamic>{
          'id': 'subscription-1',
          'tier': 'monthly',
          'status': 'active',
          'expires_at': '2030-01-01T00:00:00.000Z',
        },
      );

      expect(model.tier, SubscriptionTier.monthly);
      expect(model.status, SubscriptionStatus.active);
      expect(model.expiresAt, DateTime.utc(2030));
      expect(model.toMap()['tier'], 'monthly');
      expect(model.toMap()['status'], 'active');
    });

    test('accepts renewal_at during the compatibility migration', () {
      final SubscriptionModel model = SubscriptionModel.fromMap(
        <String, dynamic>{
          'id': 'subscription-1',
          'tier': 'yearly',
          'status': 'cancelled',
          'renewal_at': '2030-01-01T00:00:00.000Z',
        },
      );

      expect(model.tier, SubscriptionTier.yearly);
      expect(model.status, SubscriptionStatus.cancelled);
      expect(model.expiresAt, DateTime.utc(2030));
    });

    test('unknown values fail closed', () {
      final SubscriptionModel model = SubscriptionModel.fromMap(
        <String, dynamic>{
          'id': 'subscription-1',
          'tier': 'unknown',
          'status': 'unknown',
          'expires_at': 'not-a-date',
        },
      );

      expect(model.tier, SubscriptionTier.free);
      expect(model.status, SubscriptionStatus.inactive);
      expect(model.expiresAt, isNull);
      expect(model.isPremium, isFalse);
    });
  });

  group('SubscriptionEntity.isPremiumAt', () {
    const String id = 'subscription-1';
    final DateTime now = DateTime.utc(2026, 11, 18);

    test('requires an active, paid, unexpired subscription', () {
      final SubscriptionEntity entitlement = SubscriptionEntity(
        id: id,
        tier: SubscriptionTier.monthly,
        status: SubscriptionStatus.active,
        expiresAt: now.add(const Duration(days: 1)),
      );

      expect(entitlement.isPremiumAt(now), isTrue);
      expect(
        entitlement.isPremiumAt(now.add(const Duration(days: 2))),
        isFalse,
      );
    });

    test('a paid tier without active status is not premium', () {
      for (final SubscriptionStatus status in <SubscriptionStatus>[
        SubscriptionStatus.inactive,
        SubscriptionStatus.expired,
        SubscriptionStatus.cancelled,
        SubscriptionStatus.paused,
      ]) {
        final SubscriptionEntity entitlement = SubscriptionEntity(
          id: id,
          tier: SubscriptionTier.yearly,
          status: status,
          expiresAt: now.add(const Duration(days: 30)),
        );

        expect(entitlement.isPremiumAt(now), isFalse, reason: '$status');
      }
    });

    test('a paid tier without a server expiry is not premium', () {
      const SubscriptionEntity entitlement = SubscriptionEntity(
        id: id,
        tier: SubscriptionTier.monthly,
        status: SubscriptionStatus.active,
      );

      expect(entitlement.isPremiumAt(now), isFalse);
    });
  });
}
