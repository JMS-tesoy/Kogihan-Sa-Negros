import '../repositories/search_repository.dart';

class GlobalSearchUsecase {
  const GlobalSearchUsecase(this.repository);

  final SearchRepository repository;

  Future<List<String>> call(String query) {
    return repository.globalSearch(query);
  }
}
