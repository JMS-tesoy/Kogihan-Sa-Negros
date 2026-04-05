import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Property {
  final String id;
  final String title;
  final String location;
  final String price;
  final int priceValue;
  final String size;
  final int sizeValue;
  final String tag;
  final Color imageColor;
  final String? imageUrl;

  const Property({
    required this.id,
    required this.title,
    required this.location,
    required this.price,
    required this.priceValue,
    required this.size,
    required this.sizeValue,
    required this.tag,
    required this.imageColor,
    this.imageUrl,
  });

  Property copyWith({
    String? id,
    String? title,
    String? location,
    String? price,
    int? priceValue,
    String? size,
    int? sizeValue,
    String? tag,
    Color? imageColor,
    String? imageUrl,
  }) {
    return Property(
      id: id ?? this.id,
      title: title ?? this.title,
      location: location ?? this.location,
      price: price ?? this.price,
      priceValue: priceValue ?? this.priceValue,
      size: size ?? this.size,
      sizeValue: sizeValue ?? this.sizeValue,
      tag: tag ?? this.tag,
      imageColor: imageColor ?? this.imageColor,
      imageUrl: imageUrl ?? this.imageUrl,
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
      title: (map['title'] ?? '') as String,
      location: (map['location'] ?? '') as String,
      price: (map['price'] ?? '') as String,
      priceValue: _toInt(map['price_value']),
      size: (map['size'] ?? '') as String,
      sizeValue: _toInt(map['size_value']),
      tag: (map['tag'] ?? '') as String,
      imageColor: Color(_toInt(map['image_color'])),
      imageUrl: _toNullableString(map['image_url']),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'title': title,
      'location': location,
      'price': price,
      'price_value': priceValue,
      'size': size,
      'size_value': sizeValue,
      'tag': tag,
      'image_color': _toSigned32Bit(imageColor.toARGB32()),
      'image_url': _toNullableString(imageUrl),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'title': title,
      'location': location,
      'price': price,
      'price_value': priceValue,
      'size': size,
      'size_value': sizeValue,
      'tag': tag,
      'image_color': _toSigned32Bit(imageColor.toARGB32()),
      'image_url': _toNullableString(imageUrl),
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

const List<Property> _fallbackProperties = [
  Property(
    id: 'property-1',
    title: 'Prime Residential Lot',
    location: '9.3077, 123.3054',
    price: '₱1,200,000',
    priceValue: 1200000,
    size: '500 sqm',
    sizeValue: 500,
    tag: 'Featured',
    imageColor: Color(0xFF9CCC65),
    imageUrl:
        'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=1200&q=80',
  ),
  Property(
    id: 'property-2',
    title: 'Mountain View Land',
    location: '9.2516, 123.2400',
    price: '₱2,450,000',
    priceValue: 2450000,
    size: '1,200 sqm',
    sizeValue: 1200,
    tag: 'Hot Deal',
    imageColor: Color(0xFFA1887F),
    imageUrl:
        'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1200&q=80',
  ),
  Property(
    id: 'property-3',
    title: 'Farm Lot Investment',
    location: '10.3370, 123.8980',
    price: '₱3,100,000',
    priceValue: 3100000,
    size: '2,000 sqm',
    sizeValue: 2000,
    tag: 'New',
    imageColor: Color(0xFF64B5F6),
    imageUrl:
        'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=1200&q=80',
  ),
  Property(
    id: 'property-4',
    title: 'Highway Frontage Lot',
    location: '9.3580, 123.2851',
    price: '₱4,800,000',
    priceValue: 4800000,
    size: '1,500 sqm',
    sizeValue: 1500,
    tag: 'Premium',
    imageColor: Color(0xFFBA68C8),
    imageUrl:
        'https://images.unsplash.com/photo-1470770841072-f978cf4d019e?auto=format&fit=crop&w=1200&q=80',
  ),
  Property(
    id: 'property-5',
    title: 'Affordable Starter Lot',
    location: '9.3647, 122.8044',
    price: '₱900,000',
    priceValue: 900000,
    size: '300 sqm',
    sizeValue: 300,
    tag: 'Budget',
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

    appPropertiesNotifier.value = response
        .map((item) => Property.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
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
