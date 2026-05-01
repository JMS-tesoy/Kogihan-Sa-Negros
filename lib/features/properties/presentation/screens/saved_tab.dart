import 'package:flutter/material.dart';

import '../../../../core/widgets/app_empty_state.dart';
import '../../../../features/subscription/data/services/subscription_service.dart';
import '../../data/datasources/shared_properties.dart';
import 'property_details_screen.dart';
import '../widgets/property_image.dart';

class SavedTab extends StatelessWidget {
  final List<Property> savedProperties;
  final ValueChanged<Property> onToggleSave;
  final UserSubscription subscription;
  final VoidCallback onOpenSubscription;

  const SavedTab({
    super.key,
    required this.savedProperties,
    required this.onToggleSave,
    required this.subscription,
    required this.onOpenSubscription,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saved Lots',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (!subscription.isPremium) ...[
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.workspace_premium_outlined),
                  title: const Text('Free plan save limit'),
                  subtitle: Text(
                    'Save up to $freeSavedPropertiesLimit lots on Free. Upgrade for unlimited saved listings.',
                  ),
                  trailing: TextButton(
                    onPressed: onOpenSubscription,
                    child: const Text('Upgrade'),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Expanded(
              child: savedProperties.isEmpty
                  ? const EmptyState(
                      icon: Icons.favorite_border_rounded,
                      message: 'No saved lots yet.',
                      subtitle:
                          'Tap the heart on any listing to keep it here for quick access.',
                    )
                  : ListView.separated(
                      itemCount: savedProperties.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final property = savedProperties[index];
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minVerticalPadding: 0,
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 56,
                                height: 56,
                                child: buildPropertyImage(
                                  context: context,
                                  property: property,
                                  height: 56,
                                  useThumbnail: true,
                                  fallbackChild: const Center(
                                    child: Icon(
                                      Icons.landscape_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              property.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  property.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    property.titleStatus,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            trailing: Text(property.price),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => PropertyDetailsScreen(
                                    property: property,
                                    isSaved: true,
                                    onToggleSave: () => onToggleSave(property),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
