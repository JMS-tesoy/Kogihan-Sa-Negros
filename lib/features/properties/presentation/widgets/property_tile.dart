import 'package:flutter/material.dart';

import '../../data/datasources/shared_properties.dart';
import 'property_image.dart';

class PropertyTile extends StatelessWidget {
  final Property property;
  final bool isSaved;
  final VoidCallback onToggleSave;
  final VoidCallback onOpenDetails;

  const PropertyTile({
    super.key,
    required this.property,
    required this.isSaved,
    required this.onToggleSave,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String availabilityLabel = _propertyAvailabilityLabel(property);
    final Color availabilityColor = _propertyAvailabilityColor(
      context,
      availabilityLabel,
    );
    const double tileHeight = 118;
    const double tileRadius = 18;

    Widget metaChip(IconData icon, String label) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 112),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget availabilityChip() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: availabilityColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _propertyAvailabilityIcon(availabilityLabel),
              size: 14,
              color: availabilityColor,
            ),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 82),
              child: Text(
                availabilityLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: availabilityColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(tileRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            spreadRadius: 1,
            offset: Offset(0, 8),
          ),
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 7,
            spreadRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: theme.colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tileRadius),
          side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
        ),
        child: InkWell(
          onTap: onOpenDetails,
          child: SizedBox(
            height: tileHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double thumbnailWidth = constraints.maxWidth * 0.30;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: thumbnailWidth,
                          height: tileHeight,
                          child: buildPropertyDetailsImage(
                            context: context,
                            property: property,
                            height: tileHeight,
                            useThumbnail: true,
                            fallbackChild: const Center(
                              child: Icon(
                                Icons.landscape_rounded,
                                color: Colors.white,
                                size: 34,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    property.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          height: 1.15,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  tooltip: isSaved
                                      ? 'Remove from saved'
                                      : 'Save lot',
                                  onPressed: onToggleSave,
                                  style: IconButton.styleFrom(
                                    backgroundColor: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    foregroundColor: isSaved
                                        ? Colors.red
                                        : theme.iconTheme.color,
                                    fixedSize: const Size(28, 28),
                                    minimumSize: const Size(28, 28),
                                    padding: EdgeInsets.zero,
                                  ),
                                  icon: Icon(
                                    isSaved
                                        ? Icons.favorite
                                        : Icons.favorite_border_rounded,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 15,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    property.location,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    property.price,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                availabilityChip(),
                                const SizedBox(width: 6),
                                metaChip(
                                  Icons.square_foot_outlined,
                                  property.size,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

String _propertyAvailabilityLabel(Property property) {
  final String tag = property.tag.trim().toLowerCase();
  if (tag.contains('sold')) return 'Sold';
  if (tag.contains('auction')) return 'For Auction';
  return 'Available';
}

IconData _propertyAvailabilityIcon(String label) {
  switch (label) {
    case 'Sold':
      return Icons.task_alt_rounded;
    case 'For Auction':
      return Icons.gavel_rounded;
    default:
      return Icons.check_circle_outline_rounded;
  }
}

Color _propertyAvailabilityColor(BuildContext context, String label) {
  final ColorScheme colorScheme = Theme.of(context).colorScheme;
  switch (label) {
    case 'Sold':
      return colorScheme.error;
    case 'For Auction':
      return const Color(0xFFF59E0B);
    default:
      return colorScheme.primary;
  }
}
