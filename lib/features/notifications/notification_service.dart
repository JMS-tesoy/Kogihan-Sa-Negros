import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Background handler (top-level, required by FCM) ─────────────────────────

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized by this point when the app is terminated.
  // Nothing extra needed — flutter_local_notifications handles the display.
}

// ─── Notification channels ────────────────────────────────────────────────────

const String _messageChannelId = 'messages_channel';
const String _messageChannelName = 'Messages';
const String _messageChannelDesc = 'Notifications for new buyer/agent messages';

const String _listingChannelId = 'listings_channel';
const String _listingChannelName = 'New Listings';
const String _listingChannelDesc =
    'Notifications for newly published properties';

// ─── NotificationService ─────────────────────────────────────────────────────

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static final StreamController<Map<String, dynamic>> _tapPayloadController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of notification tap payloads — listen in your root widget to
  /// navigate when user taps a notification.
  static Stream<Map<String, dynamic>> get onNotificationTap =>
      _tapPayloadController.stream;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Call once in main() after Firebase.initializeApp().
  static Future<void> initialize() async {
    await _initLocalNotifications();
    await _configureFcm();
    await _registerTokenWithSupabase();
    _listenForTokenRefresh();
  }

  /// Call when the user logs out so their device stops receiving notifications.
  static Future<void> clearTokenOnLogout() async {
    try {
      final String? userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': null})
          .eq('id', userId);

      await FirebaseMessaging.instance.deleteToken();
      developer.log('🔕 FCM token cleared on logout', name: 'Notifications');
    } catch (e) {
      developer.log('⚠️ Failed to clear FCM token: $e', name: 'Notifications');
    }
  }

  // ── Local notifications setup ───────────────────────────────────────────────

  static Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Create Android notification channels
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _messageChannelId,
        _messageChannelName,
        description: _messageChannelDesc,
        importance: Importance.high,
        playSound: true,
      ),
    );

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _listingChannelId,
        _listingChannelName,
        description: _listingChannelDesc,
        importance: Importance.defaultImportance,
        playSound: true,
      ),
    );
  }

  // ── FCM configuration ───────────────────────────────────────────────────────

  static Future<void> _configureFcm() async {
    // Register background handler before anything else
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission (iOS + Android 13+)
    final NotificationSettings settings = await FirebaseMessaging.instance
        .requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );

    developer.log(
      '🔔 Notification permission: ${settings.authorizationStatus}',
      name: 'Notifications',
    );

    // Foreground: show heads-up notification on Android
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    // Foreground message handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // App opened from background notification tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // App opened from terminated state via notification
    final RemoteMessage? initialMessage = await FirebaseMessaging.instance
        .getInitialMessage();
    if (initialMessage != null) {
      // Slight delay to ensure navigation is ready
      await Future<void>.delayed(const Duration(milliseconds: 500));
      _handleNotificationTap(initialMessage);
    }
  }

  // ── Token management ────────────────────────────────────────────────────────

  static Future<void> _registerTokenWithSupabase() async {
    try {
      final String? userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final String? token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', userId);

      developer.log('✅ FCM token saved to Supabase', name: 'Notifications');
    } catch (e) {
      developer.log('⚠️ Failed to save FCM token: $e', name: 'Notifications');
    }
  }

  static void _listenForTokenRefresh() {
    FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) async {
      try {
        final String? userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) return;

        await Supabase.instance.client
            .from('profiles')
            .update({'fcm_token': newToken})
            .eq('id', userId);

        developer.log('🔄 FCM token refreshed', name: 'Notifications');
      } catch (e) {
        developer.log(
          '⚠️ Token refresh save failed: $e',
          name: 'Notifications',
        );
      }
    });
  }

  // ── Message handlers ────────────────────────────────────────────────────────

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    developer.log(
      '📩 Foreground message: ${message.notification?.title}',
      name: 'Notifications',
    );

    final RemoteNotification? notification = message.notification;
    if (notification == null) return;

    final String channelId = _channelIdForType(message.data['type']);

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId == _messageChannelId
              ? _messageChannelName
              : _listingChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: _encodePayload(message.data),
    );
  }

  static void _handleNotificationTap(RemoteMessage message) {
    developer.log(
      '👆 Notification tapped: ${message.data}',
      name: 'Notifications',
    );
    _tapPayloadController.add(message.data);
  }

  static void _onLocalNotificationTap(NotificationResponse response) {
    final String? payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    final Map<String, dynamic> data = _decodePayload(payload);
    developer.log('👆 Local notification tapped: $data', name: 'Notifications');
    _tapPayloadController.add(data);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static String _channelIdForType(String? type) {
    return switch (type) {
      'new_message' => _messageChannelId,
      'new_listing' => _listingChannelId,
      _ => _messageChannelId,
    };
  }

  static String _encodePayload(Map<String, dynamic> data) {
    return data.entries.map((e) => '${e.key}=${e.value}').join('&');
  }

  static Map<String, dynamic> _decodePayload(String payload) {
    return Map<String, dynamic>.fromEntries(
      payload.split('&').map((part) {
        final List<String> kv = part.split('=');
        return MapEntry<String, dynamic>(
          kv.first,
          kv.length > 1 ? kv.sublist(1).join('=') : '',
        );
      }),
    );
  }

  static void dispose() {
    _tapPayloadController.close();
  }
}
