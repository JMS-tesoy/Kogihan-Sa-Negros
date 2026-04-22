import '../entities/review_entity.dart';
import '../repositories/reviews_repository.dart';

class AddReviewUsecase {
  const AddReviewUsecase(this.repository);

  final ReviewsRepository repository;

  Future<void> call(ReviewEntity review) {
    return repository.addReview(review);
  }
}
