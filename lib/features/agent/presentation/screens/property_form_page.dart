import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../location/data/datasources/negros_places_datasource.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../properties/data/datasources/shared_properties.dart';
import '../../data/services/agent_property_service.dart';
import '../widgets/property_basic_info_section.dart';

class PropertyFormPage extends StatefulWidget {
  final Property? initialProperty;

  const PropertyFormPage({super.key, this.initialProperty});

  @override
  State<PropertyFormPage> createState() => _PropertyFormPageState();
}

class _UploadedImageThumbnail extends StatelessWidget {
  const _UploadedImageThumbnail({
    required this.url,
    required this.isMainImage,
    required this.onRemove,
  });

  final String url;
  final bool isMainImage;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ImageProvider<Object> imageProvider = url.startsWith('http')
        ? CachedNetworkImageProvider(url)
        : AssetImage(url);

    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image(
                image: imageProvider,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                },
              ),
            ),
          ),
          if (isMainImage)
            Positioned(
              left: 4,
              bottom: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Text(
                    'Main',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyFormPageState extends State<PropertyFormPage> {
  static const List<String> _titleStatusOptions = [
    'Clean Title',
    'Transfer Certificate of Title',
    'Tax Declaration',
    'Mother Title',
    'CLOA',
    'Pending Verification',
  ];

  late final TextEditingController _referenceCodeController;
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _priceController;
  late final TextEditingController _sizeController;
  late final TextEditingController _statusController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _thumbnailUrlController;
  late final TextEditingController _galleryImageUrlsController;
  late final TextEditingController _boundaryCoordinatesController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingImage = false;
  bool _isLoadingTeamOptions = true;
  List<ListingTeamOption> _teamOptions = const <ListingTeamOption>[];
  String? _selectedAgentTeamId;
  late String _selectedTitleStatus;

  bool get _isEditing => widget.initialProperty != null;
  String get _previewReferenceCode {
    final String value = _referenceCodeController.text.trim();
    return value.isEmpty ? 'Listing code' : value;
  }

  String get _previewTitle {
    final String value = _titleController.text.trim();
    return value.isEmpty ? 'Property Title' : value;
  }

  String get _previewLocation {
    final String value = _locationController.text.trim();
    return value.isEmpty ? 'Grid coordinate' : value;
  }

  String get _previewPrice {
    final String value = _priceController.text.trim();
    return value.isEmpty ? '₱0' : value;
  }

  String get _previewSize {
    final String value = _sizeController.text.trim();
    return value.isEmpty ? 'Lot size not set' : value;
  }

  String get _previewTag {
    final String value = _statusController.text.trim();
    return value.isEmpty ? 'Active' : value;
  }

  String get _previewTitleStatus {
    final String value = _selectedTitleStatus.trim();
    return value.isEmpty ? 'Title status not set' : value;
  }

  String get _previewDescription {
    final String value = _descriptionController.text.trim();
    return value.isEmpty
        ? 'Add a property description so buyers understand the land offering.'
        : value;
  }

  String? get _selectedTeamName {
    for (final ListingTeamOption team in _teamOptions) {
      if (team.id == _selectedAgentTeamId) return team.name;
    }
    return widget.initialProperty?.agentTeamName;
  }

  String? get _previewImageSource {
    final String thumbnailUrl = _thumbnailUrlController.text.trim();
    if (thumbnailUrl.isNotEmpty) return thumbnailUrl;

    final String imageUrl = _imageUrlController.text.trim();
    return imageUrl.isEmpty ? null : imageUrl;
  }

  List<String> _galleryImageUrlsFromText() {
    final List<String> urls = <String>[];
    for (final String line in _galleryImageUrlsController.text.split('\n')) {
      final String url = line.trim();
      if (url.isNotEmpty && !urls.contains(url)) {
        urls.add(url);
      }
    }
    return urls;
  }

  List<String> get _mediaPreviewUrls {
    final List<String> urls = <String>[];

    void addUrl(String? value) {
      final String url = (value ?? '').trim();
      if (url.isNotEmpty && !urls.contains(url)) {
        urls.add(url);
      }
    }

    final String thumbnailUrl = _thumbnailUrlController.text.trim();
    final String imageUrl = _imageUrlController.text.trim();
    addUrl(thumbnailUrl.isNotEmpty ? thumbnailUrl : imageUrl);
    for (final String url in _galleryImageUrlsFromText()) {
      addUrl(url);
    }
    return urls;
  }

  void _addGalleryImageUrl(String imageUrl) {
    final List<String> urls = _galleryImageUrlsFromText();
    if (!urls.contains(imageUrl)) {
      urls.add(imageUrl);
    }
    _galleryImageUrlsController.text = urls.join('\n');
  }

  void _removeMediaPreviewUrl(String imageUrl) {
    final String normalizedUrl = imageUrl.trim();
    final bool isMainImage =
        _imageUrlController.text.trim() == normalizedUrl ||
        _thumbnailUrlController.text.trim() == normalizedUrl;
    if (isMainImage) {
      _imageUrlController.clear();
      _thumbnailUrlController.clear();
    }

    final List<String> urls = _galleryImageUrlsFromText()
        .where((url) => url != normalizedUrl)
        .toList();
    _galleryImageUrlsController.text = urls.join('\n');
    setState(() {});
  }

  ImageProvider<Object>? get _previewImageProvider {
    final String? imageSource = _previewImageSource;
    if (imageSource == null) return null;
    if (imageSource.startsWith('http')) {
      return CachedNetworkImageProvider(imageSource);
    }
    return AssetImage(imageSource);
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? helperText,
    int? maxLines,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: (_) => setState(() {}),
      minLines: maxLines != null && maxLines > 1 ? maxLines : 1,
      maxLines: maxLines ?? 1,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: helperText,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      ),
      validator: validator,
    );
  }

  Widget _buildUploadedImagePreviewStrip(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> urls = _mediaPreviewUrls;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Uploaded images',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: urls.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final String url = urls[index];
              return _UploadedImageThumbnail(
                url: url,
                isMainImage: index == 0,
                onRemove: () => _removeMediaPreviewUrl(url),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBoundaryGuidelines(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 18,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Start at any land corner, then enter the next corner beside it. '
            'You may paste the corners in any order, then tap Auto-arrange. '
            'The app sorts simple lot shapes around the center before saving. '
            'The map marker uses the boundary center when these points are added.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamSelectionField(BuildContext context) {
    final bool selectedTeamInOptions =
        _selectedAgentTeamId == null ||
        _teamOptions.any((team) => team.id == _selectedAgentTeamId);
    return DropdownButtonFormField<String?>(
      initialValue: selectedTeamInOptions ? _selectedAgentTeamId : null,
      onChanged: _isLoadingTeamOptions
          ? null
          : (value) {
              setState(() {
                _selectedAgentTeamId = value;
              });
            },
      decoration: InputDecoration(
        labelText: 'Agent team',
        helperText: _isLoadingTeamOptions
            ? 'Loading teams...'
            : 'Optional. Shows this team on property details.',
        prefixIcon: const Icon(Icons.groups_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      ),
      items: <DropdownMenuItem<String?>>[
        const DropdownMenuItem<String?>(value: null, child: Text('No team')),
        ..._teamOptions.map(
          (team) => DropdownMenuItem<String?>(
            value: team.id,
            child: Text(team.name, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    );
  }

  Future<void> _loadTeamOptions() async {
    try {
      final List<ListingTeamOption> teamOptions =
          await AgentPropertyService.fetchListingTeamOptions();

      if (!mounted) return;
      setState(() {
        _teamOptions = teamOptions;
        _isLoadingTeamOptions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _teamOptions = const <ListingTeamOption>[];
        _isLoadingTeamOptions = false;
      });
    }
  }

  Map<String, List<NegrosPlace>> _groupNegrosPlacesByProvince(
    List<NegrosPlace> places,
  ) {
    final Map<String, List<NegrosPlace>> groupedPlaces =
        <String, List<NegrosPlace>>{};

    for (final NegrosPlace place in places) {
      final String province = place.province.trim().isEmpty
          ? 'Other Areas'
          : place.province.trim();
      groupedPlaces.putIfAbsent(province, () => <NegrosPlace>[]).add(place);
    }

    for (final List<NegrosPlace> provincePlaces in groupedPlaces.values) {
      provincePlaces.sort(
        (first, second) => first.placeName.compareTo(second.placeName),
      );
    }

    return groupedPlaces;
  }

  Future<void> _pickNegrosPlaceForLocation() async {
    final List<NegrosPlace> places = List<NegrosPlace>.from(
      appNegrosPlacesNotifier.value,
    );
    if (places.isEmpty) return;

    final Map<String, List<NegrosPlace>> groupedPlaces =
        _groupNegrosPlacesByProvince(places);

    final NegrosPlace? selectedPlace = await showModalBottomSheet<NegrosPlace>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final ThemeData theme = Theme.of(sheetContext);

        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.72,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              children: [
                Text(
                  'Pick Negros Place',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose a place to fill this listing location with map coordinates.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                ...groupedPlaces.entries.map((entry) {
                  final List<NegrosPlace> provincePlaces = entry.value;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      leading: const Icon(Icons.location_city_outlined),
                      title: Text(entry.key),
                      subtitle: Text('${provincePlaces.length} places'),
                      children: provincePlaces
                          .map((place) {
                            return ListTile(
                              dense: true,
                              title: Text(place.placeName),
                              subtitle: Text(place.location),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () =>
                                  Navigator.of(sheetContext).pop(place),
                            );
                          })
                          .toList(growable: false),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (selectedPlace == null) return;

    setState(() {
      _locationController.text = selectedPlace.location;
    });
  }

  Widget _buildPreviewCard(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ImageProvider<Object>? imageProvider = _previewImageProvider;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: SizedBox(
              height: 132,
              width: double.infinity,
              child: imageProvider == null
                  ? Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              color: Colors.white,
                              size: 42,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Image preview will appear here',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Image(
                      image: imageProvider,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Center(
                            child: Text(
                              'Unable to load image preview',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.pin_outlined,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _previewReferenceCode,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _previewTag,
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _previewPrice,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _previewTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _previewLocation,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    Chip(
                      label: Text(_previewSize),
                      avatar: const Icon(Icons.straighten, size: 18),
                    ),
                    Chip(
                      label: Text(_previewTitleStatus),
                      avatar: const Icon(Icons.verified_outlined, size: 18),
                    ),
                    Chip(
                      label: Text(
                        _previewImageSource == null
                            ? 'No image yet'
                            : 'Image attached',
                      ),
                      avatar: const Icon(Icons.image_outlined, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _previewDescription,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadPropertyImage() async {
    if (_isUploadingImage) return;

    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      AppSnackBar.warning(context, 'Please sign in again before uploading.');
      return;
    }

    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 72,
      maxWidth: 1600,
      maxHeight: 1200,
    );

    if (pickedFile == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      final Uint8List bytes = await pickedFile.readAsBytes();
      final UploadedPropertyImage uploadedImage =
          await AgentPropertyService.uploadPropertyImage(
            bytes: bytes,
            userId: user.id,
          );

      setState(() {
        if (_imageUrlController.text.trim().isEmpty) {
          _imageUrlController.text = uploadedImage.publicUrl;
          _thumbnailUrlController.text = uploadedImage.thumbnailPublicUrl;
        } else {
          _addGalleryImageUrl(uploadedImage.publicUrl);
        }
      });

      if (!mounted) return;
      AppSnackBar.success(
        context,
        'Property image uploaded and optimized successfully.',
      );
    } on StorageException catch (error) {
      if (!mounted) return;
      AppSnackBar.error(context, 'Upload failed: ${error.message}');
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.error(context, 'Unexpected upload error: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _referenceCodeController = TextEditingController(
      text: widget.initialProperty?.referenceCode ?? '',
    );
    _titleController = TextEditingController(
      text: widget.initialProperty?.title ?? '',
    );
    _locationController = TextEditingController(
      text: widget.initialProperty?.location ?? '',
    );
    _priceController = TextEditingController(
      text: widget.initialProperty?.price ?? '',
    );
    _sizeController = TextEditingController(
      text: widget.initialProperty?.size ?? '',
    );
    _statusController = TextEditingController(
      text: widget.initialProperty?.tag ?? 'Active',
    );
    _selectedTitleStatus =
        widget.initialProperty?.titleStatus.trim().isNotEmpty == true
        ? widget.initialProperty!.titleStatus
        : _titleStatusOptions.first;
    _descriptionController = TextEditingController(
      text: widget.initialProperty?.description ?? '',
    );
    _imageUrlController = TextEditingController(
      text: widget.initialProperty?.imageUrl ?? '',
    );
    _thumbnailUrlController = TextEditingController(
      text: widget.initialProperty?.thumbnailUrl ?? '',
    );
    _galleryImageUrlsController = TextEditingController(
      text: widget.initialProperty?.galleryImageUrls.join('\n') ?? '',
    );
    _boundaryCoordinatesController = TextEditingController(
      text: widget.initialProperty?.boundaryCoordinates ?? '',
    );
    _selectedAgentTeamId = widget.initialProperty?.agentTeamId;
    unawaited(_loadTeamOptions());
  }

  @override
  void dispose() {
    _referenceCodeController.dispose();
    _titleController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _sizeController.dispose();
    _statusController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _thumbnailUrlController.dispose();
    _galleryImageUrlsController.dispose();
    _boundaryCoordinatesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final int parsedPriceValue = _extractNumber(_priceController.text);
    final int parsedSizeValue = _extractNumber(_sizeController.text);
    final String? arrangedBoundaryCoordinates =
        _arrangedBoundaryCoordinatesText();

    final Property property = Property(
      id:
          widget.initialProperty?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      referenceCode: _referenceCodeController.text.trim(),
      title: _titleController.text.trim(),
      location: _locationController.text.trim(),
      price: _priceController.text.trim(),
      priceValue: parsedPriceValue > 0 ? parsedPriceValue : 0,
      size: _sizeController.text.trim(),
      sizeValue: parsedSizeValue > 0 ? parsedSizeValue : 0,
      tag: _statusController.text.trim(),
      titleStatus: _selectedTitleStatus,
      description: _descriptionController.text.trim(),
      imageColor: widget.initialProperty?.imageColor ?? _randomColor(),
      imageUrl: _imageUrlController.text.trim().isEmpty
          ? null
          : _imageUrlController.text.trim(),
      thumbnailUrl: _thumbnailUrlController.text.trim().isEmpty
          ? null
          : _thumbnailUrlController.text.trim(),
      galleryImageUrls: _galleryImageUrlsFromText(),
      boundaryCoordinates: arrangedBoundaryCoordinates,
      agentId:
          widget.initialProperty?.agentId ??
          Supabase.instance.client.auth.currentUser?.id,
      agentTeamId: _selectedAgentTeamId,
      agentTeamName: _selectedTeamName,
    );

    Navigator.pop(context, property);
  }

  List<List<double>> _parseCoordinatePairs(String value) {
    final String normalized = value.trim().toUpperCase();
    if (normalized.isEmpty) return const <List<double>>[];

    if (RegExp(r'''['"′″]''').hasMatch(normalized)) {
      return const <List<double>>[];
    }

    final List<RegExpMatch> matches = RegExp(
      r'([-+]?\d+(?:\.\d+)?)\s*°?\s*([NSEW])?',
    ).allMatches(normalized).toList(growable: false);
    if (matches.length < 2) return const <List<double>>[];

    final List<List<double>> coordinatePairs = <List<double>>[];
    for (int index = 0; index + 1 < matches.length; index += 2) {
      double? latitude = double.tryParse(matches[index].group(1)!);
      double? longitude = double.tryParse(matches[index + 1].group(1)!);
      if (latitude == null || longitude == null) continue;

      final String? latitudeDirection = matches[index].group(2);
      final String? longitudeDirection = matches[index + 1].group(2);
      if (latitudeDirection == 'S') latitude = -latitude.abs();
      if (longitudeDirection == 'W') longitude = -longitude.abs();

      if (latitude < -90 || latitude > 90) continue;
      if (longitude < -180 || longitude > 180) continue;

      coordinatePairs.add(<double>[latitude, longitude]);
    }

    return coordinatePairs;
  }

  List<Offset> _boundaryPointsFromText(String value) {
    final List<Offset> parsedPoints = _parseCoordinatePairs(
      value,
    ).map((pair) => Offset(pair[1], pair[0])).toList(growable: true);

    if (parsedPoints.length > 1 &&
        _sameBoundaryPoint(parsedPoints.first, parsedPoints.last)) {
      parsedPoints.removeLast();
    }

    final List<Offset> uniquePoints = <Offset>[];
    for (final Offset point in parsedPoints) {
      if (!uniquePoints.any((item) => _sameBoundaryPoint(item, point))) {
        uniquePoints.add(point);
      }
    }

    return uniquePoints;
  }

  bool _sameBoundaryPoint(Offset first, Offset second) {
    const double tolerance = 0.0000001;
    return (first.dx - second.dx).abs() < tolerance &&
        (first.dy - second.dy).abs() < tolerance;
  }

  double _boundaryTurn(Offset first, Offset second, Offset third) {
    return (second.dx - first.dx) * (third.dy - first.dy) -
        (second.dy - first.dy) * (third.dx - first.dx);
  }

  bool _pointIsOnBoundarySegment(Offset point, Offset start, Offset end) {
    const double tolerance = 0.0000001;
    return point.dx >= min(start.dx, end.dx) - tolerance &&
        point.dx <= max(start.dx, end.dx) + tolerance &&
        point.dy >= min(start.dy, end.dy) - tolerance &&
        point.dy <= max(start.dy, end.dy) + tolerance &&
        _boundaryTurn(start, end, point).abs() < tolerance;
  }

  bool _boundarySegmentsIntersect(
    Offset firstStart,
    Offset firstEnd,
    Offset secondStart,
    Offset secondEnd,
  ) {
    const double tolerance = 0.0000001;
    final double turnOne = _boundaryTurn(firstStart, firstEnd, secondStart);
    final double turnTwo = _boundaryTurn(firstStart, firstEnd, secondEnd);
    final double turnThree = _boundaryTurn(secondStart, secondEnd, firstStart);
    final double turnFour = _boundaryTurn(secondStart, secondEnd, firstEnd);

    if (turnOne.abs() < tolerance &&
        _pointIsOnBoundarySegment(secondStart, firstStart, firstEnd)) {
      return true;
    }
    if (turnTwo.abs() < tolerance &&
        _pointIsOnBoundarySegment(secondEnd, firstStart, firstEnd)) {
      return true;
    }
    if (turnThree.abs() < tolerance &&
        _pointIsOnBoundarySegment(firstStart, secondStart, secondEnd)) {
      return true;
    }
    if (turnFour.abs() < tolerance &&
        _pointIsOnBoundarySegment(firstEnd, secondStart, secondEnd)) {
      return true;
    }

    return (turnOne > 0) != (turnTwo > 0) && (turnThree > 0) != (turnFour > 0);
  }

  bool _boundaryHasCrossingLines(List<Offset> points) {
    for (int firstIndex = 0; firstIndex < points.length; firstIndex++) {
      final int firstNextIndex = (firstIndex + 1) % points.length;
      final Offset firstStart = points[firstIndex];
      final Offset firstEnd = points[firstNextIndex];

      for (
        int secondIndex = firstIndex + 1;
        secondIndex < points.length;
        secondIndex++
      ) {
        final int secondNextIndex = (secondIndex + 1) % points.length;
        final bool sharesCorner =
            firstIndex == secondIndex ||
            firstIndex == secondNextIndex ||
            firstNextIndex == secondIndex ||
            firstNextIndex == secondNextIndex;
        if (sharesCorner) continue;

        if (_boundarySegmentsIntersect(
          firstStart,
          firstEnd,
          points[secondIndex],
          points[secondNextIndex],
        )) {
          return true;
        }
      }
    }
    return false;
  }

  List<Offset> _autoArrangeBoundaryPoints(List<Offset> points) {
    if (points.length < 3) return points;

    double longitudeTotal = 0;
    double latitudeTotal = 0;
    for (final Offset point in points) {
      longitudeTotal += point.dx;
      latitudeTotal += point.dy;
    }

    final Offset center = Offset(
      longitudeTotal / points.length,
      latitudeTotal / points.length,
    );
    final List<Offset> arrangedPoints = List<Offset>.from(points);
    arrangedPoints.sort((first, second) {
      final double firstAngle = atan2(
        first.dy - center.dy,
        first.dx - center.dx,
      );
      final double secondAngle = atan2(
        second.dy - center.dy,
        second.dx - center.dx,
      );
      return firstAngle.compareTo(secondAngle);
    });

    return arrangedPoints;
  }

  String _formatBoundaryCoordinate(double value) {
    return value
        .toStringAsFixed(7)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _boundaryTextFromPoints(List<Offset> points) {
    return points
        .map(
          (point) =>
              '${_formatBoundaryCoordinate(point.dy)}, ${_formatBoundaryCoordinate(point.dx)}',
        )
        .join('\n');
  }

  String? _arrangedBoundaryCoordinatesText() {
    final String normalized = _boundaryCoordinatesController.text.trim();
    if (normalized.isEmpty) return null;

    final List<Offset> points = _boundaryPointsFromText(normalized);
    if (points.length < 3) return normalized;

    return _boundaryTextFromPoints(_autoArrangeBoundaryPoints(points));
  }

  void _autoArrangeBoundaryCoordinates() {
    final String? arrangedText = _arrangedBoundaryCoordinatesText();
    if (arrangedText == null) return;

    _boundaryCoordinatesController.text = arrangedText;
    setState(() {});
    _formKey.currentState?.validate();
  }

  String? _validateBoundaryCoordinates(String? value) {
    final String normalized = (value ?? '').trim();
    if (normalized.isEmpty) return null;

    final List<Offset> points = _boundaryPointsFromText(normalized);
    if (points.length < 3) {
      return 'Add at least 3 valid latitude, longitude points.';
    }
    final List<Offset> arrangedPoints = _autoArrangeBoundaryPoints(points);
    if (_boundaryHasCrossingLines(arrangedPoints)) {
      return 'Auto-arrange could not fix this shape. Check the corner points.';
    }
    return null;
  }

  int _extractNumber(String input) {
    final String digitsOnly = input.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digitsOnly) ?? 0;
  }

  Color _randomColor() {
    final List<Color> colors = [
      const Color(0xFF9CCC65),
      const Color(0xFFA1887F),
      const Color(0xFF64B5F6),
      const Color(0xFFBA68C8),
      const Color(0xFFFFB74D),
    ];
    return colors[Random().nextInt(colors.length)];
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Property' : 'Add New Property'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.78),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEditing ? 'Update Listing' : 'Create New Listing',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Fill the form, preview it, then save.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimary.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildPreviewCard(context),
            const SizedBox(height: 12),
            PropertyBasicInfoSection(
              referenceCodeController: _referenceCodeController,
              titleController: _titleController,
              locationController: _locationController,
              priceController: _priceController,
              sizeController: _sizeController,
              statusController: _statusController,
              selectedTitleStatus: _selectedTitleStatus,
              titleStatusOptions: _titleStatusOptions,
              onFieldChanged: () => setState(() {}),
              onPickNegrosPlace: _pickNegrosPlaceForLocation,
              onTitleStatusChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedTitleStatus = value;
                });
              },
              referenceCodeValidator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a listing code.';
                }
                return null;
              },
              titleValidator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a clean title.';
                }
                return null;
              },
              locationValidator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a location or area.';
                }
                return null;
              },
              priceValidator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a price.';
                }
                return null;
              },
              sizeValidator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a lot size.';
                }
                return null;
              },
              statusValidator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a card tag.';
                }
                return null;
              },
              titleStatusValidator: (selectedValue) {
                if (selectedValue == null || selectedValue.trim().isEmpty) {
                  return 'Please select a title status.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildSectionCard(
              context: context,
              title: 'Agent Team',
              subtitle:
                  'Choose which verified team should appear on this listing.',
              children: [_buildTeamSelectionField(context)],
            ),
            const SizedBox(height: 12),
            _buildSectionCard(
              context: context,
              title: 'Listing Content',
              subtitle:
                  'Describe the land clearly so buyers understand the offer before they inquire.',
              children: [
                _buildFormField(
                  controller: _descriptionController,
                  label: 'Description',
                  hintText:
                      'Describe access, terrain, nearby landmarks, ideal use, and key selling points.',
                  icon: Icons.description_outlined,
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a property description.';
                    }
                    return null;
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSectionCard(
              context: context,
              title: 'Map Boundary',
              subtitle:
                  'Optional. Add surveyed lot corners so buyers can see the land outline on the map.',
              children: [
                _buildBoundaryGuidelines(context),
                const SizedBox(height: 12),
                _buildFormField(
                  controller: _boundaryCoordinatesController,
                  label: 'Boundary coordinates',
                  hintText:
                      '9.3077, 123.3054\n9.3078, 123.3060\n9.3071, 123.3061\n9.3070, 123.3055',
                  icon: Icons.polyline_outlined,
                  keyboardType: TextInputType.multiline,
                  maxLines: 4,
                  helperText:
                      'At least 3 points. One corner per line. The first point is closed automatically.',
                  validator: _validateBoundaryCoordinates,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _autoArrangeBoundaryCoordinates,
                    icon: const Icon(Icons.reorder_rounded),
                    label: const Text('Auto-arrange points'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSectionCard(
              context: context,
              title: 'Media',
              subtitle:
                  'Attach an image URL to make the listing preview more complete.',
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isUploadingImage
                        ? null
                        : _pickAndUploadPropertyImage,
                    icon: _isUploadingImage
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload_outlined),
                    label: Text(
                      _isUploadingImage
                          ? 'Uploading image...'
                          : 'Upload Image From Device',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                if (_mediaPreviewUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildUploadedImagePreviewStrip(context),
                ],
                const SizedBox(height: 12),
                _buildFormField(
                  controller: _imageUrlController,
                  label: 'Image URL (optional)',
                  hintText: 'https://example.com/property.jpg',
                  icon: Icons.image_outlined,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                _buildFormField(
                  controller: _thumbnailUrlController,
                  label: 'Thumbnail URL (optional)',
                  hintText: 'https://example.com/property-thumb.jpg',
                  icon: Icons.photo_size_select_small_outlined,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                _buildFormField(
                  controller: _galleryImageUrlsController,
                  label: 'Gallery image URLs (optional)',
                  hintText:
                      'https://example.com/gallery-1.jpg\nhttps://example.com/gallery-2.jpg',
                  icon: Icons.photo_library_outlined,
                  keyboardType: TextInputType.multiline,
                  maxLines: 4,
                  helperText:
                      'One image URL per line. These appear as right-side thumbnails on property details.',
                ),
                if (_imageUrlController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _imageUrlController.clear();
                          _thumbnailUrlController.clear();
                          _galleryImageUrlsController.clear();
                        });
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove image'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(_isEditing ? 'Save Changes' : 'Add Property'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
