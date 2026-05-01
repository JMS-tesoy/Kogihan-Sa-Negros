import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatters.dart';
import '../../data/datasources/shared_properties.dart';
import 'property_image.dart';

class RecommendedPropertyCard extends StatelessWidget {
  final Property property;
  final bool isSaved;
  final bool isActive;
  final VoidCallback onToggleSave;
  final VoidCallback onOpenDetails;
  final double activeImageHeight;
  final double inactiveImageHeight;

  const RecommendedPropertyCard({
    super.key,
    required this.property,
    required this.isSaved,
    required this.isActive,
    required this.onToggleSave,
    required this.onOpenDetails,
    required this.activeImageHeight,
    required this.inactiveImageHeight,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? agentTeamName = property.agentTeamName?.trim();
    final String availabilityLabel = _propertyAvailabilityLabel(property);
    final Color availabilityColor = _propertyAvailabilityColor(
      availabilityLabel,
    );

    final double preferredImageHeight = isActive
        ? activeImageHeight
        : inactiveImageHeight;

    final double imageHeight = preferredImageHeight
        .clamp(isActive ? 210.0 : 198.0, isActive ? 230.0 : 218.0)
        .toDouble();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      clipBehavior: Clip.antiAlias,
      elevation: isActive ? 12 : 4,
      shadowColor: Colors.black.withValues(alpha: isActive ? 0.32 : 0.18),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.14)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onOpenDetails,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Hero(
                  tag: 'property_image_${property.id}',
                  child: buildPropertyDetailsImage(
                    context: context,
                    property: property,
                    height: imageHeight,
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
                Positioned(
                  top: 12,
                  right: 12,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: onToggleSave,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          isSaved ? Icons.favorite : Icons.favorite_border,
                          size: 20,
                          color: isSaved ? Colors.redAccent : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: availabilityColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _propertyAvailabilityIcon(availabilityLabel),
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          availabilityLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatters.phpFull(property.priceValue),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (agentTeamName != null && agentTeamName.isNotEmpty) ...[
                      const Spacer(),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 32),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.45,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.22,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shield_rounded,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Listed By ${_titleCase(agentTeamName)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else
                      const Spacer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _propertyAvailabilityLabel(Property property) {
    final String tag = property.tag.trim().toLowerCase();
    if (tag.contains('sold')) return 'SOLD';
    if (tag.contains('auction')) return 'AUCTION';
    return 'AVAILABLE';
  }

  IconData _propertyAvailabilityIcon(String label) {
    switch (label) {
      case 'SOLD':
        return Icons.verified_rounded;
      case 'AUCTION':
        return Icons.gavel_rounded;
      default:
        return Icons.check_circle_rounded;
    }
  }

  Color _propertyAvailabilityColor(String label) {
    switch (label) {
      case 'SOLD':
        return const Color(0xFFEF4444);
      case 'AUCTION':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF10B981);
    }
  }

  String _titleCase(String value) {
    return value
        .split(' ')
        .where((word) => word.trim().isNotEmpty)
        .map((word) {
          final String cleanWord = word.trim();

          if (cleanWord.length == 1) {
            return cleanWord.toUpperCase();
          }

          return cleanWord[0].toUpperCase() + cleanWord.substring(1);
        })
        .join(' ');
  }
}
