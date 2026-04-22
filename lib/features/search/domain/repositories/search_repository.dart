abstract interface class SearchRepository {
  Future<List<String>> globalSearch(String query);

  Future<List<String>> recentSearches();
}
