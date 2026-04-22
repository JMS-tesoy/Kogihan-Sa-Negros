import '../repositories/search_repository.dart';

class RecentSearchesUsecase {
  const RecentSearchesUsecase(this.repository);

  final SearchRepository repository;

  Future<List<String>> call() {
    return repository.recentSearches();
  }
}
