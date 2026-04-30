import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/router/route_names.dart';
import '../../../settings/presentation/screens/settings_page.dart';
import '../../../subscription/data/services/subscription_service.dart';
import '../../../subscription/presentation/screens/subscription_screen.dart';
import '../../data/models/profile_model.dart';
import '../../data/services/buyer_profile_service.dart';
import '../widgets/profile_formatters.dart';
import 'account_page.dart';

class ProfileTab extends StatefulWidget {
  final Uint8List? profileImageBytes;
  final bool profileAvatarHidden;
  final VoidCallback onAvatarTap;
  final Future<void> Function(BuildContext context) onLogout;
  final ValueChanged<bool>? onRemoteAvatarAvailableChanged;

  const ProfileTab({
    super.key,
    required this.profileImageBytes,
    required this.profileAvatarHidden,
    required this.onAvatarTap,
    required this.onLogout,
    this.onRemoteAvatarAvailableChanged,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late final Future<BuyerProfileData> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfileAndPrecacheAvatar();
  }

  Future<BuyerProfileData> _loadProfileAndPrecacheAvatar() async {
    final BuyerProfileData profile = await loadCurrentBuyerProfileData();
    final String avatarUrl = (profile.avatarUrl ?? '').trim();
    if (mounted &&
        !widget.profileAvatarHidden &&
        widget.profileImageBytes == null &&
        avatarUrl.isNotEmpty) {
      try {
        await precacheImage(CachedNetworkImageProvider(avatarUrl), context);
      } catch (_) {}
    }
    return profile;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder<UserSubscription>(
        valueListenable: appSubscriptionNotifier,
        builder: (context, currentSubscription, child) {
          return FutureBuilder<BuyerProfileData>(
            future: _profileFuture,
            builder: (context, snapshot) {
              final BuyerProfileData profile = resolveBuyerProfileData(
                snapshot.data,
                currentSubscription,
              );
              final String avatarUrl = (profile.avatarUrl ?? '').trim();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                widget.onRemoteAvatarAvailableChanged?.call(
                  !widget.profileAvatarHidden &&
                      widget.profileImageBytes == null &&
                      avatarUrl.isNotEmpty,
                );
              });
              final ImageProvider<Object>? avatarImageProvider =
                  widget.profileImageBytes != null
                  ? MemoryImage(widget.profileImageBytes!)
                  : !widget.profileAvatarHidden && avatarUrl.isNotEmpty
                  ? CachedNetworkImageProvider(avatarUrl)
                  : null;

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GestureDetector(
                          onTap: widget.onAvatarTap,
                          child: CircleAvatar(
                            radius: 48,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            backgroundImage: avatarImageProvider,
                            child: avatarImageProvider == null
                                ? const Icon(
                                    Icons.person,
                                    size: 50,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: GestureDetector(
                            onTap: widget.onAvatarTap,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).scaffoldBackgroundColor,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.edit,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      profile.displayName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Real Estate Buyer Profile',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: const Text('Account'),
                        subtitle: const Text('Personal contact details'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AccountPage(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.workspace_premium_outlined),
                        title: const Text('Subscription'),
                        subtitle: Text(
                          profile.isPremium
                              ? '${profile.planName} until ${formatSubscriptionDate(profile.expiresAt)}'
                              : 'Current plan: ${profile.planName}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SubscriptionPage(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.groups_outlined),
                        title: const Text('Agent Teams'),
                        subtitle: const Text('View and request to join teams'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).pushNamed(
                            RouteNames.agentTeams,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.settings_outlined),
                        title: const Text('Settings'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettingsPage(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: const Text('Log Out'),
                        textColor: Colors.red,
                        onTap: () async {
                          await widget.onLogout(context);
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
