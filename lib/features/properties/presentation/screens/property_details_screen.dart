import 'package:flutter/material.dart';

import '../../data/datasources/shared_properties.dart';
import 'contact_agent_screen.dart';
import '../widgets/property_image.dart';
import '../widgets/property_map_preview.dart';

class PropertyDetailsScreen extends StatefulWidget {
  const PropertyDetailsScreen({
    super.key,
    required this.property,
    required this.isSaved,
    required this.onToggleSave,
  });

  final Property property;
  final bool isSaved;
  final VoidCallback onToggleSave;

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  late bool _isSaved;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.isSaved;
    _recordView();
  }

  Future<void> _recordView() async {
    await recordPropertyView(widget.property);
  }

  void _handleToggleSave() {
    setState(() => _isSaved = !_isSaved);
    widget.onToggleSave();
  }

  @override
  Widget build(BuildContext context) {
    final Property property = widget.property;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            stretch: true,
            backgroundColor: colorScheme.surface,
            foregroundColor: colorScheme.onSurface,
            title: const SizedBox.shrink(),
            actions: <Widget>[
              _SaveButton(isSaved: _isSaved, onTap: _handleToggleSave),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const <StretchMode>[StretchMode.zoomBackground],
              background: _PropertyDetailsGallery(
                property: property,
                height: 280,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _PriceHeader(
                  property: property,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
                const Divider(height: 1),
                _BadgesRow(
                  property: property,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
                const Divider(height: 1),
                _DescriptionSection(
                  property: property,
                  textTheme: textTheme,
                  colorScheme: colorScheme,
                ),
                if (_hasAgentInfo(property)) ...<Widget>[
                  const Divider(height: 1),
                  _AgentTeamSection(
                    property: property,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                ],
                const Divider(height: 1),
                _MapSection(property: property),
                const Divider(height: 1),
                _MetaSection(
                  property: property,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _ContactBar(property: property),
    );
  }
}

bool _hasAgentInfo(Property property) {
  return (property.agentFullName ?? '').trim().isNotEmpty ||
      (property.agentEmail ?? '').trim().isNotEmpty ||
      (property.agentPhone ?? '').trim().isNotEmpty ||
      (property.agentTeamName ?? '').trim().isNotEmpty ||
      (property.agentId ?? '').trim().isNotEmpty;
}

// ─── Image Gallery ────────────────────────────────────────────────────────────

class _PropertyDetailsGallery extends StatefulWidget {
  const _PropertyDetailsGallery({required this.property, required this.height});

  final Property property;
  final double height;

  @override
  State<_PropertyDetailsGallery> createState() =>
      _PropertyDetailsGalleryState();
}

class _PropertyDetailsGalleryState extends State<_PropertyDetailsGallery> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<String> get _imageUrls {
    final List<String> urls = <String>[];

    void addUrl(String? value) {
      final String normalized = (value ?? '').trim();
      if (normalized.isNotEmpty && !urls.contains(normalized)) {
        urls.add(normalized);
      }
    }

    addUrl(widget.property.imageUrl);
    for (final String url in widget.property.galleryImageUrls) {
      addUrl(url);
    }
    if (urls.isEmpty) {
      addUrl(widget.property.thumbnailUrl);
    }

    return urls;
  }

  List<String> get _thumbnailUrls {
    final List<String> imageUrls = _imageUrls;
    return List<String>.generate(imageUrls.length, (index) {
      if (index == 0 &&
          (widget.property.thumbnailUrl ?? '').trim().isNotEmpty) {
        return widget.property.thumbnailUrl!.trim();
      }
      return imageUrls[index];
    });
  }

  void _showImage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> imageUrls = _imageUrls;
    final List<String> thumbnailUrls = _thumbnailUrls;
    final double statusTop = MediaQuery.paddingOf(context).top;
    final double imageHeight = widget.height > statusTop
        ? widget.height - statusTop
        : widget.height;
    final double thumbnailTop = statusTop + kToolbarHeight + 8;
    if (imageUrls.isEmpty) {
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          children: <Widget>[
            Positioned(
              top: statusTop,
              left: 0,
              right: 0,
              bottom: 0,
              child: buildPropertyDetailsImage(
                context: context,
                property: widget.property,
                height: imageHeight,
                useThumbnail: false,
                fallbackChild: _GalleryFallback(property: widget.property),
              ),
            ),
            if (statusTop > 0)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: statusTop,
                child: ColoredBox(color: Theme.of(context).colorScheme.surface),
              ),
          ],
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        children: <Widget>[
          Positioned(
            top: statusTop,
            left: 0,
            right: 0,
            bottom: 0,
            child: PageView.builder(
              controller: _pageController,
              itemCount: imageUrls.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                return _GalleryImage(
                  url: imageUrls[index],
                  property: widget.property,
                  height: imageHeight,
                );
              },
            ),
          ),
          if (statusTop > 0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: statusTop,
              child: ColoredBox(color: Theme.of(context).colorScheme.surface),
            ),
          Positioned(
            left: 10,
            bottom: 10,
            child: Transform.scale(
              scale: 0.65,
              alignment: Alignment.bottomLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.38),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: Text(
                    '${_currentIndex + 1}/${imageUrls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 18,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(imageUrls.length, (index) {
                final bool isActive = index == _currentIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: isActive ? 0.95 : 0.62,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
          ),
          Positioned(
            top: thumbnailTop,
            right: 7,
            bottom: 16,
            child: SizedBox(
              width: 50,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: thumbnailUrls.length,
                separatorBuilder: (context, index) => const SizedBox(height: 7),
                itemBuilder: (context, index) {
                  return _GalleryThumbnail(
                    url: thumbnailUrls[index],
                    isSelected: index == _currentIndex,
                    onTap: () => _showImage(index),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryThumbnail extends StatelessWidget {
  const _GalleryThumbnail({
    required this.url,
    required this.isSelected,
    required this.onTap,
  });

  final String url;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ImageProvider<Object> provider = ResizeImage(
      url.startsWith('http') ? NetworkImage(url) : AssetImage(url),
      width: 96,
      height: 96,
    );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.black.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(
            color: Colors.white.withValues(alpha: isSelected ? 0.55 : 0.38),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image(
                  image: provider,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (context, error, stackTrace) {
                    return const ColoredBox(
                      color: Colors.black26,
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryImage extends StatelessWidget {
  const _GalleryImage({
    required this.url,
    required this.property,
    required this.height,
  });

  final String url;
  final Property property;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ImageProvider<Object> provider = url.startsWith('http')
        ? NetworkImage(url)
        : AssetImage(url);

    return Image(
      image: provider,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        return _GalleryFallback(property: property);
      },
    );
  }
}

class _GalleryFallback extends StatelessWidget {
  const _GalleryFallback({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.landscape_rounded,
        color: Colors.white.withValues(alpha: 0.7),
        size: 56,
      ),
    );
  }
}

// ─── Save Button ─────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.isSaved, required this.onTap});

  final bool isSaved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          isSaved ? Icons.favorite : Icons.favorite_border_rounded,
          size: 20,
          color: isSaved ? Colors.red : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ─── Price Header ─────────────────────────────────────────────────────────────

class _PriceHeader extends StatelessWidget {
  const _PriceHeader({
    required this.property,
    required this.colorScheme,
    required this.textTheme,
  });

  final Property property;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            property.price,
            style: textTheme.headlineMedium?.copyWith(
              fontSize: 18,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            property.title,
            style: textTheme.titleLarge?.copyWith(
              fontSize: 18,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.location_on_outlined,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  property.location,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Badges Row ───────────────────────────────────────────────────────────────

class _BadgesRow extends StatelessWidget {
  const _BadgesRow({
    required this.property,
    required this.colorScheme,
    required this.textTheme,
  });

  final Property property;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          if (property.titleStatus.isNotEmpty)
            _Badge(
              label: property.titleStatus,
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
            ),
          if (property.tag.isNotEmpty)
            _Badge(
              label: property.tag,
              backgroundColor: colorScheme.secondaryContainer,
              foregroundColor: colorScheme.onSecondaryContainer,
            ),
          if (property.size.isNotEmpty)
            _Badge(
              icon: Icons.straighten_outlined,
              label: property.size,
              backgroundColor: colorScheme.surfaceContainerHighest,
              foregroundColor: colorScheme.onSurface,
            ),
          if (property.viewCount > 0)
            _Badge(
              icon: Icons.visibility_outlined,
              label: '${property.viewCount} views',
              backgroundColor: colorScheme.surfaceContainerHighest,
              foregroundColor: colorScheme.onSurfaceVariant,
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.icon,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 13, color: foregroundColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Description ──────────────────────────────────────────────────────────────

class _DescriptionSection extends StatefulWidget {
  const _DescriptionSection({
    required this.property,
    required this.textTheme,
    required this.colorScheme,
  });

  final Property property;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  @override
  State<_DescriptionSection> createState() => _DescriptionSectionState();
}

class _DescriptionSectionState extends State<_DescriptionSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final String description = widget.property.description.trim();
    if (description.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'About this Property',
            style: widget.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          AnimatedCrossFade(
            firstChild: Text(
              description,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: widget.textTheme.bodyMedium?.copyWith(
                color: widget.colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
            secondChild: Text(
              description,
              style: widget.textTheme.bodyMedium?.copyWith(
                color: widget.colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
          if (description.length > 200) ...<Widget>[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded ? 'Show less' : 'Read more',
                style: TextStyle(
                  color: widget.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Agent Team ───────────────────────────────────────────────────────────────

class _AgentTeamSection extends StatelessWidget {
  const _AgentTeamSection({
    required this.property,
    required this.colorScheme,
    required this.textTheme,
  });

  final Property property;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final String agentName = (property.agentFullName ?? '').trim().isNotEmpty
        ? property.agentFullName!.trim()
        : 'Assigned Agent';
    final String? agentPhone = (property.agentPhone ?? '').trim().isNotEmpty
        ? property.agentPhone!.trim()
        : null;
    final String? agentEmail = (property.agentEmail ?? '').trim().isNotEmpty
        ? property.agentEmail!.trim()
        : null;
    final String? agentTeamName =
        (property.agentTeamName ?? '').trim().isNotEmpty
        ? property.agentTeamName!.trim()
        : null;
    final String? agentAvatarUrl =
        (property.agentAvatarUrl ?? '').trim().isNotEmpty
        ? property.agentAvatarUrl!.trim()
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Listed By',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              _AgentAvatar(
                avatarUrl: agentAvatarUrl,
                backgroundColor: colorScheme.primaryContainer,
                iconColor: colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      agentName,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (agentTeamName != null)
                      Text(
                        agentTeamName,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (agentPhone != null || agentEmail != null) ...<Widget>[
                      const SizedBox(height: 4),
                      if (agentPhone != null)
                        _AgentContactLine(
                          icon: Icons.call_outlined,
                          value: agentPhone,
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                        ),
                      if (agentEmail != null)
                        _AgentContactLine(
                          icon: Icons.mail_outline,
                          value: agentEmail,
                          colorScheme: colorScheme,
                          textTheme: textTheme,
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AgentAvatar extends StatelessWidget {
  const _AgentAvatar({
    required this.avatarUrl,
    required this.backgroundColor,
    required this.iconColor,
  });

  final String? avatarUrl;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final String? url = avatarUrl;
    return CircleAvatar(
      radius: 22,
      backgroundColor: backgroundColor,
      backgroundImage: url != null && url.startsWith('http')
          ? NetworkImage(url)
          : null,
      child: url == null || !url.startsWith('http')
          ? Icon(Icons.person_outline, color: iconColor, size: 22)
          : null,
    );
  }
}

class _AgentContactLine extends StatelessWidget {
  const _AgentContactLine({
    required this.icon,
    required this.value,
    required this.colorScheme,
    required this.textTheme,
  });

  final IconData icon;
  final String value;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Map Section ──────────────────────────────────────────────────────────────

class _MapSection extends StatelessWidget {
  const _MapSection({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Location',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: PropertyMapPreview(
              boundaryCoordinates: property.boundaryCoordinates,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Icon(
                Icons.location_on_outlined,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  property.location,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Meta Info ────────────────────────────────────────────────────────────────

class _MetaSection extends StatelessWidget {
  const _MetaSection({
    required this.property,
    required this.colorScheme,
    required this.textTheme,
  });

  final Property property;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Property Details',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _MetaRow(
            icon: Icons.tag_outlined,
            label: 'Reference',
            value: property.referenceCode,
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
          const SizedBox(height: 10),
          _MetaRow(
            icon: Icons.straighten_outlined,
            label: 'Size',
            value: property.size,
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
          const SizedBox(height: 10),
          _MetaRow(
            icon: Icons.description_outlined,
            label: 'Title Status',
            value: property.titleStatus,
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
          const SizedBox(height: 10),
          _MetaRow(
            icon: Icons.sell_outlined,
            label: 'Listing Type',
            value: property.tag,
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.colorScheme,
    required this.textTheme,
  });

  final IconData icon;
  final String label;
  final String value;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: <TextSpan>[
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: value.isNotEmpty ? value : '-',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Contact Bar ──────────────────────────────────────────────────────────────

class _ContactBar extends StatelessWidget {
  const _ContactBar({required this.property});

  final Property property;

  void _openInquiry(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ContactAgentPage(property: property),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _openInquiry(context),
                icon: const Icon(Icons.message_outlined),
                label: const Text('Message Agent'),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () {},
              child: const Icon(Icons.call_outlined),
            ),
          ],
        ),
      ),
    );
  }
}
