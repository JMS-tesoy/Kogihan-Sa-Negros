import 'package:flutter/material.dart';

import '../../../../core/widgets/app_scaffold_shell.dart';
import '../../data/datasources/notifications_remote_datasource.dart';
import '../../data/notification_model.dart';
import '../widgets/notification_tile.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationsRemoteDatasource _datasource =
      NotificationsRemoteDatasource();

  late Future<List<AppNotification>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _datasource.getNotifications();
  }

  void _refreshNotifications() {
    setState(() {
      _notificationsFuture = _datasource.getNotifications();
    });
  }

  Future<void> _markAsRead(AppNotification notification) async {
    if (notification.isRead) {
      return;
    }

    await _datasource.markNotificationRead(notification.id);
    _refreshNotifications();
  }

  Future<void> _markAllAsRead() async {
    await _datasource.markAllNotificationsRead();
    _refreshNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AppNotification>>(
      future: _notificationsFuture,
      builder: (context, snapshot) {
        final List<AppNotification> notifications =
            snapshot.data ?? <AppNotification>[];

        final int unreadCount = notifications
            .where((notification) => !notification.isRead)
            .length;

        return AppScaffoldShell(
          title: 'Notifications',
          actions: <Widget>[
            if (unreadCount > 0)
              TextButton(
                onPressed: _markAllAsRead,
                child: const Text('Mark all as read'),
              ),
          ],
          body: _NotificationsBody(
            snapshot: snapshot,
            notifications: notifications,
            unreadCount: unreadCount,
            onRefresh: () async => _refreshNotifications(),
            onNotificationTap: _markAsRead,
          ),
        );
      },
    );
  }
}

class _NotificationsBody extends StatelessWidget {
  const _NotificationsBody({
    required this.snapshot,
    required this.notifications,
    required this.unreadCount,
    required this.onRefresh,
    required this.onNotificationTap,
  });

  final AsyncSnapshot<List<AppNotification>> snapshot;
  final List<AppNotification> notifications;
  final int unreadCount;
  final Future<void> Function() onRefresh;
  final Future<void> Function(AppNotification notification) onNotificationTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return _NotificationsErrorState(
        message: 'Unable to load notifications.',
        onRetry: onRefresh,
      );
    }

    if (notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: const CustomScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyNotificationsState(),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          if (unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                'You have $unreadCount unread notification${unreadCount == 1 ? '' : 's'}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ),
          ...notifications.map(
            (notification) => NotificationTile(
              notification: notification,
              onTap: () => onNotificationTap(notification),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsErrorState extends StatelessWidget {
  const _NotificationsErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _EmptyNotificationsState extends StatelessWidget {
  const _EmptyNotificationsState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.notifications_none_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Updates about your saved properties, inquiries, and account will appear here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
