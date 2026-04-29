import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/config/app_config.dart';
import '../../data/datasources/shared_properties.dart';
import 'recommended_property_card.dart';

class RecommendedPropertiesCarousel extends StatefulWidget {
  final List<Property> properties;
  final Set<Property> savedProperties;
  final ValueChanged<Property> onToggleSave;
  final ValueChanged<Property> onOpenDetails;
  final void Function(BuildContext context, Property property) onPrecacheDetails;

  const RecommendedPropertiesCarousel({
    super.key,
    required this.properties,
    required this.savedProperties,
    required this.onToggleSave,
    required this.onOpenDetails,
    required this.onPrecacheDetails,
  });

  @override
  State<RecommendedPropertiesCarousel> createState() =>
      _RecommendedPropertiesCarouselState();
}

class _RecommendedPropertiesCarouselState
    extends State<RecommendedPropertiesCarousel> {
  late final CarouselController _carouselController;
  final Set<String> _warmedDetailImageIds = <String>{};
  int _currentPage = 0;
  static const List<int> _carouselWeights = <int>[1];
  static const double _activeCardHeight = 265;
  static const double _indicatorHeight = 19;

  @override
  void initState() {
    super.initState();
    _carouselController = CarouselController();
    _carouselController.addListener(_handleCarouselScroll);
    _warmRecommendedDetailImages();
  }

  void _warmRecommendedDetailImages() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      for (final Property property in widget.properties.take(
        AppConfig.initialPropertyImagePrefetchCount,
      )) {
        if (_warmedDetailImageIds.add(property.id)) {
          widget.onPrecacheDetails(context, property);
        }
      }
    });
  }

  void _handleCarouselScroll() {
    if (!_carouselController.hasClients || widget.properties.isEmpty) return;

    final ScrollPosition position = _carouselController.position;
    if (!position.hasViewportDimension || position.viewportDimension == 0) {
      return;
    }

    final double itemScrollExtent =
        position.viewportDimension /
        _carouselWeights.reduce((value, element) => value + element);
    if (itemScrollExtent == 0) return;

    final int nextPage = math.max(
      0,
      math.min(
        widget.properties.length - 1,
        (_carouselController.offset / itemScrollExtent).round(),
      ),
    );

    if (nextPage == _currentPage) return;
    setState(() {
      _currentPage = nextPage;
    });
  }

  @override
  void didUpdateWidget(covariant RecommendedPropertiesCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _warmRecommendedDetailImages();

    if (widget.properties.isEmpty) {
      _currentPage = 0;
      return;
    }

    if (_currentPage >= widget.properties.length) {
      _currentPage = widget.properties.length - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_carouselController.hasClients) return;
        unawaited(_carouselController.animateToItem(_currentPage));
      });
    }
  }

  @override
  void dispose() {
    _carouselController.removeListener(_handleCarouselScroll);
    _carouselController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.properties.isEmpty) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);

    return SizedBox(
      height:
          _activeCardHeight +
          (widget.properties.length > 1 ? _indicatorHeight : 0),
      child: Column(
        children: [
          Expanded(
            child: CarouselView.weighted(
              controller: _carouselController,
              itemSnapping: true,
              flexWeights: _carouselWeights,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              backgroundColor: Colors.transparent,
              elevation: 0,
              itemClipBehavior: Clip.none,
              enableSplash: false,
              children: List<Widget>.generate(widget.properties.length, (
                index,
              ) {
                final Property property = widget.properties[index];
                final bool isActive = index == _currentPage;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      height: _activeCardHeight,
                      child: RecommendedPropertyCard(
                        property: property,
                        isSaved: widget.savedProperties.contains(property),
                        isActive: isActive,
                        onToggleSave: () => widget.onToggleSave(property),
                        onOpenDetails: () => widget.onOpenDetails(property),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          if (widget.properties.length > 1) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.properties.length, (index) {
                final bool isActive = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: isActive ? 18 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}
