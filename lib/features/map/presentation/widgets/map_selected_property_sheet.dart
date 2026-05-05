import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/router/instant_route.dart';
import '../../../properties/data/datasources/shared_properties.dart';
import '../../../properties/presentation/screens/property_details_screen.dart';
import '../../../properties/presentation/widgets/property_image.dart';

class MapSelectedPropertySheet extends StatelessWidget {
  final Property property;
  final bool isSaved;
  final bool hasBoundary;
  final bool isLoadingElevation;
  final double? elevationMeters;
  final VoidCallback onToggleSave;

  const MapSelectedPropertySheet({
    super.key,
    required this.property,
    required this.isSaved,
    required this.hasBoundary,
    required this.isLoadingElevation,
    required this.elevationMeters,
    required this.onToggleSave,
  });

  void _openDetails(BuildContext context) {
    unawaited(precachePropertyImage(context, property, height: 300));
    Navigator.push(
      context,
      instantRoute(
        PropertyDetailsScreen(
          property: property,
          isSaved: isSaved,
          onToggleSave: onToggleSave,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String description = property.description.trim().isEmpty
        ? 'No description available for this lot yet.'
        : property.description;
    final String elevationLabel = isLoadingElevation
        ? 'Elevation loading'
        : elevationMeters == null
        ? 'Elevation unavailable'
        : 'Elevation ~${elevationMeters!.round()} m';
    final double cardWidth = math.min(
      390.0,
      math.max(280.0, MediaQuery.sizeOf(context).width - 32),
    );
    final double cardHeight = math.min(
      420.0,
      math.max(370.0, MediaQuery.sizeOf(context).height * 0.60),
    );
    final double thumbnailSize = math.min(
      136.0,
      math.max(120.0, cardWidth * 0.36),
    );

    return SizedBox(
      width: cardWidth,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: cardHeight,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: thumbnailSize,
                      height: thumbnailSize,
                      child: buildPropertyImage(
                        context: context,
                        property: property,
                        height: thumbnailSize,
                        borderRadius: BorderRadius.circular(14),
                        fallbackChild: const Center(
                          child: Icon(
                            Icons.landscape_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            property.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            property.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            property.price,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _MapPropertyInfoChip(
                                icon: Icons.square_foot_rounded,
                                label: property.size,
                              ),
                              _MapPropertyInfoChip(
                                icon: Icons.verified_outlined,
                                label: property.titleStatus,
                              ),
                              _MapPropertyInfoChip(
                                icon: Icons.landscape_rounded,
                                label: elevationLabel,
                              ),
                              _MapPropertyInfoChip(
                                icon: Icons.polyline_outlined,
                                label: hasBoundary
                                    ? 'Boundary shown'
                                    : 'No boundary',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _openDetails(context),
                  icon: const Icon(Icons.open_in_new_rounded, size: 17),
                  label: const Text('View Details'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapPropertyInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MapPropertyInfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.78,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
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
}
