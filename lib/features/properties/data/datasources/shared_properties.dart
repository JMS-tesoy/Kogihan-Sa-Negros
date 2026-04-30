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
  final String? boundaryCoordinates;
  final String? agentId;
  final String? agentTeamId;
  final String? agentTeamName;

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
    this.boundaryCoordinates,
    this.agentId,
    this.agentTeamId,
    this.agentTeamName,
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
    String? boundaryCoordinates,
    String? agentId,
    String? agentTeamId,
    String? agentTeamName,
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
      boundaryCoordinates: boundaryCoordinates ?? this.boundaryCoordinates,
      agentId: agentId ?? this.agentId,
      agentTeamId: agentTeamId ?? this.agentTeamId,
      agentTeamName: agentTeamName ?? this.agentTeamName,
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
      boundaryCoordinates: _toNullableString(map['boundary_coordinates']),
      agentId: _toNullableString(map['agent_id']),
      agentTeamId: _toNullableString(map['agent_team_id']),
      agentTeamName: _agentTeamNameFromMap(map),
    );
  }

  Map<String, dynamic> toInsertMap() {
    final Map<String, dynamic> data = {
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
      'boundary_coordinates': _toNullableString(boundaryCoordinates),
      'agent_id': _toNullableString(agentId),
      'agent_team_id': _toNullableString(agentTeamId),
    };
    return data;
  }

  Map<String, dynamic> toUpdateMap() {
    final Map<String, dynamic> data = {
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
      'boundary_coordinates': _toNullableString(boundaryCoordinates),
      'agent_id': _toNullableString(agentId),
      'agent_team_id': _toNullableString(agentTeamId),
    };
    return data;
  }

  static String? _toNullableString(dynamic value) {
    final String normalized = (value?.toString() ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }

  static String? _agentTeamNameFromMap(Map<String, dynamic> map) {
    final Object? team = map['agent_teams'];
    if (team is Map) {
      return _toNullableString(team['name']);
    }
    return null;
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

String _optimizedPropertyImageUrl(String imageUrl, {required int targetWidth}) {
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

const List<Property> _fallbackProperties = [];

final ValueNotifier<List<Property>> appPropertiesNotifier =
    ValueNotifier<List<Property>>(List<Property>.from(_fallbackProperties));

const int propertyPageSize = 20;
int _loadedPropertyCount = 0;
bool _hasMoreProperties = true;
Future<void>? _propertiesLoadFuture;

bool get hasMoreProperties => _hasMoreProperties;

Future<void> loadProperties({bool reset = true}) {
  if (_propertiesLoadFuture != null) return _propertiesLoadFuture!;
  if (!reset && !_hasMoreProperties) return Future<void>.value();

  _propertiesLoadFuture = _loadPropertiesPage(reset: reset).whenComplete(() {
    _propertiesLoadFuture = null;
  });
  return _propertiesLoadFuture!;
}

Future<void> loadMoreProperties() => loadProperties(reset: false);

Future<void> _loadPropertiesPage({required bool reset}) async {
  if (reset) {
    _loadedPropertyCount = 0;
    _hasMoreProperties = true;
  }

  try {
    final int from = _loadedPropertyCount;
    final int to = from + propertyPageSize - 1;
    final List<dynamic> response = await Supabase.instance.client
        .from('properties')
        .select('*, agent_teams(name)')
        .order('created_at', ascending: false)
        .range(from, to);

    final List<Property> loadedProperties = response
        .map((item) => Property.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();

    _loadedPropertyCount += loadedProperties.length;
    _hasMoreProperties = loadedProperties.length == propertyPageSize;

    if (reset) {
      appPropertiesNotifier.value = loadedProperties.isEmpty
          ? List<Property>.from(_fallbackProperties)
          : loadedProperties;
      return;
    }

    if (loadedProperties.isEmpty) return;

    final List<Property> currentProperties = List<Property>.from(
      appPropertiesNotifier.value,
    );
    final Set<String> existingIds = currentProperties
        .map((property) => property.id)
        .toSet();
    currentProperties.addAll(
      loadedProperties.where((property) => existingIds.add(property.id)),
    );
    appPropertiesNotifier.value = currentProperties;
  } catch (_) {
    if (reset) {
      _loadedPropertyCount = 0;
      appPropertiesNotifier.value = List<Property>.from(_fallbackProperties);
    }
    _hasMoreProperties = false;
  }
}

Future<Property> createProperty(Property property) async {
  final Map<String, dynamic> response = await Supabase.instance.client
      .from('properties')
      .insert(property.toInsertMap())
      .select('*, agent_teams(name)')
      .single();

  final Property createdProperty = Property.fromMap(
    Map<String, dynamic>.from(response),
  );

  appPropertiesNotifier.value = [
    createdProperty,
    ...appPropertiesNotifier.value,
  ];
  return createdProperty;
}

Future<Property> updateProperty(Property property) async {
  final Map<String, dynamic> response = await Supabase.instance.client
      .from('properties')
      .update(property.toUpdateMap())
      .eq('id', property.id)
      .select('*, agent_teams(name)')
      .single();

  final Property updatedProperty = Property.fromMap(
    Map<String, dynamic>.from(response),
  );
  final List<Property> updatedProperties = List<Property>.from(
    appPropertiesNotifier.value,
  );
  final int index = updatedProperties.indexWhere(
    (item) => item.id == updatedProperty.id,
  );

  if (index != -1) {
    updatedProperties[index] = updatedProperty;
    appPropertiesNotifier.value = updatedProperties;
  }

  return updatedProperty;
}

Future<void> deleteProperty(String propertyId) async {
  await Supabase.instance.client
      .from('properties')
      .delete()
      .eq('id', propertyId);

  appPropertiesNotifier.value = appPropertiesNotifier.value
      .where((property) => property.id != propertyId)
      .toList();
}
