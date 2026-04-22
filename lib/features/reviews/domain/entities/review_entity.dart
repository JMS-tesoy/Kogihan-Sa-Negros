class ReviewEntity {
  const ReviewEntity({
    required this.id,
    required this.propertyId,
    required this.rating,
    this.comment = '',
  });

  final String id;
  final String propertyId;
  final int rating;
  final String comment;
}
