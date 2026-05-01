import 'package:flutter/material.dart';

class PropertyMapPreview extends StatelessWidget {
  const PropertyMapPreview({super.key, this.boundaryCoordinates});

  final String? boundaryCoordinates;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF162033),
        border: Border.all(color: const Color(0xFF2D3B52)),
      ),
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            const Positioned(
              left: -24,
              top: 34,
              right: -24,
              child: _MapRoad(angle: -0.12),
            ),
            const Positioned(
              left: -20,
              bottom: 38,
              right: -20,
              child: _MapRoad(angle: 0.16),
            ),
            const Positioned(
              top: -20,
              bottom: -20,
              left: 92,
              child: _MapVerticalRoad(),
            ),
            Positioned(
              right: 22,
              top: 24,
              child: _MapBlock(
                width: 62,
                height: 42,
                color: const Color(0xFF244737),
              ),
            ),
            Positioned(
              left: 24,
              bottom: 22,
              child: _MapBlock(
                width: 74,
                height: 48,
                color: const Color(0xFF493B2B),
              ),
            ),
            Icon(
              Icons.map_outlined,
              size: 64,
              color: const Color(0xFF8FA8C7).withValues(alpha: 0.2),
            ),
            const Icon(Icons.location_on, size: 38, color: Color(0xFF4B9BFF)),
            Positioned(
              bottom: 18,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1726).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'Map preview',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFFD7E3F2),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapRoad extends StatelessWidget {
  const _MapRoad({required this.angle});

  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        height: 18,
        decoration: BoxDecoration(
          color: const Color(0xFF26354C).withValues(alpha: 0.85),
          border: Border.symmetric(
            horizontal: BorderSide(
              color: const Color(0xFF3D506B).withValues(alpha: 0.9),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapVerticalRoad extends StatelessWidget {
  const _MapVerticalRoad();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      decoration: BoxDecoration(
        color: const Color(0xFF26354C).withValues(alpha: 0.78),
        border: Border.symmetric(
          vertical: BorderSide(
            color: const Color(0xFF3D506B).withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }
}

class _MapBlock extends StatelessWidget {
  const _MapBlock({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}
