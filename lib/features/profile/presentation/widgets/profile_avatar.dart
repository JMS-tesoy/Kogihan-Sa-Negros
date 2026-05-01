import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../subscription/data/services/subscription_service.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.imageUrl = '', this.radius = 40});

  final String imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool hasImage = imageUrl.isNotEmpty;

    return ValueListenableBuilder<UserSubscription>(
      valueListenable: appSubscriptionNotifier,
      builder: (BuildContext context, UserSubscription subscription, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                CircleAvatar(
                  radius: radius,
                  backgroundColor: cs.primaryContainer,
                  backgroundImage: hasImage
                      ? CachedNetworkImageProvider(imageUrl)
                      : null,
                  child: hasImage
                      ? null
                      : Icon(
                          Icons.person,
                          size: radius,
                          color: cs.onPrimaryContainer,
                        ),
                ),
                if (subscription.isPremium)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.surface, width: 2),
                      ),
                      child: Icon(
                        Icons.workspace_premium_rounded,
                        size: 16,
                        color: cs.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
            if (subscription.isPremium) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[cs.primary, cs.secondary],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.workspace_premium_rounded,
                      size: 14,
                      color: cs.onPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Premium',
                      style: TextStyle(
                        color: cs.onPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
