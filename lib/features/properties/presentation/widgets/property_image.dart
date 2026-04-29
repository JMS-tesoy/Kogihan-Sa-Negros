import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../data/datasources/shared_properties.dart';

ImageProvider<Object>? propertyImageProvider(
  Property property, {
  int? targetWidth,
  bool useThumbnail = false,
}) {
  final String? imageUrl = resolvePropertyImageUrl(
    property,
    preferThumbnail: useThumbnail,
    targetWidth: useThumbnail ? targetWidth : null,
  );
  if (imageUrl == null || imageUrl.isEmpty) return null;
  if (imageUrl.startsWith('http')) {
    return CachedNetworkImageProvider(imageUrl);
  }
  return AssetImage(imageUrl);
}

ImageProvider<Object>? propertyDisplayImageProvider(
  BuildContext context,
  Property property, {
  required double height,
  bool useThumbnail = false,
}) {
  final double devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  final int targetWidth = (MediaQuery.sizeOf(context).width * 1.5)
      .round()
      .clamp(480, 900);
  final ImageProvider<Object>? imageProvider = propertyImageProvider(
    property,
    targetWidth: targetWidth,
    useThumbnail: useThumbnail,
  );
  if (imageProvider == null) return null;

  return ResizeImage.resizeIfNeeded(
    (MediaQuery.sizeOf(context).width * devicePixelRatio).round(),
    (height * devicePixelRatio).round(),
    imageProvider,
  );
}

void warmPropertyImage(
  BuildContext context,
  Property property, {
  double height = 210,
  bool useThumbnail = false,
}) {
  final ImageProvider<Object>? imageProvider = propertyDisplayImageProvider(
    context,
    property,
    height: height,
    useThumbnail: useThumbnail,
  );
  if (imageProvider == null) return;
  unawaited(precacheImage(imageProvider, context));
}

void scheduleInitialPropertyImageWarmup({
  required BuildContext context,
  required Iterable<Property> properties,
  required Set<String> warmedPropertyImageIds,
  required int count,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;

    for (final Property property in properties.take(count)) {
      if (warmedPropertyImageIds.add(property.id)) {
        warmPropertyImage(context, property, useThumbnail: true);
      }
    }
  });
}

Future<void> precachePropertyImage(
  BuildContext context,
  Property property, {
  double height = 210,
  bool useThumbnail = false,
}) async {
  final ImageProvider<Object>? imageProvider = propertyDisplayImageProvider(
    context,
    property,
    height: height,
    useThumbnail: useThumbnail,
  );
  if (imageProvider == null) return;
  await precacheImage(imageProvider, context);
}

Widget buildPropertyImage({
  required BuildContext context,
  required Property property,
  required double height,
  required Widget fallbackChild,
  BorderRadius? borderRadius,
  bool useThumbnail = false,
}) {
  final Widget fallback = Container(
    height: height,
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          property.imageColor,
          property.imageColor.withValues(alpha: 0.78),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: fallbackChild,
  );
  final Color shimmerHighlightColor = Color.alphaBlend(
    Colors.white.withValues(alpha: 0.34),
    property.imageColor,
  );
  final Widget loadingFallback = SizedBox(
    height: height,
    width: double.infinity,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Shimmer.fromColors(
          baseColor: property.imageColor,
          highlightColor: shimmerHighlightColor,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  property.imageColor,
                  property.imageColor.withValues(alpha: 0.78),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        fallbackChild,
      ],
    ),
  );

  final ImageProvider<Object>? imageProvider = propertyDisplayImageProvider(
    context,
    property,
    height: height,
    useThumbnail: useThumbnail,
  );
  if (imageProvider == null) {
    return borderRadius == null
        ? fallback
        : ClipRRect(borderRadius: borderRadius, child: fallback);
  }

  final Widget image = Image(
    image: imageProvider,
    height: height,
    width: double.infinity,
    fit: BoxFit.cover,
    filterQuality: FilterQuality.low,
    gaplessPlayback: true,
    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
      if (wasSynchronouslyLoaded || frame != null) {
        return child;
      }
      return loadingFallback;
    },
    loadingBuilder:
        resolvePropertyImageUrl(
              property,
              preferThumbnail: useThumbnail,
            )?.startsWith('http') ==
            true
        ? (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return loadingFallback;
          }
        : null,
    errorBuilder: (context, error, stackTrace) => fallback,
  );

  return borderRadius == null
      ? image
      : ClipRRect(borderRadius: borderRadius, child: image);
}

Widget buildPropertyDetailsImage({
  required BuildContext context,
  required Property property,
  required double height,
  required Widget fallbackChild,
  BorderRadius? borderRadius,
  bool useThumbnail = false,
}) {
  return buildPropertyImage(
    context: context,
    property: property,
    height: height,
    fallbackChild: fallbackChild,
    borderRadius: borderRadius,
    useThumbnail: useThumbnail,
  );
}
