import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/location/data/datasources/negros_places_datasource.dart';
import '../../features/notifications/notification_service.dart';
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

  // Firebase must be initialized before Supabase so the FCM token
  // is available when NotificationService registers it after login.
  try {
    await Firebase.initializeApp();
    developer.log('✅ Firebase initialized', name: 'Firebase');
  } catch (e, stackTrace) {
    developer.log(
      '❌ Firebase initialization failed',
      name: 'Firebase',
      error: e,
      stackTrace: stackTrace,
    );
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

/// Call this after the user successfully logs in.
/// Registers the FCM token with Supabase so the device receives notifications.
Future<void> onUserLoggedIn() async {
  await NotificationService.initialize();
}

/// Call this before signing the user out.
/// Removes the FCM token from Supabase so the device stops receiving notifications.
Future<void> onUserLoggedOut() async {
  await NotificationService.clearTokenOnLogout();
}
