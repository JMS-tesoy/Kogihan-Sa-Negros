import '../../../../core/enums/listing_type.dart';
import '../../../../core/enums/property_status.dart';
import '../../domain/entities/property_entity.dart';

class PropertyModel extends PropertyEntity {
  const PropertyModel({
    required super.id,
    required super.title,
    required super.price,
    super.description,
    super.address,
    super.listingType,
    super.status,
    super.location,
    super.images,
  });

  factory PropertyModel.fromJson(Map<String, dynamic> json) {
    return PropertyModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      address: json['address'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      listingType: ListingType.sale,
      status: PropertyStatus.active,
    );
  }
}
