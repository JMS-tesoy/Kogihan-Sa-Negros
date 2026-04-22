class PropertyImageEntity {
  const PropertyImageEntity({
    required this.id,
    required this.url,
    this.caption = '',
  });

  final String id;
  final String url;
  final String caption;
}
