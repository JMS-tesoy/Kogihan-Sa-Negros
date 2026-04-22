import '../entities/review_entity.dart';

abstract interface class ReviewsRepository {
  Future<List<ReviewEntity>> getReviews(String propertyId);

  Future<void> addReview(ReviewEntity review);
}
