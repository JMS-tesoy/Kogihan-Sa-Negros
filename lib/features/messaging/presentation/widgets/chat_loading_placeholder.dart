import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ChatLoadingPlaceholder extends StatelessWidget {
  const ChatLoadingPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final Color baseColor = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
    final Color highlightColor = Color.alphaBlend(
      Colors.white.withValues(alpha: 0.35),
      baseColor,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: List<Widget>.generate(6, (index) {
        final bool isOutgoing = index.isOdd;
        return Align(
          alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
          child: Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              width: isOutgoing ? 220 : 180,
              height: 54,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: isOutgoing
                      ? const Radius.circular(0)
                      : const Radius.circular(16),
                  bottomLeft: !isOutgoing
                      ? const Radius.circular(0)
                      : const Radius.circular(16),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
