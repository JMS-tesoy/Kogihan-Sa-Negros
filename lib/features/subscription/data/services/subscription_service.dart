import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/enums/subscription_status.dart';
import '../../../../core/enums/subscription_tier.dart';
import '../../domain/entities/subscription_entity.dart';
import '../repositories/subscription_repository_impl.dart';

export '../../../../core/enums/subscription_tier.dart' show SubscriptionTier;

const int freeSavedPropertiesLimit = 3;

final ValueNotifier<UserSubscription> appSubscriptionNotifier = ValueNotifier(
  const UserSubscription.free(),
);

class SubscriptionPlan {
  final SubscriptionTier tier;
  final String title;
  final String priceLabel;
  final String billingLabel;
  final List<String> features;

  const SubscriptionPlan({
    required this.tier,
    required this.title,
    required this.priceLabel,
    required this.billingLabel,
    required this.features,
  });
}

class UserSubscription {
  final SubscriptionTier tier;
  final SubscriptionStatus status;
  final DateTime? expiresAt;

  const UserSubscription({
    required this.tier,
    this.status = SubscriptionStatus.active,
    required this.expiresAt,
  });

  const UserSubscription.free()
    : tier = SubscriptionTier.free,
      status = SubscriptionStatus.inactive,
      expiresAt = null;

  bool get isPremium {
    if (status != SubscriptionStatus.active) return false;
    if (tier == SubscriptionTier.free) return false;
    final DateTime? expiry = expiresAt;
    return expiry != null && expiry.isAfter(DateTime.now());
  }

  String get planName => switch (tier) {
    SubscriptionTier.free => 'Free',
    SubscriptionTier.monthly => 'Monthly Premium',
    SubscriptionTier.yearly => 'Yearly Premium',
  };

  UserSubscription copyWith({
    SubscriptionTier? tier,
    SubscriptionStatus? status,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
  }) {
    return UserSubscription(
      tier: tier ?? this.tier,
      status: status ?? this.status,
      expiresAt: clearExpiresAt ? null : expiresAt ?? this.expiresAt,
    );
  }

  factory UserSubscription.fromPreferences(SharedPreferences preferences) {
    final SubscriptionTier tier = _subscriptionTierFromStorage(
      preferences.getString(_subscriptionTierPrefsKey),
    );
    final DateTime? expiresAt = _parseDateTime(
      preferences.getString(_subscriptionExpiresAtPrefsKey),
    );
    final SubscriptionStatus status = _subscriptionStatusFromStorage(
      preferences.getString(_subscriptionStatusPrefsKey),
    );
    return UserSubscription(
      tier: tier,
      status: status,
      expiresAt: tier == SubscriptionTier.free ? null : expiresAt,
    );
  }

  factory UserSubscription.fromProfileMap(Map<String, dynamic> map) {
    final SubscriptionTier tier = _subscriptionTierFromStorage(
      map['tier']?.toString() ?? map['subscription_tier']?.toString(),
    );
    final SubscriptionStatus status = _subscriptionStatusFromStorage(
      map['status']?.toString() ?? map['subscription_status']?.toString(),
    );
    final DateTime? expiresAt = _parseDateTime(
      map['subscription_expires_at'] ?? map['expires_at'] ?? map['renewal_at'],
    );
    return UserSubscription(
      tier: tier,
      status: status,
      expiresAt: tier == SubscriptionTier.free ? null : expiresAt,
    );
  }

  static UserSubscription? maybeFromProfileMap(Map<String, dynamic> map) {
    final bool hasTier =
        map.containsKey('tier') || map.containsKey('subscription_tier');
    final bool hasExpiry =
        map.containsKey('subscription_expires_at') ||
        map.containsKey('expires_at');
    if (!hasTier && !hasExpiry) return null;
    return UserSubscription.fromProfileMap(map);
  }

