import '../../domain/entities/profile_entity.dart';
import '../../../subscription/data/services/subscription_service.dart';

class ProfileModel extends ProfileEntity {
  const ProfileModel({
    required super.id,
    required super.name,
    required super.email,
    super.phone,
    super.avatarUrl,
  });
}

class BuyerProfileData {
  final String displayName;
  final String email;
  final String phone;
  final String? avatarUrl;
  final UserSubscription subscription;

  const BuyerProfileData({
    required this.displayName,
    required this.email,
    required this.phone,
    required this.avatarUrl,
    required this.subscription,
  });

  bool get isPremium => subscription.isPremium;
  String get planName => subscription.planName;
  DateTime? get expiresAt => subscription.expiresAt;

  BuyerProfileData copyWith({
    String? displayName,
    String? email,
    String? phone,
    String? avatarUrl,
    UserSubscription? subscription,
  }) {
    return BuyerProfileData(
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      subscription: subscription ?? this.subscription,
    );
  }
}
