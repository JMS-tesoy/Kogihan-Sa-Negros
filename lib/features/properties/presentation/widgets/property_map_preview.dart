import 'package:flutter/material.dart';

class PropertyMapPreview extends StatelessWidget {
  const PropertyMapPreview({super.key, this.boundaryCoordinates});

  final String? boundaryCoordinates;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 180,
      width: double.infinity,
      color: colorScheme.surfaceContainerHighest,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Icon(
            Icons.map_outlined,
            size: 56,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.location_on,
                size: 32,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.1),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Text(
                  'Map coming soon',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}