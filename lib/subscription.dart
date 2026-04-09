import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SubscriptionTier { free, monthly, yearly }

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
  final DateTime? expiresAt;

  const UserSubscription({required this.tier, required this.expiresAt});

  const UserSubscription.free()
    : tier = SubscriptionTier.free,
      expiresAt = null;

  bool get isPremium {
    if (tier == SubscriptionTier.free) return false;
    if (expiresAt == null) return true;
    return expiresAt!.isAfter(DateTime.now());
  }

  String get planName => switch (tier) {
    SubscriptionTier.free => 'Free',
    SubscriptionTier.monthly => 'Monthly Premium',
    SubscriptionTier.yearly => 'Yearly Premium',
  };

  UserSubscription copyWith({
    SubscriptionTier? tier,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
  }) {
    return UserSubscription(
      tier: tier ?? this.tier,
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

    return UserSubscription(
      tier: tier,
      expiresAt: tier == SubscriptionTier.free ? null : expiresAt,
    );
  }

  factory UserSubscription.fromProfileMap(Map<String, dynamic> map) {
    final SubscriptionTier tier = _subscriptionTierFromStorage(
      map['subscription_tier']?.toString(),
    );
    final DateTime? expiresAt = _parseDateTime(
      map['subscription_expires_at'] ?? map['expires_at'],
    );

    return UserSubscription(
      tier: tier,
      expiresAt: tier == SubscriptionTier.free ? null : expiresAt,
    );
  }

  static UserSubscription? maybeFromProfileMap(Map<String, dynamic> map) {
    final bool hasTier = map.containsKey('subscription_tier');
    final bool hasExpiry =
        map.containsKey('subscription_expires_at') ||
        map.containsKey('expires_at');
    if (!hasTier && !hasExpiry) return null;
    return UserSubscription.fromProfileMap(map);
  }
}

const List<SubscriptionPlan> subscriptionPlans = [
  SubscriptionPlan(
    tier: SubscriptionTier.free,
    title: 'Free',
    priceLabel: '₱0',
    billingLabel: 'Current starter access',
    features: [
      'Browse property listings',
      'Message agents',
      'Save up to 3 properties',
    ],
  ),
  SubscriptionPlan(
    tier: SubscriptionTier.monthly,
    title: 'Monthly Premium',
    priceLabel: '₱199',
    billingLabel: 'Per month placeholder',
    features: [
      'Unlimited saved properties',
      'Premium-only feature gates',
      'Ready for store billing hookup',
    ],
  ),
  SubscriptionPlan(
    tier: SubscriptionTier.yearly,
    title: 'Yearly Premium',
    priceLabel: '₱1,999',
    billingLabel: 'Per year placeholder',
    features: [
      'Everything in Monthly Premium',
      'Longer subscription window',
      'Best value placeholder plan',
    ],
  ),
];

class SubscriptionService {
  SubscriptionService._();

  static Future<void> initialize() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    appSubscriptionNotifier.value = UserSubscription.fromPreferences(
      preferences,
    );
  }

  static Future<UserSubscription> loadCurrentSubscription() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return UserSubscription.fromPreferences(preferences);
  }

  static Future<UserSubscription> purchasePlan(SubscriptionTier tier) async {
    // INTEGRATION POINT: Replace this local placeholder with Google Play
    // Billing / Apple In-App Purchase purchase handling.
    final UserSubscription subscription = UserSubscription(
      tier: tier,
      expiresAt: switch (tier) {
        SubscriptionTier.free => null,
        SubscriptionTier.monthly => DateTime.now().add(
          const Duration(days: 30),
        ),
        SubscriptionTier.yearly => DateTime.now().add(
          const Duration(days: 365),
        ),
      },
    );

    await _saveSubscription(subscription);
    return subscription;
  }

  static Future<UserSubscription> restorePurchases() async {
    // INTEGRATION POINT: Replace this with real restore logic from the billing
    // SDK once store products are configured.
    final UserSubscription subscription = await loadCurrentSubscription();
    appSubscriptionNotifier.value = subscription;
    return subscription;
  }

  static Future<void> _saveSubscription(UserSubscription subscription) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _subscriptionTierPrefsKey,
      subscription.tier.name,
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