  /// Bridge: convert a [SubscriptionEntity] from the clean-arch layer
  /// into a [UserSubscription] for the notifier.
  factory UserSubscription.fromEntity(SubscriptionEntity entity) {
    return UserSubscription(
      tier: entity.tier,
      status: entity.status,
      expiresAt: entity.expiresAt,
    );
  }
}

const List<SubscriptionPlan> subscriptionPlans = [
  SubscriptionPlan(
    tier: SubscriptionTier.free,
    title: 'Free',
    priceLabel: '₱0',
    billingLabel: 'Current starter access',
    features: ['Browse lot listings', 'Message agents', 'Save up to 3 lots'],
  ),
  SubscriptionPlan(
    tier: SubscriptionTier.monthly,
    title: 'Monthly Premium',
    priceLabel: '₱199',
    billingLabel: 'Per month',
    features: [
      'Unlimited saved lots',
      'Premium-only feature gates',
      'Ready for store billing hookup',
    ],
  ),
  SubscriptionPlan(
    tier: SubscriptionTier.yearly,
    title: 'Yearly Premium',
    priceLabel: '₱1,999',
    billingLabel: 'Per year',
    features: [
      'Everything in Monthly Premium',
      'Longer subscription window',
      'Best value',
    ],
  ),
];

class SubscriptionService {
  SubscriptionService._();

  static Future<void> initialize() async {
    appSubscriptionNotifier.value = const UserSubscription.free();
    try {
      final SubscriptionEntity? subscription =
          await SubscriptionRepositoryImpl().getCurrentSubscription();
      if (subscription != null) {
        await syncFromEntity(subscription);
      } else {
        await clear();
      }
    } catch (error, stackTrace) {
      developer.log(
        'Unable to refresh subscription during app initialization',
        name: 'SubscriptionService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<UserSubscription> loadCurrentSubscription() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return UserSubscription.fromPreferences(preferences);
  }

  /// Called by [SubscriptionController] to push entity changes
  /// into the global notifier so all widgets react immediately.
  static Future<void> syncFromEntity(SubscriptionEntity entity) async {
    final UserSubscription subscription = UserSubscription.fromEntity(entity);
    await _saveSubscription(subscription);
  }

  static Future<void> clear() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.remove(_subscriptionTierPrefsKey);
    await preferences.remove(_subscriptionStatusPrefsKey);
    await preferences.remove(_subscriptionExpiresAtPrefsKey);
    appSubscriptionNotifier.value = const UserSubscription.free();
  }

  static Future<void> _saveSubscription(UserSubscription subscription) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _subscriptionTierPrefsKey,
      subscription.tier.name,
    );
    await preferences.setString(
      _subscriptionStatusPrefsKey,
      subscription.status.name,
    );
    if (subscription.expiresAt == null) {
      await preferences.remove(_subscriptionExpiresAtPrefsKey);
    } else {
      await preferences.setString(
        _subscriptionExpiresAtPrefsKey,
        subscription.expiresAt!.toIso8601String(),
      );
    }
    appSubscriptionNotifier.value = subscription;
  }
}

const String _subscriptionTierPrefsKey = 'subscription_tier';
const String _subscriptionStatusPrefsKey = 'subscription_status';
const String _subscriptionExpiresAtPrefsKey = 'subscription_expires_at';

SubscriptionTier _subscriptionTierFromStorage(String? value) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'monthly':
      return SubscriptionTier.monthly;
    case 'yearly':
      return SubscriptionTier.yearly;
    default:
      return SubscriptionTier.free;
  }
}

DateTime? _parseDateTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

SubscriptionStatus _subscriptionStatusFromStorage(String? value) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'active':
      return SubscriptionStatus.active;
    case 'expired':
      return SubscriptionStatus.expired;
    case 'cancelled':
    case 'canceled':
      return SubscriptionStatus.cancelled;
    case 'paused':
      return SubscriptionStatus.paused;
    default:
      return SubscriptionStatus.inactive;
  }
}
