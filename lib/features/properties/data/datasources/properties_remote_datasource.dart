import '../models/property_model.dart';

class PropertiesRemoteDatasource {
  Future<List<PropertyModel>> getProperties() async {
    return const <PropertyModel>[];
  }

  Future<PropertyModel?> getPropertyDetails(String id) async {
    return null;
  }
}
