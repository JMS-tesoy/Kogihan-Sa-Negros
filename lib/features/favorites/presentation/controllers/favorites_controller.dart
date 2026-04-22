import 'package:flutter/foundation.dart';

import '../../../properties/domain/entities/property_entity.dart';
import '../../domain/usecases/get_saved_properties_usecase.dart';

class FavoritesController extends ChangeNotifier {
  FavoritesController({this.getSavedPropertiesUsecase});

  final GetSavedPropertiesUsecase? getSavedPropertiesUsecase;

  List<PropertyEntity> _properties = const <PropertyEntity>[];

  List<PropertyEntity> get properties => _properties;

  Future<void> load() async {
    _properties =
        await getSavedPropertiesUsecase?.call() ?? const <PropertyEntity>[];
    notifyListeners();
  }
}
