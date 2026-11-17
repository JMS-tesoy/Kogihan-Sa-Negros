import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
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

String resolveMapboxAccessToken({Map<String, String>? env}) {
  final source = env ?? dotenv.env;
  return (source['MAPBOX_ACCESS_TOKEN'] ?? '').trim();
}

Future<void> initializeMapboxConfiguration() async {
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('✅ .env loaded');
  } catch (e) {
    debugPrint('❌ .env LOAD FAILED: $e');
  }

  final String envToken = resolveMapboxAccessToken();
  if (envToken.isNotEmpty) {
    MapboxConfig.accessToken = envToken;
  }

  if (MapboxConfig.accessToken.isNotEmpty) {
    MapboxOptions.setAccessToken(MapboxConfig.accessToken);
  }
}

Future<void> initializeFirebaseServices() async {
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
}

Future<void> initializeSupabaseServices() async {
  try {
    await Supabase.initialize(
      url: SupabaseConfig.effectiveUrl,
      anonKey: SupabaseConfig.effectiveAnonKey,
    );
    unawaited(loadProperties());
    unawaited(loadNegrosPlaces());
    debugPrint('✅ Supabase connected successfully!');
  } catch (e, stackTrace) {
    debugPrint('❌ SUPABASE INIT FAILED: $e');
    debugPrint('$stackTrace');
    developer.log(
      '❌ Supabase connection failed',
      name: 'Supabase',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

Future<void> initializeLandFinderAppBootstrap() async {
  await initializeMapboxConfiguration();
  await initializeFirebaseServices();
  await initializeSupabaseServices();
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