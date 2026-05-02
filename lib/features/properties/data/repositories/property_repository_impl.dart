import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/property_entity.dart';
import '../../domain/entities/property_filter_entity.dart';
import '../../domain/repositories/property_repository.dart';
import '../datasources/properties_local_datasource.dart';
import '../datasources/properties_remote_datasource.dart';
import '../models/property_model.dart';
import '../services/property_upload_service.dart';

class PropertyRepositoryImpl implements PropertyRepository {
  PropertyRepositoryImpl({
    PropertiesRemoteDatasource? remoteDatasource,
    PropertiesLocalDatasource? localDatasource,
    PropertyUploadService? uploadService,
    SupabaseClient? supabase,
  }) : _remoteDatasource = remoteDatasource ?? PropertiesRemoteDatasource(),
       _localDatasource = localDatasource ?? PropertiesLocalDatasource(),
       _uploadService = uploadService ?? PropertyUploadService(),
       _supabase = supabase ?? Supabase.instance.client;

  final PropertiesRemoteDatasource _remoteDatasource;
  final PropertiesLocalDatasource _localDatasource;
  final PropertyUploadService _uploadService;
  final SupabaseClient _supabase;

  Future<void> createProperty(
    PropertyModel property,
    Uint8List? imageBytes,
  ) async {
    String? imageUrl;

    if (imageBytes != null) {
      final fileName = 'prop_${DateTime.now().millisecondsSinceEpoch}.jpg';

      imageUrl = await _uploadService.uploadImage(imageBytes, fileName);
    }

    final data = <String, dynamic>{
      if (property.id.isNotEmpty) 'id': property.id,
      'title': property.title,
      'price': property.price,
      if (property.description.isNotEmpty) 'description': property.description,
      if (property.address.isNotEmpty) 'address': property.address,
      'listing_type': property.listingType.name,
      'status': property.status.name,
    };

    if (imageUrl != null) {
      data['image_url'] = imageUrl;
    }

    await _supabase.from('properties').insert(data);
  }

  @override
  Future<List<PropertyEntity>> getProperties({PropertyFilterEntity? filter}) {
    return _remoteDatasource.getProperties();
  }

  @override
  Future<PropertyEntity?> getPropertyDetails(String id) {
    return _remoteDatasource.getPropertyDetails(id);
  }

  @override
  Future<List<PropertyEntity>> getFeaturedProperties() {
    return _remoteDatasource.getProperties();
  }

  @override
  Future<List<PropertyEntity>> searchProperties(String query) {
    return _remoteDatasource.getProperties();
  }

  @override
  Future<void> saveProperty(String id) {
    return _localDatasource.saveProperty(id);
  }

  @override
  Future<void> unsaveProperty(String id) {
    return _localDatasource.unsaveProperty(id);
  }
}
