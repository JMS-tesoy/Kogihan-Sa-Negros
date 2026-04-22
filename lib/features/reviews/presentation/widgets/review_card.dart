import 'package:flutter/material.dart';

import '../../domain/entities/review_entity.dart';

class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.review,
  });

  final ReviewEntity review;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.star),
        title: Text('${review.rating}/5'),
        subtitle: Text(review.comment),
      ),
    );
  }
}
