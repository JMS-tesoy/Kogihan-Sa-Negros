import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../properties/data/datasources/shared_properties.dart';
import 'property_form_page.dart';

class ManagePropertiesPage extends StatefulWidget {
  final List<Property> properties;
  final Future<void> Function(Property property) onUpdateProperty;
  final Future<void> Function(String propertyId) onDeleteProperty;

  const ManagePropertiesPage({
    super.key,
    required this.properties,
    required this.onUpdateProperty,
    required this.onDeleteProperty,
  });

  @override
  State<ManagePropertiesPage> createState() => _ManagePropertiesPageState();
}

class _ManagePropertiesPageState extends State<ManagePropertiesPage> {
  late List<Property> _properties;
  final Set<String> _warmedPropertyImageIds = <String>{};

  ImageProvider<Object>? _managePropertyImageProvider(Property property) {
    final String? imageUrl = resolvePropertyImageUrl(
      property,
      preferThumbnail: true,
      targetWidth: 720,
    );
    if (imageUrl == null || imageUrl.isEmpty) return null;
    if (imageUrl.startsWith('http')) {
      return CachedNetworkImageProvider(imageUrl);
    }
    return AssetImage(imageUrl);
  }

  void _warmInitialPropertyImages() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      for (final Property property in _properties.take(4)) {
        final ImageProvider<Object>? imageProvider =
            _managePropertyImageProvider(property);
        if (imageProvider == null) continue;
        if (_warmedPropertyImageIds.add(property.id)) {
          unawaited(precacheImage(imageProvider, context));
        }
      }
    });
  }

  Widget _buildManagePropertyCard(BuildContext context, Property property) {
    final ThemeData theme = Theme.of(context);
    final ImageProvider<Object>? imageProvider = _managePropertyImageProvider(
      property,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 88,
            width: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(
                  child: imageProvider != null
                      ? Image(
                          image: imageProvider,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: theme.colorScheme.primaryContainer,
                              child: Icon(
                                Icons.landscape_rounded,
                                color: theme.colorScheme.onPrimaryContainer,
                                size: 34,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: theme.colorScheme.primaryContainer,
                          child: Icon(
                            Icons.landscape_rounded,
                            color: theme.colorScheme.onPrimaryContainer,
                            size: 34,
                          ),
                        ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      property.tag,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          property.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    property.location,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${property.price} • ${property.size}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          property.titleStatus,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _editProperty(property),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            minimumSize: const Size.fromHeight(38),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('Edit'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: () => _deleteProperty(property),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            minimumSize: const Size.fromHeight(38),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('Delete'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _properties = List<Property>.from(widget.properties);
    _warmInitialPropertyImages();
  }

  Future<void> _editProperty(Property property) async {
    final Property? updatedProperty = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PropertyFormPage(initialProperty: property),
      ),
    );

    if (updatedProperty == null || !mounted) return;

    final int index = _properties.indexWhere(
      (item) => item.id == updatedProperty.id,
    );

    if (index == -1) return;

    setState(() {
      _properties[index] = updatedProperty;
    });
    await widget.onUpdateProperty(updatedProperty);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${updatedProperty.title} updated successfully.')),
    );
  }

  Future<void> _deleteProperty(Property property) async {
    setState(() {
      _properties.removeWhere((item) => item.id == property.id);
    });
    await widget.onDeleteProperty(property.id);
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${property.title} deleted.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Properties')),
      body: _properties.isEmpty
          ? const Center(child: Text('No properties available.'))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 360,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 292,
              ),
              itemCount: _properties.length,
              itemBuilder: (context, index) {
                final Property property = _properties[index];
                return _buildManagePropertyCard(context, property);
              },
            ),
    );
  }
}
