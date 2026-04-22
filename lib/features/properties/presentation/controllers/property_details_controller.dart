import 'package:flutter/foundation.dart';

import '../../domain/entities/property_entity.dart';
import '../../domain/usecases/get_property_details_usecase.dart';

class PropertyDetailsController extends ChangeNotifier {
  PropertyDetailsController({this.getPropertyDetailsUsecase});

  final GetPropertyDetailsUsecase? getPropertyDetailsUsecase;

  PropertyEntity? _property;

  PropertyEntity? get property => _property;

  Future<void> load(String id) async {
    _property = await getPropertyDetailsUsecase?.call(id);
    notifyListeners();
  }
}
