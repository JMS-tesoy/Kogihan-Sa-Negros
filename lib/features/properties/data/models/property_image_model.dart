import '../../domain/entities/property_image_entity.dart';

class PropertyImageModel extends PropertyImageEntity {
  const PropertyImageModel({
    required super.id,
    required super.url,
    super.caption,
  });

  factory PropertyImageModel.fromJson(Map<String, dynamic> json) {
    return PropertyImageModel(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
    );
  }
}
