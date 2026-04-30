import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/location/data/datasources/negros_places_datasource.dart';
import '../../features/properties/data/datasources/shared_properties.dart';
import '../../features/subscription/data/services/subscription_service.dart';
import '../config/mapbox_config.dart';
import '../config/supabase_config.dart';
import '../state/app_display_preferences.dart';

Future<void> initializeLandFinderAppBootstrap() async {
  try {
    await dotenv.load(fileName: '.env');
    final String envToken = dotenv.env['MAPBOX_ACCESS_TOKEN']?.trim() ?? '';
    if (envToken.isNotEmpty) {
      MapboxConfig.accessToken = envToken;
    }
  } catch (_) {}

  if (MapboxConfig.accessToken.isNotEmpty) {
    MapboxOptions.setAccessToken(MapboxConfig.accessToken);
  }

  try {
    await Supabase.initialize(
      url: SupabaseConfig.effectiveUrl,
      anonKey: SupabaseConfig.effectiveAnonKey,
    );
    unawaited(loadProperties());
    unawaited(loadNegrosPlaces());
    developer.log('✅ Supabase connected successfully!', name: 'Supabase');
  } catch (e, stackTrace) {
    developer.log(
      '❌ Supabase connection failed',
      name: 'Supabase',
      error: e,
      stackTrace: stackTrace,
    );
  }

  await SubscriptionService.initialize();
  await initializeAppThemePreference();
}
