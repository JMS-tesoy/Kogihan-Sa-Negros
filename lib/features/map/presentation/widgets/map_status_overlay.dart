import 'package:flutter/material.dart';

class MapStatusOverlay extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const MapStatusOverlay({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  const MapStatusOverlay.mapboxAccessTokenMissing({super.key})
    : icon = Icons.map_outlined,
      title = 'Mapbox access token is missing.',
      message =
          'Add MAPBOX_ACCESS_TOKEN to .env or run the app with --dart-define ACCESS_TOKEN=YOUR_PUBLIC_MAPBOX_ACCESS_TOKEN to load the map.';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
