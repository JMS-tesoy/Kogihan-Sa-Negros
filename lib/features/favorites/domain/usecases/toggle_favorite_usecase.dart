import '../repositories/favorites_repository.dart';

class ToggleFavoriteUsecase {
  const ToggleFavoriteUsecase(this.repository);

  final FavoritesRepository repository;

  Future<void> call(String propertyId) {
    return repository.toggleFavorite(propertyId);
  }
}
