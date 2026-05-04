import 'package:flutter/material.dart';

import '../../../../app/router/route_names.dart';
import '../../data/datasources/notifications_remote_datasource.dart';
import '../../data/notification_model.dart';

class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context) {
    final NotificationsRemoteDatasource datasource =
        NotificationsRemoteDatasource();

    return StreamBuilder<List<AppNotification>>(
      stream: datasource.watchNotifications(),
      builder: (context, snapshot) {
        final List<AppNotification> notifications =
            snapshot.data ?? <AppNotification>[];

        final int unreadCount = notifications
            .where((notification) => !notification.isRead)
            .length;

        return _NotificationBellIcon(unreadCount: unreadCount);
      },
    );
  }
}

class _NotificationBellIcon extends StatelessWidget {
  const _NotificationBellIcon({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        IconButton(
          tooltip: 'Notifications',
          onPressed: () {
            Navigator.of(context).pushNamed(RouteNames.notifications);
          },
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        if (unreadCount > 0)
          Positioned(
            top: 5,
            right: 5,
            child: IgnorePointer(
              child: Container(
                constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: theme.scaffoldBackgroundColor,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onError,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
