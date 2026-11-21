import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/enums/subscription_status.dart';
import '../../../../core/enums/subscription_tier.dart';
import '../../domain/entities/subscription_entity.dart';

class SubscriptionLocalDatasource {
  static const String _subscriptionKeyPrefix = 'cached_subscription_';
  static const Duration maximumCacheAge = Duration(hours: 24);

  Future<void> saveSubscription(
    String userId,
    SubscriptionEntity subscription,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_subscriptionKeyPrefix$userId',
      jsonEncode(<String, dynamic>{
        'id': subscription.id,
        'tier': subscription.tier.name,
        'status': subscription.status.name,
        'expires_at': subscription.expiresAt?.toIso8601String(),
        'cached_at': DateTime.now().toUtc().toIso8601String(),
        'verified_by_server': true,
      }),
    );
  }

  Future<SubscriptionEntity?> getCachedSubscription(String userId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? json = prefs.getString('$_subscriptionKeyPrefix$userId');
    if (json == null) return null;

    try {
      final Map<String, dynamic> map =
          jsonDecode(json) as Map<String, dynamic>;
      final DateTime? cachedAt = DateTime.tryParse(
        map['cached_at']?.toString() ?? '',
      );
      if (map['verified_by_server'] != true ||
          cachedAt == null ||
          DateTime.now().toUtc().difference(cachedAt) > maximumCacheAge) {
        return null;
      }

      final SubscriptionTier tier = SubscriptionTier.values.firstWhere(
        (e) => e.name == map['tier'],
        orElse: () => SubscriptionTier.free,
      );
      final SubscriptionStatus status = SubscriptionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => SubscriptionStatus.inactive,
      );
      final DateTime? expiresAt = map['expires_at'] != null
          ? DateTime.tryParse(map['expires_at'].toString())
          : null;

      return SubscriptionEntity(
        id: map['id'] as String? ?? '',
        tier: tier,
        status: status,
        expiresAt: expiresAt,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> clearCache(String userId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_subscriptionKeyPrefix$userId');
  }
}
