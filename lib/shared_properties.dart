import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Property {
  final String id;
  final String referenceCode;
  final String title;
  final String location;
  final String price;
  final int priceValue;
  final String size;
  final int sizeValue;
  final String tag;
  final String titleStatus;
  final String description;
  final Color imageColor;
  final String? imageUrl;
  final String? thumbnailUrl;

  const Property({
    required this.id,
    required this.referenceCode,
    required this.title,
    required this.location,
    required this.price,
    required this.priceValue,
    required this.size,
    required this.sizeValue,
    required this.tag,
    required this.titleStatus,
    required this.description,
    required this.imageColor,
    this.imageUrl,
    this.thumbnailUrl,
  });

  Property copyWith({
    String? id,
    String? referenceCode,
    String? title,
    String? location,
    String? price,
    int? priceValue,
    String? size,
    int? sizeValue,
    String? tag,
    String? titleStatus,
    String? description,
    Color? imageColor,
    String? imageUrl,
    String? thumbnailUrl,
  }) {
    return Property(
      id: id ?? this.id,
      referenceCode: referenceCode ?? this.referenceCode,
      title: title ?? this.title,
      location: location ?? this.location,
      price: price ?? this.price,
      priceValue: priceValue ?? this.priceValue,
      size: size ?? this.size,
      sizeValue: sizeValue ?? this.sizeValue,
      tag: tag ?? this.tag,
      titleStatus: titleStatus ?? this.titleStatus,
      description: description ?? this.description,
      imageColor: imageColor ?? this.imageColor,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Property && other.id == id;

  @override
  int get hashCode => id.hashCode;

  factory Property.fromMap(Map<String, dynamic> map) {
    return Property(
      id: map['id'] as String,
      referenceCode: (map['reference_code'] ?? '') as String,
      title: (map['title'] ?? '') as String,
      location: (map['location'] ?? '') as String,
      price: (map['price'] ?? '') as String,
      priceValue: _toInt(map['price_value']),
      size: (map['size'] ?? '') as String,
      sizeValue: _toInt(map['size_value']),
      tag: (map['tag'] ?? '') as String,
      titleStatus: (map['title_status'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      imageColor: Color(_toInt(map['image_color'])),
      imageUrl: _toNullableString(map['image_url']),
      thumbnailUrl: _toNullableString(map['thumbnail_url']),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'reference_code': referenceCode,
      'title': title,
      'location': location,
      'price': price,
      'price_value': priceValue,
      'size': size,
      'size_value': sizeValue,
      'tag': tag,
      'title_status': titleStatus,
      'description': description,
      'image_color': _toSigned32Bit(imageColor.toARGB32()),
      'image_url': _toNullableString(imageUrl),
      'thumbnail_url': _toNullableString(thumbnailUrl),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'reference_code': referenceCode,
      'title': title,
      'location': location,
      'price': price,
      'price_value': priceValue,
      'size': size,
      'size_value': sizeValue,
      'tag': tag,
      'title_status': titleStatus,
      'description': description,
      'image_color': _toSigned32Bit(imageColor.toARGB32()),
      'image_url': _toNullableString(imageUrl),
      'thumbnail_url': _toNullableString(thumbnailUrl),
    };
  }

  static String? _toNullableString(dynamic value) {
    final String normalized = (value?.toString() ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _toSigned32Bit(int value) {
    return value > 0x7FFFFFFF ? value - 0x100000000 : value;
  }
}

String _optimizedPropertyImageUrl(
  String imageUrl, {
  required int targetWidth,
}) {
  final Uri? uri = Uri.tryParse(imageUrl);
  if (uri == null) return imageUrl;

  final String host = uri.host.toLowerCase();
  if (!host.contains('unsplash.com')) return imageUrl;

  final Map<String, String> queryParameters = Map<String, String>.from(
    uri.queryParameters,
  );
  queryParameters['auto'] = 'format';
  queryParameters['fit'] = 'crop';
  queryParameters['w'] = targetWidth.toString();
  queryParameters['q'] = '70';

  return uri.replace(queryParameters: queryParameters).toString();
}

String? resolvePropertyImageUrl(
  Property property, {
  bool preferThumbnail = false,
  int? targetWidth,
}) {
  final String? primarySource = preferThumbnail
      ? property.thumbnailUrl ?? property.imageUrl
      : property.imageUrl ?? property.thumbnailUrl;
  final String normalized = (primarySource ?? '').trim();
  if (normalized.isEmpty) return null;

  if (preferThumbnail && (property.thumbnailUrl ?? '').trim().isNotEmpty) {
    return normalized;
  }

  if (targetWidth != null) {
    return _optimizedPropertyImageUrl(normalized, targetWidth: targetWidth);
  }

  return normalized;
}

const List<Property> _fallbackProperties = [
  Property(
    id: 'property-1',
    referenceCode: 'LF-000120008',
    title: 'Prime Residential Lot',
    location: '9.3077, 123.3054',
    price: '₱1,200,000',
    priceValue: 1200000,
    size: '500 sqm',
    sizeValue: 500,
    tag: 'Featured',
    titleStatus: 'Clean Title',
    description:
        'A clean residential lot ideal for a primary home build. Easy road access, stable neighborhood demand, and ready for site viewing.',
    imageColor: Color(0xFF9CCC65),
    imageUrl:
        'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=1200&q=80',
  ),
  Property(
    id: 'property-2',
    referenceCode: 'LF-000120009',
    title: 'Mountain View Land',
    location: '9.2516, 123.2400',
    price: '₱2,450,000',
    priceValue: 2450000,
    size: '1,200 sqm',
    sizeValue: 1200,
    tag: 'Hot Deal',
    titleStatus: 'Transfer Certificate of Title',
    description:
        'Elevated land parcel with open mountain views and strong long-term value for vacation home or subdivision planning.',
    imageColor: Color(0xFFA1887F),
    imageUrl:
        'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80',
  ),
  Property(
    id: 'property-3',
    referenceCode: 'LF-000120010',
    title: 'Farm Lot Investment',
    location: '10.3370, 123.8980',
    price: '₱3,100,000',
    priceValue: 3100000,
    size: '2,000 sqm',
    sizeValue: 2000,
    tag: 'New',
    titleStatus: 'Tax Declaration',
    description:
        'Spacious agricultural lot suited for farming, agri-tourism, or long-term land banking with room for future expansion.',
    imageColor: Color(0xFF64B5F6),
    imageUrl:
        'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=1200&q=80',
  ),
  Property(
    id: 'property-4',
    referenceCode: 'LF-000120011',
    title: 'Highway Frontage Lot',
    location: '9.3580, 123.2851',
    price: '₱4,800,000',
    priceValue: 4800000,
    size: '1,500 sqm',
    sizeValue: 1500,
    tag: 'Premium',
    titleStatus: 'Mother Title',
    description:
        'High-visibility lot with direct highway exposure, suitable for commercial development, showroom use, or mixed-use investment.',
    imageColor: Color(0xFFBA68C8),
    imageUrl:
        'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?auto=format&fit=crop&w=1200&q=80',
  ),
  Property(
    id: 'property-5',
    referenceCode: 'LF-000120012',
    title: 'Affordable Starter Lot',
    location: '9.3647, 122.8044',
    price: '₱900,000',
    priceValue: 900000,
    size: '300 sqm',
    sizeValue: 300,
    tag: 'Budget',
    titleStatus: 'Clean Title',
    description:
        'Entry-level lot for first-time buyers seeking an accessible parcel for a modest home build or initial lot investment.',
    imageColor: Color(0xFFFFB74D),
    imageUrl:
        'https://images.unsplash.com/photo-1501785888041-af3ef285b470?auto=format&fit=crop&w=1200&q=80',
  ),
];

final ValueNotifier<List<Property>> appPropertiesNotifier =
    ValueNotifier<List<Property>>(List<Property>.from(_fallbackProperties));

Future<void> loadProperties() async {
  try {
    final List<dynamic> response = await Supabase.instance.client
        .from('properties')
        .select()
        .order('created_at', ascending: false);

    final List<Property> loadedProperties = response
        .map((item) => Property.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();

    appPropertiesNotifier.value = loadedProperties.isEmpty
        ? List<Property>.from(_fallbackProperties)
        : loadedProperties;
  } catch (_) {
    appPropertiesNotifier.value = List<Property>.from(_fallbackProperties);
  }
}

Future<Property> createProperty(Property property) async {
  final Map<String, dynamic> response = await Supabase.instance.client
      .from('properties')
      .insert(property.toInsertMap())
      .select()
      .single();

  final Property createdProperty =
      Property.fromMap(Map<String, dynamic>.from(response));

  appPropertiesNotifier.value = [createdProperty, ...appPropertiesNotifier.value];
  return createdProperty;
}

Future<Property> updateProperty(Property property) async {
  final Map<String, dynamic> response = await Supabase.instance.client
      .from('properties')
      .update(property.toUpdateMap())
      .eq('id', property.id)
      .select()
      .single();

  final Property updatedProperty =
      Property.fromMap(Map<String, dynamic>.from(response));
  final List<Property> updatedProperties =
      List<Property>.from(appPropertiesNotifier.value);
  final int index =
      updatedProperties.indexWhere((item) => item.id == updatedProperty.id);

  if (index != -1) {
    updatedProperties[index] = updatedProperty;
    appPropertiesNotifier.value = updatedProperties;
  }

  return updatedProperty;
}

Future<void> deleteProperty(String propertyId) async {
  await Supabase.instance.client.from('properties').delete().eq('id', propertyId);

  appPropertiesNotifier.value = appPropertiesNotifier.value
      .where((property) => property.id != propertyId)
      .toList();
}
