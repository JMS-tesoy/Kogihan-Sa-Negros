import 'package:flutter/material.dart';

import '../../data/datasources/shared_properties.dart';
import 'property_image.dart';

class RecommendedPropertyCard extends StatelessWidget {
  final Property property;
  final bool isSaved;
  final bool isActive;
  final VoidCallback onToggleSave;
  final VoidCallback onOpenDetails;

  const RecommendedPropertyCard({
    super.key,
    required this.property,
    required this.isSaved,
    required this.isActive,
    required this.onToggleSave,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? agentTeamName = property.agentTeamName?.trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: isActive ? 10 : 2,
      shadowColor: theme.colorScheme.shadow.withValues(
        alpha: isActive ? 0.24 : 0.10,
      ),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: InkWell(
        onTap: onOpenDetails,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                buildPropertyDetailsImage(
                  context: context,
                  property: property,
                  height: isActive ? 206 : 152,
                  useThumbnail: true,
                  fallbackChild: const Center(
                    child: Icon(
                      Icons.landscape_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: onToggleSave,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSaved
                            ? Icons.favorite
                            : Icons.favorite_border_rounded,
                        size: 18,
                        color: isSaved ? Colors.red : theme.iconTheme.color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.12,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    property.price,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.place_rounded,
                        size: 14,
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
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isActive &&
                      agentTeamName != null &&
                      agentTeamName.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 13,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            agentTeamName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
