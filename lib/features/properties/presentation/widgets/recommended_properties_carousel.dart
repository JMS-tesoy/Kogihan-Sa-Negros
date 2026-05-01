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
  final void Function(BuildContext context, Property property)
  onPrecacheDetails;

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
  late final PageController _pageController;
  final Set<String> _warmedDetailImageIds = <String>{};
  int _currentPage = 0;
  double _pageOffset = 0;
  static const double _indicatorHeight = 19;
  static const double _viewportFraction = 0.90;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: _viewportFraction);
    _pageController.addListener(_handleCarouselScroll);
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
    if (!_pageController.hasClients || widget.properties.isEmpty) return;

    final double nextOffset = _pageController.page ?? _currentPage.toDouble();

    final int nextPage = math.max(
      0,
      math.min(widget.properties.length - 1, nextOffset.round()),
    );

    if (nextPage == _currentPage && nextOffset == _pageOffset) return;
    setState(() {
      _currentPage = nextPage;
      _pageOffset = nextOffset;
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
      _pageOffset = _currentPage.toDouble();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        unawaited(
          _pageController.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_handleCarouselScroll);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.properties.isEmpty) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double textScale = MediaQuery.textScalerOf(
      context,
    ).scale(1).clamp(0.9, 1.15).toDouble();
    final bool hasTeamInfo = widget.properties.any(
      (property) => (property.agentTeamName ?? '').trim().isNotEmpty,
    );
    final double baseCardHeight = (screenWidth * 0.82)
        .clamp(292.0, 328.0)
        .toDouble();
    final double activeCardHeight =
        baseCardHeight + (hasTeamInfo ? 24 : 0) + ((textScale - 1) * 42);
    final double activeImageHeight = (screenWidth * 0.52)
        .clamp(178.0, 210.0)
        .toDouble();
    final double inactiveImageHeight = (activeImageHeight * 0.74)
        .clamp(132.0, 156.0)
        .toDouble();

    return SizedBox(
      height:
          activeCardHeight +
          (widget.properties.length > 1 ? _indicatorHeight : 0),
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              clipBehavior: Clip.none,
              physics: const BouncingScrollPhysics(),
              itemCount: widget.properties.length,
              itemBuilder: (context, index) {
                final Property property = widget.properties[index];
                final bool isActive = index == _currentPage;
                final double pageDistance = (_pageOffset - index)
                    .abs()
                    .clamp(0.0, 1.0)
                    .toDouble();
                final double scale = 1 - (pageDistance * 0.10);
                final double opacity = 1 - (pageDistance * 0.32);
                final double verticalOffset = pageDistance * 14;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Transform.translate(
                    offset: Offset(0, verticalOffset),
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.topCenter,
                      child: Opacity(
                        opacity: opacity,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            height: activeCardHeight,
                            child: RecommendedPropertyCard(
                              property: property,
                              isSaved: widget.savedProperties.contains(
                                property,
                              ),
                              isActive: isActive,
                              onToggleSave: () => widget.onToggleSave(property),
                              onOpenDetails: () =>
                                  widget.onOpenDetails(property),
                              activeImageHeight: activeImageHeight,
                              inactiveImageHeight: inactiveImageHeight,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.properties.length > 1) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.properties.length, (index) {
                final bool isActive = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  width: isActive ? 22 : 7,
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
