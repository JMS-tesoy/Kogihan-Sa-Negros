import 'package:flutter/material.dart';

class StickySearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  const StickySearchHeaderDelegate({required this.child, required this.height});

  final Widget child;
  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final ThemeData theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: overlapsContent
            ? <BoxShadow>[
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant StickySearchHeaderDelegate oldDelegate) {
    return height != oldDelegate.height || child != oldDelegate.child;
  }
}
