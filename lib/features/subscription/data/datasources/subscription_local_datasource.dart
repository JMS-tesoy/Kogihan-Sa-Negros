import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/enums/subscription_status.dart';
import '../../../../core/enums/subscription_tier.dart';
import '../../domain/entities/subscription_entity.dart';

class SubscriptionLocalDatasource {
  static const String _subscriptionKey = 'cached_subscription';

  Future<void> saveSubscription(SubscriptionEntity subscription) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _subscriptionKey,
      jsonEncode(<String, dynamic>{
        'id': subscription.id,
        'subscription_tier': subscription.tier.name,
        'subscription_status': subscription.status.name,
        'expires_at': subscription.expiresAt?.toIso8601String(),
      }),
    );
  }

  Future<SubscriptionEntity?> getCachedSubscription() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? json = prefs.getString(_subscriptionKey);
    if (json == null) return null;

    final Map<String, dynamic> map = jsonDecode(json) as Map<String, dynamic>;

    final SubscriptionTier tier = SubscriptionTier.values.firstWhere(
      (e) => e.name == map['subscription_tier'],
      orElse: () => SubscriptionTier.free,
    );
    final SubscriptionStatus status = SubscriptionStatus.values.firstWhere(
      (e) => e.name == map['subscription_status'],
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
  }

  Future<void> clearCache() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_subscriptionKey);
  }

  Future<void> restoreSubscription() async {}
}
