import '../../../../core/enums/listing_type.dart';
import '../../domain/entities/property_filter_entity.dart';

class PropertyFilterModel extends PropertyFilterEntity {
  const PropertyFilterModel({
    super.query,
    super.listingType,
    super.minPrice,
    super.maxPrice,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'query': query,
      'listingType': listingType?.name,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
    };
  }

  factory PropertyFilterModel.saleOnly() {
    return const PropertyFilterModel(listingType: ListingType.sale);
  }
}
