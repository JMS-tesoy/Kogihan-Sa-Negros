import 'package:flutter/material.dart';

import '../../../../core/widgets/app_scaffold_shell.dart';
import '../../../../core/widgets/app_snack_bar.dart';
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

  final Set<String> _optimisticallyDeletedIds = <String>{};

  Future<void> _markAsRead(AppNotification notification) async {
    if (notification.isRead) {
      return;
    }

    await _datasource.markNotificationRead(notification.id);
  }

  Future<void> _markAllAsRead() async {
    await _datasource.markAllNotificationsRead();
  }

  Future<void> _deleteNotification(AppNotification notification) async {
    setState(() {
      _optimisticallyDeletedIds.add(notification.id);
    });

    try {
      await _datasource.deleteNotification(notification.id);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _optimisticallyDeletedIds.remove(notification.id);
      });

      AppSnackBar.error(
        context,
        'Unable to delete notification. Please try again.',
      );
    }
  }

  Future<void> _deleteReadNotifications(
    List<AppNotification> notifications,
  ) async {
    final List<AppNotification> readNotifications = notifications
        .where((notification) => notification.isRead)
        .toList();

    if (readNotifications.isEmpty) {
      AppSnackBar.info(context, 'No read notifications to clear.');
      return;
    }

    final Set<String> idsToDelete = readNotifications
        .map((notification) => notification.id)
        .toSet();

    setState(() {
      _optimisticallyDeletedIds.addAll(idsToDelete);
    });

    try {
      await _datasource.deleteReadNotifications();

      if (!mounted) {
        return;
      }

      AppSnackBar.success(
        context,
        'Cleared ${idsToDelete.length} read notification${idsToDelete.length == 1 ? '' : 's'}.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _optimisticallyDeletedIds.removeAll(idsToDelete);
      });

      AppSnackBar.error(
        context,
        'Unable to clear read notifications. Please try again.',
      );
    }
  }

  List<AppNotification> _filterVisibleNotifications(
    List<AppNotification> notifications,
  ) {
    return notifications
        .where(
          (notification) =>
              !_optimisticallyDeletedIds.contains(notification.id),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: _datasource.watchNotifications(),
      builder: (context, snapshot) {
        final List<AppNotification> notifications = _filterVisibleNotifications(
          snapshot.data ?? <AppNotification>[],
        );

        final int unreadCount = notifications
            .where((notification) => !notification.isRead)
            .length;

        final bool hasReadNotifications = notifications.any(
          (notification) => notification.isRead,
        );

        return AppScaffoldShell(
          title: 'Notifications',
          actions: <Widget>[
            if (unreadCount > 0)
              TextButton(
                onPressed: _markAllAsRead,
                child: const Text('Mark all as read'),
              ),
            if (hasReadNotifications)
              TextButton(
                onPressed: () => _deleteReadNotifications(notifications),
                child: const Text('Clear read'),
              ),
          ],
          body: _NotificationsBody(
            snapshot: snapshot,
            notifications: notifications,
            unreadCount: unreadCount,
            onNotificationTap: _markAsRead,
            onNotificationDelete: _deleteNotification,
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
    required this.onNotificationTap,
    required this.onNotificationDelete,
  });

  final AsyncSnapshot<List<AppNotification>> snapshot;
  final List<AppNotification> notifications;
  final int unreadCount;
  final Future<void> Function(AppNotification notification) onNotificationTap;
  final Future<void> Function(AppNotification notification)
  onNotificationDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return const _NotificationsErrorState(
        message: 'Unable to load notifications.',
      );
    }

    if (notifications.isEmpty) {
      return const CustomScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyNotificationsState(),
          ),
        ],
      );
    }

    return ListView(
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
          (notification) => Dismissible(
            key: ValueKey<String>(notification.id),
            direction: DismissDirection.endToStart,
            background: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.centerRight,
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                color: theme.colorScheme.onError,
              ),
            ),
            confirmDismiss: (_) async {
              if (notification.isRead) {
                return true;
              }

              AppSnackBar.warning(
                context,
                'Read the notification before deleting it.',
              );

              return false;
            },
            onDismissed: (_) {
              onNotificationDelete(notification);
            },
            child: NotificationTile(
              notification: notification,
              onTap: () => onNotificationTap(notification),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationsErrorState extends StatelessWidget {
  const _NotificationsErrorState({required this.message});

  final String message;

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
