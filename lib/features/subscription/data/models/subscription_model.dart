import '../../../../core/enums/subscription_status.dart';
import '../../../../core/enums/subscription_tier.dart';
import '../../domain/entities/subscription_entity.dart';

class SubscriptionModel extends SubscriptionEntity {
  const SubscriptionModel({
    required super.id,
    super.tier,
    super.status,
    super.expiresAt,
  });

  factory SubscriptionModel.fromMap(Map<String, dynamic> map) {
    return SubscriptionModel(
      id: map['id'] ?? '',
      tier: _tierFromString(
        map['tier']?.toString() ?? map['subscription_tier']?.toString(),
      ),
      status: _statusFromString(
        map['status']?.toString() ?? map['subscription_status']?.toString(),
      ),
      expiresAt: _dateTimeFromMap(map),
    );
  }

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel.fromMap(json);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tier': tier.name,
      'status': status.name,
      'expires_at': expiresAt?.toIso8601String(),
    };
  }

  static SubscriptionTier _tierFromString(String? value) {
    return SubscriptionTier.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SubscriptionTier.free,
    );
  }

  static SubscriptionStatus _statusFromString(String? value) {
    switch (value?.trim().toLowerCase()) {
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

  static DateTime? _dateTimeFromMap(Map<String, dynamic> map) {
    final Object? value = map['expires_at'] ?? map['renewal_at'];
    return value == null ? null : DateTime.tryParse(value.toString());
  }
}
