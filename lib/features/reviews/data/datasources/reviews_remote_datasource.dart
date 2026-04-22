import '../models/review_model.dart';

class ReviewsRemoteDatasource {
  Future<List<ReviewModel>> getReviews(String propertyId) async {
    return const <ReviewModel>[];
  }

  Future<void> addReview(ReviewModel review) async {}
}
