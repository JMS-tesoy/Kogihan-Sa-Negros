import 'package:flutter/material.dart';

class MapPropertyCountBadge extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const MapPropertyCountBadge({
    super.key,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    const List<Shadow> floatingShadows = [
      Shadow(blurRadius: 10, offset: Offset(0, 4), color: Color(0x99000000)),
      Shadow(blurRadius: 3, offset: Offset(0, 1), color: Color(0x66000000)),
    ];

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.landscape_rounded,
              size: 16,
              color: theme.colorScheme.primary,
              shadows: floatingShadows,
            ),
            const SizedBox(width: 6),
            Text(
              '$count lot${count == 1 ? '' : 's'} available',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                shadows: floatingShadows,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
