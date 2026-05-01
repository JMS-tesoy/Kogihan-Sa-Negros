import 'package:flutter/material.dart';

class ActiveFilterChip extends StatelessWidget {
  const ActiveFilterChip({
    super.key,
    required this.label,
    required this.onDeleted,
  });

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: InputChip(
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        deleteIcon: const Icon(Icons.close_rounded, size: 16),
        onDeleted: onDeleted,
      ),
    );
  }
}
