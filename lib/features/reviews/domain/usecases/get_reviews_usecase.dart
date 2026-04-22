import '../entities/review_entity.dart';
import '../repositories/reviews_repository.dart';

class GetReviewsUsecase {
  const GetReviewsUsecase(this.repository);

  final ReviewsRepository repository;

  Future<List<ReviewEntity>> call(String propertyId) {
    return repository.getReviews(propertyId);
  }
}
