import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Property && other.id == id;

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'location': location,
      'price': price,
      'priceValue': priceValue,
      'size': size,
      'sizeValue': sizeValue,
      'tag': tag,
      'imageColor': imageColor.toARGB32(),
    };
  }

  factory Property.fromJson(Map<String, dynamic> json) {
    return Property(
      id: json['id'] as String,
      title: json['title'] as String,
      location: json['location'] as String,
      price: json['price'] as String,
      priceValue: json['priceValue'] as int,
      size: json['size'] as String,
      sizeValue: json['sizeValue'] as int,
      tag: json['tag'] as String,
      imageColor: Color(json['imageColor'] as int),
    );
  }
}

const String _propertiesStorageKey = 'agent_properties_v1';

const List<Property> _defaultProperties = [
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
  ),
];

final ValueNotifier<List<Property>> appPropertiesNotifier =
    ValueNotifier<List<Property>>(List<Property>.from(_defaultProperties));

Future<void> loadProperties() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? rawJson = prefs.getString(_propertiesStorageKey);

  if (rawJson == null || rawJson.isEmpty) {
    appPropertiesNotifier.value = List<Property>.from(_defaultProperties);
    return;
  }

  final List<dynamic> decoded = jsonDecode(rawJson) as List<dynamic>;
  appPropertiesNotifier.value = decoded
      .map((item) => Property.fromJson(Map<String, dynamic>.from(item as Map)))
      .toList();
}

Future<void> saveProperties(List<Property> properties) async {
  appPropertiesNotifier.value = List<Property>.from(properties);

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String rawJson = jsonEncode(
    properties.map((property) => property.toJson()).toList(),
  );
  await prefs.setString(_propertiesStorageKey, rawJson);
}
