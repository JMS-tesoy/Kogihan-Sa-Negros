import 'package:flutter/material.dart';

class ReviewSummary extends StatelessWidget {
  const ReviewSummary({
    super.key,
    required this.averageRating,
  });

  final double averageRating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(Icons.star),
        const SizedBox(width: 4),
        Text(averageRating.toStringAsFixed(1)),
      ],
    );
  }
}
