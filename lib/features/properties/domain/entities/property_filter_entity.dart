import '../../../../core/enums/listing_type.dart';

class PropertyFilterEntity {
  const PropertyFilterEntity({
    this.query = '',
    this.listingType,
    this.minPrice,
    this.maxPrice,
  });

  final String query;
  final ListingType? listingType;
  final double? minPrice;
  final double? maxPrice;
}
