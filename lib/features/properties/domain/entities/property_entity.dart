import '../../../../core/enums/listing_type.dart';
import '../../../../core/enums/property_status.dart';
import '../../../../shared/models/location_point.dart';
import 'property_image_entity.dart';

class PropertyEntity {
  const PropertyEntity({
    required this.id,
    required this.title,
    required this.price,
    this.description = '',
    this.address = '',
    this.listingType = ListingType.sale,
    this.status = PropertyStatus.active,
    this.location,
    this.images = const <PropertyImageEntity>[],
  });

  final String id;
  final String title;
  final String description;
  final String address;
  final double price;
  final ListingType listingType;
  final PropertyStatus status;
  final LocationPoint? location;
  final List<PropertyImageEntity> images;
}
