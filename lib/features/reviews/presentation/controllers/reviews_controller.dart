import 'package:flutter/foundation.dart';

import '../../domain/entities/review_entity.dart';
import '../../domain/usecases/get_reviews_usecase.dart';

class ReviewsController extends ChangeNotifier {
  ReviewsController({this.getReviewsUsecase});

  final GetReviewsUsecase? getReviewsUsecase;

  List<ReviewEntity> _reviews = const <ReviewEntity>[];

  List<ReviewEntity> get reviews => _reviews;

  Future<void> load(String propertyId) async {
    _reviews = await getReviewsUsecase?.call(propertyId) ?? const <ReviewEntity>[];
    notifyListeners();
  }
}
