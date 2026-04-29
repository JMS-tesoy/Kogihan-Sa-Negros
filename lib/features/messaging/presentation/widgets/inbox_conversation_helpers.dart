import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../data/services/messaging_service.dart';

String messageInitial(String value) {
  final String trimmed = value.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed[0].toUpperCase();
}

String formatInboxTimestamp(DateTime? value) {
  if (value == null) return '';

  const List<String> months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final DateTime localValue = value.toLocal();
  final int hour = localValue.hour % 12 == 0 ? 12 : localValue.hour % 12;
  final String minute = localValue.minute.toString().padLeft(2, '0');
  final String suffix = localValue.hour >= 12 ? 'PM' : 'AM';

  return '${months[localValue.month - 1]} ${localValue.day}, $hour:$minute $suffix';
}

String buyerInboxConversationTitle(ConversationSummary conversation) {
  final String propertyTitle = (conversation.propertyTitle ?? '').trim();
  if (propertyTitle.isNotEmpty) return propertyTitle;
  return conversation.title;
}

ImageProvider<Object>? buyerInboxConversationImageProvider(
  BuildContext context,
  ConversationSummary conversation,
) {
  final String? rawImageUrl = (() {
    final String thumbnailUrl = (conversation.propertyThumbnailUrl ?? '')
        .trim();
    if (thumbnailUrl.isNotEmpty) return thumbnailUrl;

    final String imageUrl = (conversation.propertyImageUrl ?? '').trim();
    if (imageUrl.isNotEmpty) return imageUrl;

    return null;
  })();

  if (rawImageUrl == null || rawImageUrl.isEmpty) return null;
  if (rawImageUrl.startsWith('http')) {
    return CachedNetworkImageProvider(rawImageUrl);
  }
  return AssetImage(rawImageUrl);
}
