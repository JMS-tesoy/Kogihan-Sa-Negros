import '../../domain/entities/review_entity.dart';

class ReviewModel extends ReviewEntity {
  const ReviewModel({
    required super.id,
    required super.propertyId,
    required super.rating,
    super.comment,
  });
}
