import 'package:flutter/foundation.dart';

import '../../domain/entities/property_entity.dart';
import '../../domain/usecases/get_properties_usecase.dart';

class PropertyListController extends ChangeNotifier {
  PropertyListController({this.getPropertiesUsecase});

  final GetPropertiesUsecase? getPropertiesUsecase;

  List<PropertyEntity> _properties = const <PropertyEntity>[];

  List<PropertyEntity> get properties => _properties;

  Future<void> load() async {
    _properties = await getPropertiesUsecase?.call() ?? const <PropertyEntity>[];
    notifyListeners();
  }
}
