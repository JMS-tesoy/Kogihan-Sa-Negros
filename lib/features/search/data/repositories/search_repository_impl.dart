import '../../domain/repositories/search_repository.dart';
import '../datasources/search_remote_datasource.dart';

class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl({SearchRemoteDatasource? remoteDatasource})
      : _remoteDatasource = remoteDatasource ?? SearchRemoteDatasource();

  final SearchRemoteDatasource _remoteDatasource;

  @override
  Future<List<String>> globalSearch(String query) {
    return _remoteDatasource.search(query);
  }

  @override
  Future<List<String>> recentSearches() async {
    return const <String>[];
  }
}
