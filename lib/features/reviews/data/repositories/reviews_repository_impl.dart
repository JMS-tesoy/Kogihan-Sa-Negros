import '../../domain/entities/review_entity.dart';
import '../../domain/repositories/reviews_repository.dart';
import '../datasources/reviews_remote_datasource.dart';
import '../models/review_model.dart';

class ReviewsRepositoryImpl implements ReviewsRepository {
  ReviewsRepositoryImpl({ReviewsRemoteDatasource? remoteDatasource})
    : _remoteDatasource = remoteDatasource ?? ReviewsRemoteDatasource();

  final ReviewsRemoteDatasource _remoteDatasource;

  @override
  Future<void> addReview(ReviewEntity review) {
    final model = ReviewModel(
      id: review.id,
      propertyId: review.propertyId,
      rating: review.rating,
      comment: review.comment,
    );
    return _remoteDatasource.addReview(model);
  }

  @override
  Future<List<ReviewEntity>> getReviews(String propertyId) {
    return _remoteDatasource.getReviews(propertyId);
  }
}
