import 'package:supabase_flutter/supabase_flutter.dart';

import '../notification_model.dart';

class NotificationsRemoteDatasource {
  NotificationsRemoteDatasource({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<AppNotification>> getNotifications() async {
    final String? userId = _client.auth.currentUser?.id;

    if (userId == null) {
      return <AppNotification>[];
    }

    final List<dynamic> response = await _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return response
        .map((item) => AppNotification.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Stream<List<AppNotification>> watchNotifications() {
    final String? userId = _client.auth.currentUser?.id;

    if (userId == null) {
      return Stream<List<AppNotification>>.value(<AppNotification>[]);
    }

    return _client
        .from('notifications')
        .stream(primaryKey: <String>['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map(
          (rows) => rows.map((row) => AppNotification.fromMap(row)).toList(),
        );
  }

  Future<void> markNotificationRead(String notificationId) async {
    final String? userId = _client.auth.currentUser?.id;

    if (userId == null) {
      return;
    }

    await _client
        .from('notifications')
        .update(<String, dynamic>{'is_read': true})
        .eq('id', notificationId)
        .eq('user_id', userId);
  }

  Future<void> markAllNotificationsRead() async {
    final String? userId = _client.auth.currentUser?.id;

    if (userId == null) {
      return;
    }

    await _client
        .from('notifications')
        .update(<String, dynamic>{'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  Future<void> deleteNotification(String notificationId) async {
    final String? userId = _client.auth.currentUser?.id;

    if (userId == null) {
      return;
    }

    await _client
        .from('notifications')
        .delete()
        .eq('id', notificationId)
        .eq('user_id', userId);
  }

  Future<int> deleteReadNotifications() async {
    final String? userId = _client.auth.currentUser?.id;

    if (userId == null) {
      return 0;
    }

    final List<dynamic> deletedRows = await _client
        .from('notifications')
        .delete()
        .eq('user_id', userId)
        .eq('is_read', true)
        .select('id');

    return deletedRows.length;
  }
}
