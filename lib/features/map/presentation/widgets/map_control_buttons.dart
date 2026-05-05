import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

class MapControlButtons extends StatelessWidget {
  final Future<void> Function() onZoomIn;
  final Future<void> Function() onZoomOut;
  final Future<void> Function() onResetNorth;
  final Future<void> Function() onFitAll;
  final Future<void> Function() onMyLocation;
  final bool isLocationEnabled;

  const MapControlButtons({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetNorth,
    required this.onFitAll,
    required this.onMyLocation,
    required this.isLocationEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            blurRadius: 38,
            offset: Offset(0, 22),
            color: Color(0x42000000),
          ),
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 6),
            color: Color(0x24000000),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.32),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapIconButton(icon: Icons.add, onTap: onZoomIn),
                _MapDivider(color: theme.dividerColor),
                _MapIconButton(icon: Icons.remove, onTap: onZoomOut),
                _MapDivider(color: theme.dividerColor),
                _MapIconButton(
                  icon: Icons.navigation,
                  iconSize: 18,
                  onTap: onResetNorth,
                ),
                _MapDivider(color: theme.dividerColor),
                _MapIconButton(
                  icon: Icons.fit_screen_rounded,
                  iconSize: 20,
                  onTap: onFitAll,
                ),
                _MapDivider(color: theme.dividerColor),
                _MapIconButton(
                  icon: isLocationEnabled
                      ? Icons.my_location_rounded
                      : Icons.location_searching_rounded,
                  iconSize: 20,
                  onTap: onMyLocation,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MapDirectionFloatingButton extends StatelessWidget {
  final Future<void> Function() onTap;

  const MapDirectionFloatingButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const List<Shadow> iconShadows = [
      Shadow(blurRadius: 10, offset: Offset(0, 4), color: Color(0x99000000)),
      Shadow(blurRadius: 3, offset: Offset(0, 1), color: Color(0x66000000)),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            blurRadius: 30,
            spreadRadius: -5,
            offset: Offset(0, 16),
            color: Color(0x44000000),
          ),
          BoxShadow(
            blurRadius: 8,
            offset: Offset(0, 4),
            color: Color(0x26000000),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => unawaited(onTap()),
            borderRadius: BorderRadius.circular(18),
            child: const SizedBox(
              width: 56,
              height: 56,
              child: Icon(
                Icons.directions_rounded,
                size: 32,
                color: Colors.white,
                shadows: iconShadows,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapIconButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final Future<void> Function() onTap;

  const _MapIconButton({
    required this.icon,
    required this.onTap,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    const List<Shadow> iconShadows = [
      Shadow(blurRadius: 10, offset: Offset(0, 4), color: Color(0x99000000)),
      Shadow(blurRadius: 3, offset: Offset(0, 1), color: Color(0x66000000)),
    ];

    return InkWell(
      onTap: () {
        unawaited(onTap());
      },
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, size: iconSize, shadows: iconShadows),
      ),
    );
  }
}

class _MapDivider extends StatelessWidget {
  final Color color;

  const _MapDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 1,
      color: color.withValues(alpha: 0.55),
    );
  }
}
