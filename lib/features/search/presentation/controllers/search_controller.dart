import 'package:flutter/foundation.dart';

import '../../domain/usecases/global_search_usecase.dart';

class SearchController extends ChangeNotifier {
  SearchController({this.globalSearchUsecase});

  final GlobalSearchUsecase? globalSearchUsecase;

  List<String> _results = const <String>[];

  List<String> get results => _results;

  Future<void> search(String query) async {
    _results = await globalSearchUsecase?.call(query) ?? const <String>[];
    notifyListeners();
  }
}
