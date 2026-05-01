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
      tier: _tierFromString(map['subscription_tier']),
      status: _statusFromString(map['subscription_status']),
      expiresAt: map['expires_at'] != null
          ? DateTime.tryParse(map['expires_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subscription_tier': tier.name,
      'subscription_status': status.name,
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
    return SubscriptionStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SubscriptionStatus.inactive,
    );
  }
}
