import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../messaging/data/services/messaging_service.dart';
import '../../../subscription/data/services/subscription_service.dart';
import '../../presentation/widgets/profile_formatters.dart';
import '../models/profile_model.dart';

const BuyerProfileData defaultBuyerProfileData = BuyerProfileData(
  displayName: 'Buyer',
  email: 'No email available',
  phone: 'No phone available',
  avatarUrl: null,
  subscription: UserSubscription.free(),
);

Future<BuyerProfileData> loadCurrentBuyerProfileData() async {
  final User? user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    return defaultBuyerProfileData;
  }

  final UserSubscription localSubscription =
      await SubscriptionService.loadCurrentSubscription();

  try {
    final MessagingProfile? profile =
        await MessagingService.fetchCurrentProfile();
    final String profileName = profileTextValue(profile?.fullName);
    final String metadataName = profileTextValue(
      user.userMetadata?['full_name'] ?? user.userMetadata?['name'],
    );
    final String displayName = profileName.isNotEmpty
        ? profileName
        : metadataName.isNotEmpty
        ? metadataName
        : profileTextValue(user.email).isNotEmpty
        ? profileTextValue(user.email)
        : profileTextValue(user.phone).isNotEmpty
        ? profileTextValue(user.phone)
        : 'Buyer';
    final String email = profileTextValue(profile?.email).isNotEmpty
        ? profileTextValue(profile?.email)
        : profileTextValue(user.email);
    final String phone = profileTextValue(profile?.phone).isNotEmpty
        ? profileTextValue(profile?.phone)
        : profileTextValue(user.phone);
    final UserSubscription subscription =
        profile?.subscription ?? localSubscription;
    final String avatarUrl = profileTextValue(
      profile?.avatarUrl ?? user.userMetadata?['avatar_url'],
    );

    return BuyerProfileData(
      displayName: displayName,
      email: email.isNotEmpty ? email : 'No email available',
      phone: phone.isNotEmpty ? phone : 'No phone available',
      avatarUrl: avatarUrl.isEmpty ? null : avatarUrl,
      subscription: subscription,
    );
  } catch (_) {
    final String metadataName = profileTextValue(
      user.userMetadata?['full_name'] ?? user.userMetadata?['name'],
    );
    final String email = profileTextValue(user.email);
    final String phone = profileTextValue(user.phone);
    final String avatarUrl = profileTextValue(user.userMetadata?['avatar_url']);

    return BuyerProfileData(
      displayName: metadataName.isNotEmpty
          ? metadataName
          : email.isNotEmpty
          ? email
          : phone.isNotEmpty
          ? phone
          : 'Buyer',
      email: email.isNotEmpty ? email : 'No email available',
      phone: phone.isNotEmpty ? phone : 'No phone available',
      avatarUrl: avatarUrl.isEmpty ? null : avatarUrl,
      subscription: localSubscription,
    );
  }
}

BuyerProfileData resolveBuyerProfileData(
  BuyerProfileData? profile,
  UserSubscription currentSubscription,
) {
  final BuyerProfileData baseProfile = profile ?? defaultBuyerProfileData;
  final bool hasLocalSubscriptionData =
      currentSubscription.tier != SubscriptionTier.free ||
      currentSubscription.expiresAt != null;

  return baseProfile.copyWith(
    subscription: hasLocalSubscriptionData
        ? currentSubscription
        : baseProfile.subscription,
  );
}

Future<void> syncSubscriptionFromCurrentProfile() async {
  final UserSubscription currentSubscription = appSubscriptionNotifier.value;
  final bool hasLocalSubscriptionData =
      currentSubscription.tier != SubscriptionTier.free ||
      currentSubscription.expiresAt != null;
  if (hasLocalSubscriptionData) return;

  try {
    final MessagingProfile? profile =
        await MessagingService.fetchCurrentProfile();
    if (profile?.subscription == null) return;
    appSubscriptionNotifier.value = profile!.subscription!;
  } catch (_) {}
}
