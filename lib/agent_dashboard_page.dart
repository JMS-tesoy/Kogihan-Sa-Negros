import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'messaging_service.dart';
import 'negros_places.dart';
import 'shared_properties.dart';

String _formatInboxTime(DateTime? value) {
  if (value == null) return '';

  final DateTime localValue = value.toLocal();
  final DateTime now = DateTime.now();
  final Duration difference = now.difference(localValue);

  if (difference.inDays == 0) {
    final int hour = localValue.hour % 12 == 0 ? 12 : localValue.hour % 12;
    final String minute = localValue.minute.toString().padLeft(2, '0');
    final String suffix = localValue.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  if (difference.inDays == 1) return 'Yesterday';

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

  return '${months[localValue.month - 1]} ${localValue.day}';
}

List<AgentInquiry> _cachedAgentInquiries() {
  final List<ConversationSummary> cachedSummaries =
      MessagingService.getCachedConversationSummaries();
  if (cachedSummaries.isEmpty) return const [];
  return AgentInquiry.groupedFromConversationSummaries(cachedSummaries);
}

Route<T> _instantRoute<T>(Widget child) {
  return PageRouteBuilder<T>(
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (context, animation, secondaryAnimation) => child,
  );
}

class AgentInquiry {
  final String id;
  final String buyerId;
  final String buyerName;
  final String message;
  final String timeLabel;
  final bool isUnread;
  final String conversationTitle;
  final String primaryConversationId;
  final List<String> conversationIds;
  final DateTime? lastMessageAt;

  const AgentInquiry({
    required this.id,
    required this.buyerId,
    required this.buyerName,
    required this.message,
    required this.timeLabel,
    required this.isUnread,
    required this.conversationTitle,
    required this.primaryConversationId,
    required this.conversationIds,
    required this.lastMessageAt,
  });

  AgentInquiry copyWith({
    String? id,
    String? buyerId,
    String? buyerName,
    String? message,
    String? timeLabel,
    bool? isUnread,
    String? conversationTitle,
    String? primaryConversationId,
    List<String>? conversationIds,
    DateTime? lastMessageAt,
  }) {
    return AgentInquiry(
      id: id ?? this.id,
      buyerId: buyerId ?? this.buyerId,
      buyerName: buyerName ?? this.buyerName,
      message: message ?? this.message,
      timeLabel: timeLabel ?? this.timeLabel,
      isUnread: isUnread ?? this.isUnread,
      conversationTitle: conversationTitle ?? this.conversationTitle,
      primaryConversationId:
          primaryConversationId ?? this.primaryConversationId,
      conversationIds: conversationIds ?? this.conversationIds,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    );
  }

  factory AgentInquiry.fromConversationSummary(ConversationSummary summary) {
    return AgentInquiry(
      id: summary.otherParticipantId,
      buyerId: summary.otherParticipantId,
      buyerName: summary.otherParticipantName,
      message: summary.lastMessagePreview.isNotEmpty
          ? summary.lastMessagePreview
          : 'No messages yet.',
      timeLabel: _formatInboxTime(summary.lastMessageAt),
      isUnread: summary.isUnread,
      conversationTitle: summary.title,
      primaryConversationId: summary.id,
      conversationIds: [summary.id],
      lastMessageAt: summary.lastMessageAt,
    );
  }

  static List<AgentInquiry> groupedFromConversationSummaries(
    List<ConversationSummary> summaries,
  ) {
    final Map<String, List<ConversationSummary>> grouped = {};

    for (final ConversationSummary summary in summaries) {
      grouped.putIfAbsent(summary.otherParticipantId, () => []).add(summary);
    }

    final List<AgentInquiry> inquiries = grouped.values.map((items) {
      items.sort((a, b) {
        final DateTime? first = a.lastMessageAt;
        final DateTime? second = b.lastMessageAt;
        if (first == null && second == null) return 0;
        if (first == null) return 1;
        if (second == null) return -1;
        return second.compareTo(first);
      });

      final ConversationSummary latest = items.first;
      final List<String> titles = items
          .map((summary) => summary.title.trim())
          .where((title) => title.isNotEmpty)
          .toSet()
          .toList();

      return AgentInquiry(
        id: latest.otherParticipantId,
        buyerId: latest.otherParticipantId,
        buyerName: latest.otherParticipantName,
        message: latest.lastMessagePreview.isNotEmpty
            ? latest.lastMessagePreview
            : 'No messages yet.',
        timeLabel: _formatInboxTime(latest.lastMessageAt),
        isUnread: items.any((summary) => summary.isUnread),
        conversationTitle: titles.length <= 1
            ? latest.title
            : 'Multiple inquiries',
        primaryConversationId: latest.id,
        conversationIds: items.map((summary) => summary.id).toList(),
        lastMessageAt: latest.lastMessageAt,
      );
    }).toList();

    inquiries.sort((a, b) {
      final DateTime? first = a.lastMessageAt;
      final DateTime? second = b.lastMessageAt;
      if (first == null && second == null) return 0;
      if (first == null) return 1;
      if (second == null) return -1;
      return second.compareTo(first);
    });

    return inquiries;
  }
}

class AdminHomePage extends StatefulWidget {
  final Future<void> Function(BuildContext context) onLogout;

  const AdminHomePage({super.key, required this.onLogout});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  List<AgentInquiry> _inquiries = const [];
  bool _isInboxLoading = true;
  RealtimeChannel? _inboxChannel;

  int get _unreadInquiryCount =>
      _inquiries.where((inquiry) => inquiry.isUnread).length;

  List<Property> get _properties => appPropertiesNotifier.value;

  @override
  void initState() {
    super.initState();
    appPropertiesNotifier.addListener(_refreshDashboard);
    final List<AgentInquiry> cachedInquiries = _cachedAgentInquiries();
    if (cachedInquiries.isNotEmpty) {
      _inquiries = cachedInquiries;
      _isInboxLoading = false;
    }
    unawaited(_loadInquiries(showLoader: cachedInquiries.isEmpty));
    _subscribeToInboxUpdates();
  }

  @override
  void dispose() {
    appPropertiesNotifier.removeListener(_refreshDashboard);
    if (_inboxChannel != null) {
      unawaited(Supabase.instance.client.removeChannel(_inboxChannel!));
    }
    super.dispose();
  }

  void _refreshDashboard() {
    if (!mounted) return;
    setState(() {});
  }

  void _subscribeToInboxUpdates() {
    final SupabaseClient client = Supabase.instance.client;
    _inboxChannel = client
        .channel('agent-inbox-dashboard')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (_) {
            if (!mounted) return;
            unawaited(_loadInquiries(showLoader: false));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (_) {
            if (!mounted) return;
            unawaited(_loadInquiries(showLoader: false));
          },
        )
        .subscribe();
  }

  Future<void> _loadInquiries({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        _isInboxLoading = true;
      });
    }

    try {
      final List<ConversationSummary> summaries =
          await MessagingService.fetchMyConversationSummaries();
      if (!mounted) return;
      setState(() {
        _inquiries = AgentInquiry.groupedFromConversationSummaries(summaries);
        _isInboxLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _inquiries = const [];
        _isInboxLoading = false;
      });
    }
  }

  Future<void> _openAddPropertyPage() async {
    final Property? newProperty = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PropertyFormPage()),
    );

    if (newProperty == null || !mounted) return;

    try {
      final Property createdProperty = await createProperty(newProperty);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${createdProperty.title} added successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add property: $e')));
    }
  }

  Future<void> _openManagePropertiesPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManagePropertiesPage(
          properties: _properties,
          onUpdateProperty: _updatePropertyRecord,
          onDeleteProperty: _deletePropertyRecord,
        ),
      ),
    );

    if (!mounted) return;
  }

  Future<void> _openInboxPage() async {
    await Navigator.push(
      context,
      _instantRoute(
        AgentInboxPage(
          inquiries: _inquiries,
          onMarkAsRead: _markInquiryAsRead,
        ),
      ),
    );

    if (!mounted) return;
    await _loadInquiries(showLoader: false);
  }

  Future<void> _updatePropertyRecord(Property updatedProperty) async {
    await updateProperty(updatedProperty);
  }

  Future<void> _deletePropertyRecord(String propertyId) async {
    await deleteProperty(propertyId);
  }

  void _markInquiryAsRead(String inquiryId) {
    final int index = _inquiries.indexWhere(
      (inquiry) => inquiry.id == inquiryId,
    );

    if (index == -1 || !_inquiries[index].isUnread) return;

    setState(() {
      _inquiries[index] = _inquiries[index].copyWith(isUnread: false);
    });
  }

  Widget _buildDashboardActionCard({
    required BuildContext context,
    required IconData icon,
    required Color accentColor,
    required String title,
    required String subtitle,
    required String badgeText,
    required VoidCallback onTap,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool isLightTheme = theme.brightness == Brightness.light;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accentColor.withValues(
                    alpha: isLightTheme ? 0.12 : 0.2,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: accentColor, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badgeText,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTile({
    required BuildContext context,
    required String value,
    required String label,
    required IconData icon,
    required Color accentColor,
  }) {
    final ThemeData theme = Theme.of(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            const SizedBox(height: 18),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await widget.onLogout(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Workspace',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Handle listings and buyer conversations from one place.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _buildDashboardActionCard(
            context: context,
            icon: Icons.add_home_work_rounded,
            accentColor: theme.colorScheme.primary,
            title: 'Add New Property',
            subtitle: 'Create and publish a new listing.',
            badgeText: 'Quick action',
            onTap: _openAddPropertyPage,
          ),
          const SizedBox(height: 12),
          _buildDashboardActionCard(
            context: context,
            icon: Icons.edit_note_rounded,
            accentColor: Colors.orange,
            title: 'Manage Properties',
            subtitle: 'Review and update your active listings.',
            badgeText: '${_properties.length} listing(s)',
            onTap: _openManagePropertiesPage,
          ),
          const SizedBox(height: 12),
          _buildDashboardActionCard(
            context: context,
            icon: Icons.mail_rounded,
            accentColor: Colors.blue,
            title: 'Agent Inbox',
            subtitle: 'Open buyer messages and respond quickly.',
            badgeText: _isInboxLoading
                ? 'Loading inquiries...'
                : '$_unreadInquiryCount unread inquiry(s)',
            onTap: _openInboxPage,
          ),
          const SizedBox(height: 22),
          Text(
            'Quick Overview',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'A quick snapshot of your current dashboard activity.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildOverviewTile(
                context: context,
                value: '${_properties.length}',
                label: 'Listings',
                icon: Icons.home_work_rounded,
                accentColor: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              _buildOverviewTile(
                context: context,
                value: '$_unreadInquiryCount',
                label: 'Unread',
                icon: Icons.mark_email_unread_rounded,
                accentColor: Colors.blue,
              ),
              const SizedBox(width: 12),
              _buildOverviewTile(
                context: context,
                value: '${_inquiries.length}',
                label: 'Threads',
                icon: Icons.forum_rounded,
                accentColor: Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PropertyFormPage extends StatefulWidget {
  final Property? initialProperty;

  const PropertyFormPage({super.key, this.initialProperty});

  @override
  State<PropertyFormPage> createState() => _PropertyFormPageState();
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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingImage = false;
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

  String? get _previewImageSource {
    final String thumbnailUrl = _thumbnailUrlController.text.trim();
    if (thumbnailUrl.isNotEmpty) return thumbnailUrl;

    final String imageUrl = _imageUrlController.text.trim();
    return imageUrl.isEmpty ? null : imageUrl;
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

  Widget _buildCompactFieldRow({required Widget left, required Widget right}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(children: [left, const SizedBox(height: 12), right]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 12),
            Expanded(child: right),
          ],
        );
      },
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

  Widget _buildSelectionField({
    required BuildContext context,
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? helperText,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      validator: (selectedValue) {
        if (selectedValue == null || selectedValue.trim().isEmpty) {
          return 'Please select a title status.';
        }
        return null;
      },
    );
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
                      children: provincePlaces.map((place) {
                        return ListTile(
                          dense: true,
                          title: Text(place.placeName),
                          subtitle: Text(place.location),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.of(sheetContext).pop(place),
                        );
                      }).toList(growable: false),
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

  _OptimizedPropertyImages _optimizePropertyImages(Uint8List bytes) {
    final img.Image? decodedImage = img.decodeImage(bytes);
    if (decodedImage == null) {
      throw const FormatException('Unsupported image format.');
    }

    final img.Image orientedImage = img.bakeOrientation(decodedImage);
    final int thumbnailWidth = orientedImage.width > 560
        ? 560
        : orientedImage.width;
    final img.Image thumbnailImage = img.copyResize(
      orientedImage,
      width: thumbnailWidth,
      interpolation: img.Interpolation.average,
    );

    return _OptimizedPropertyImages(
      detailBytes: Uint8List.fromList(img.encodeJpg(orientedImage, quality: 72)),
      thumbnailBytes: Uint8List.fromList(
        img.encodeJpg(thumbnailImage, quality: 64),
      ),
    );
  }

  Future<void> _pickAndUploadPropertyImage() async {
    if (_isUploadingImage) return;

    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again before uploading.')),
      );
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
      final _OptimizedPropertyImages optimizedImages =
          _optimizePropertyImages(bytes);
      final int uploadTimestamp = DateTime.now().millisecondsSinceEpoch;
      final String detailFilePath = '${user.id}/$uploadTimestamp-detail.jpg';
      final String thumbnailFilePath = '${user.id}/$uploadTimestamp-thumb.jpg';

      await Supabase.instance.client.storage
          .from('property-images')
          .uploadBinary(
            detailFilePath,
            optimizedImages.detailBytes,
            fileOptions: FileOptions(
              cacheControl: '604800',
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      await Supabase.instance.client.storage
          .from('property-images')
          .uploadBinary(
            thumbnailFilePath,
            optimizedImages.thumbnailBytes,
            fileOptions: FileOptions(
              cacheControl: '604800',
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final String publicUrl = Supabase.instance.client.storage
          .from('property-images')
          .getPublicUrl(detailFilePath);
      final String thumbnailPublicUrl = Supabase.instance.client.storage
          .from('property-images')
          .getPublicUrl(thumbnailFilePath);

      setState(() {
        _imageUrlController.text = publicUrl;
        _thumbnailUrlController.text = thumbnailPublicUrl;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Property image uploaded and optimized successfully.'),
        ),
      );
    } on StorageException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: ${error.message}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected upload error: $error')),
      );
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
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final int parsedPriceValue = _extractNumber(_priceController.text);
    final int parsedSizeValue = _extractNumber(_sizeController.text);

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
    );

    Navigator.pop(context, property);
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
            _buildSectionCard(
              context: context,
              title: 'Listing Identity',
              subtitle:
                  'Add the core listing details the agent should track and publish.',
              children: [
                _buildCompactFieldRow(
                  left: _buildFormField(
                    controller: _referenceCodeController,
                    label: 'Listing code',
                    hintText: 'LF-000120008',
                    icon: Icons.pin_outlined,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a listing code.';
                      }
                      return null;
                    },
                  ),
                  right: _buildFormField(
                    controller: _titleController,
                    label: 'Clean title',
                    hintText: 'Prime Residential Lot',
                    icon: Icons.title_rounded,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a clean title.';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _buildFormField(
                  controller: _locationController,
                  label: 'Location / area',
                  hintText: 'Example: Dumaguete City or 9.3077, 123.3054',
                  icon: Icons.location_on_outlined,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a location or area.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _pickNegrosPlaceForLocation,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Pick from Negros places'),
                  ),
                ),
                const SizedBox(height: 12),
                _buildCompactFieldRow(
                  left: _buildFormField(
                    controller: _priceController,
                    label: 'Price',
                    hintText: '₱1,200,000',
                    icon: Icons.payments_outlined,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a price.';
                      }
                      return null;
                    },
                  ),
                  right: _buildFormField(
                    controller: _sizeController,
                    label: 'Lot size',
                    hintText: '500 sqm',
                    icon: Icons.straighten_rounded,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a lot size.';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _buildCompactFieldRow(
                  left: _buildFormField(
                    controller: _statusController,
                    label: 'Card tag',
                    hintText: 'Featured',
                    icon: Icons.sell_outlined,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a card tag.';
                      }
                      return null;
                    },
                  ),
                  right: _buildSelectionField(
                    context: context,
                    label: 'Title status',
                    icon: Icons.verified_outlined,
                    value: _selectedTitleStatus,
                    items: _titleStatusOptions,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedTitleStatus = value;
                      });
                    },
                  ),
                ),
              ],
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
                if (_imageUrlController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _imageUrlController.clear();
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
    final ImageProvider<Object>? imageProvider =
        _managePropertyImageProvider(property);

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

class AgentInboxPage extends StatefulWidget {
  final List<AgentInquiry> inquiries;
  final ValueChanged<String> onMarkAsRead;

  const AgentInboxPage({
    super.key,
    required this.inquiries,
    required this.onMarkAsRead,
  });

  @override
  State<AgentInboxPage> createState() => _AgentInboxPageState();
}

class _AgentInboxPageState extends State<AgentInboxPage> {
  late List<AgentInquiry> _inquiries;
  RealtimeChannel? _inboxChannel;

  @override
  void initState() {
    super.initState();
    _inquiries = widget.inquiries.isNotEmpty
        ? List<AgentInquiry>.from(widget.inquiries)
        : _cachedAgentInquiries();
    _subscribeToInboxUpdates();
    unawaited(_refreshInquiries());
  }

  @override
  void dispose() {
    if (_inboxChannel != null) {
      unawaited(Supabase.instance.client.removeChannel(_inboxChannel!));
    }
    super.dispose();
  }

  void _subscribeToInboxUpdates() {
    final SupabaseClient client = Supabase.instance.client;
    _inboxChannel = client
        .channel('agent-inbox-page')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (_) {
            if (!mounted) return;
            unawaited(_refreshInquiries());
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (_) {
            if (!mounted) return;
            unawaited(_refreshInquiries());
          },
        )
        .subscribe();
  }

  Future<void> _refreshInquiries() async {
    try {
      final List<ConversationSummary> summaries =
          await MessagingService.fetchMyConversationSummaries();
      if (!mounted) return;
      setState(() {
        _inquiries = AgentInquiry.groupedFromConversationSummaries(summaries);
      });
    } catch (_) {}
  }

  Future<void> _openInquiry(AgentInquiry inquiry) async {
    if (inquiry.isUnread) {
      final int index = _inquiries.indexWhere((item) => item.id == inquiry.id);
      if (index != -1) {
        setState(() {
          _inquiries[index] = _inquiries[index].copyWith(isUnread: false);
        });
        widget.onMarkAsRead(inquiry.id);
      }

      unawaited(
        MessagingService.markConversationsAsRead(inquiry.conversationIds),
      );
    }

    await Navigator.push(
      context,
      _instantRoute(InquiryDetailsPage(inquiry: inquiry)),
    );

    await _refreshInquiries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agent Inbox')),
      body: RefreshIndicator(
        onRefresh: _refreshInquiries,
        child: _inquiries.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No buyer inquiries yet.')),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _inquiries.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final AgentInquiry inquiry = _inquiries[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text(inquiry.buyerName[0])),
                      title: Text(
                        inquiry.buyerName,
                        style: TextStyle(
                          fontWeight: inquiry.isUnread
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        inquiry.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(inquiry.timeLabel),
                          if (inquiry.isUnread) ...[
                            const SizedBox(height: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      onTap: () => _openInquiry(inquiry),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class InquiryDetailsPage extends StatefulWidget {
  final AgentInquiry inquiry;

  const InquiryDetailsPage({super.key, required this.inquiry});

  @override
  State<InquiryDetailsPage> createState() => _InquiryDetailsPageState();
}

class _InquiryDetailsPageState extends State<InquiryDetailsPage> {
  late final TextEditingController _replyController;
  late final ScrollController _messagesScrollController;
  bool _isSending = false;
  bool _isLoadingMessages = true;
  bool _isLoadingMoreMessages = false;
  bool _hasMoreMessages = true;
  List<ConversationMessage> _messages = const [];
  RealtimeChannel? _messagesChannel;

  String get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _replyController = TextEditingController();
    _messagesScrollController = ScrollController();
    _messages = MessagingService.getCachedConversationMessagesForConversations(
      widget.inquiry.conversationIds,
      limit: MessagingService.initialMessagePageSize,
    );
    _isLoadingMessages = _messages.isEmpty;
    _hasMoreMessages =
        _messages.length >= MessagingService.initialMessagePageSize;
    _messagesScrollController.addListener(_handleMessagesScroll);
    _subscribeToMessageUpdates();
    if (_messages.isNotEmpty) {
      _jumpToBottom();
    }
    unawaited(
      _loadMessages(scrollToBottom: true, showLoader: _messages.isEmpty),
    );
  }

  @override
  void dispose() {
    _replyController.dispose();
    _messagesScrollController.dispose();
    if (_messagesChannel != null) {
      unawaited(Supabase.instance.client.removeChannel(_messagesChannel!));
    }
    super.dispose();
  }

  void _subscribeToMessageUpdates() {
    RealtimeChannel channel = Supabase.instance.client.channel(
      'agent-thread-${widget.inquiry.buyerId}',
    );

    for (final String conversationId in widget.inquiry.conversationIds) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'conversation_id',
          value: conversationId,
        ),
        callback: (_) {
          if (!mounted) return;
          unawaited(_loadMessages(scrollToBottom: true, showLoader: false));
        },
      );
    }

    _messagesChannel = channel.subscribe();
  }

  void _handleMessagesScroll() {
    if (!_messagesScrollController.hasClients ||
        _isLoadingMoreMessages ||
        !_hasMoreMessages ||
        _messages.isEmpty) {
      return;
    }

    if (_messagesScrollController.position.pixels <= 120) {
      unawaited(_loadOlderMessages());
    }
  }

  List<ConversationMessage> _mergeMessages(
    Iterable<ConversationMessage> existing,
    Iterable<ConversationMessage> incoming,
  ) {
    final Map<String, ConversationMessage> byId =
        <String, ConversationMessage>{};
    for (final ConversationMessage message in existing) {
      byId[message.id] = message;
    }
    for (final ConversationMessage message in incoming) {
      byId[message.id] = message;
    }

    final List<ConversationMessage> merged = byId.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return merged;
  }

  Future<void> _loadMessages({
    bool scrollToBottom = false,
    bool showLoader = true,
  }) async {
    if (showLoader && mounted) {
      setState(() {
        _isLoadingMessages = true;
      });
    }

    try {
      final List<ConversationMessage> messages =
          await MessagingService.fetchConversationMessagesForConversations(
            widget.inquiry.conversationIds,
            limit: MessagingService.initialMessagePageSize,
          );
      final int previousCount = _messages.length;
      final List<ConversationMessage> mergedMessages = _mergeMessages(
        _messages,
        messages,
      );
      if (!mounted) return;
      setState(() {
        _messages = mergedMessages;
        _isLoadingMessages = false;
        _hasMoreMessages =
            messages.length >= MessagingService.initialMessagePageSize;
      });
      if (scrollToBottom || mergedMessages.length > previousCount) {
        if (previousCount == 0) {
          _jumpToBottom();
        } else {
          _scrollToBottom();
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMessages = false;
      });
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoadingMoreMessages || !_hasMoreMessages || _messages.isEmpty) {
      return;
    }

    final DateTime before = _messages.first.createdAt;
    final double previousOffset = _messagesScrollController.hasClients
        ? _messagesScrollController.offset
        : 0;
    final double previousMaxExtent = _messagesScrollController.hasClients
        ? _messagesScrollController.position.maxScrollExtent
        : 0;

    setState(() {
      _isLoadingMoreMessages = true;
    });

    try {
      final List<ConversationMessage> olderMessages =
          await MessagingService.fetchConversationMessagesForConversations(
            widget.inquiry.conversationIds,
            limit: MessagingService.initialMessagePageSize,
            before: before,
          );
      final List<ConversationMessage> mergedMessages = _mergeMessages(
        _messages,
        olderMessages,
      );

      if (!mounted) return;
      setState(() {
        _messages = mergedMessages;
        _isLoadingMoreMessages = false;
        _hasMoreMessages =
            olderMessages.length >= MessagingService.initialMessagePageSize;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_messagesScrollController.hasClients) return;
        final double delta =
            _messagesScrollController.position.maxScrollExtent -
            previousMaxExtent;
        _messagesScrollController.jumpTo(previousOffset + delta);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMoreMessages = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messagesScrollController.hasClients) return;
      _messagesScrollController.animateTo(
        _messagesScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messagesScrollController.hasClients) return;
      _messagesScrollController.jumpTo(
        _messagesScrollController.position.maxScrollExtent,
      );
    });
  }

  Future<void> _sendReply() async {
    final String replyText = _replyController.text.trim();
    if (replyText.isEmpty || _isSending) return;

    final ConversationMessage optimisticMessage = ConversationMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      conversationId: widget.inquiry.primaryConversationId,
      senderId: _currentUserId,
      body: replyText,
      createdAt: DateTime.now(),
      readAt: null,
    );

    setState(() {
      _isSending = true;
      _messages = [..._messages, optimisticMessage];
    });
    _replyController.clear();
    _scrollToBottom();

    try {
      final ConversationMessage sentMessage =
          await MessagingService.sendMessage(
            conversationId: widget.inquiry.primaryConversationId,
            body: replyText,
          );

      if (!mounted) return;
      final List<ConversationMessage> currentMessages = _messages
          .where((message) => message.id != optimisticMessage.id)
          .toList();
      setState(() {
        _messages = _mergeMessages(currentMessages, [sentMessage]);
      });
    } catch (e) {
      if (!mounted) return;
      _replyController.text = replyText;
      setState(() {
        _messages = _messages
            .where((message) => message.id != optimisticMessage.id)
            .toList();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send reply: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _showMessageActions(ConversationMessage message) async {
    final String? action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit message'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete message',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == 'edit') {
      await _editMessage(message);
    } else if (action == 'delete') {
      await _deleteMessage(message);
    }
  }

  Future<void> _editMessage(ConversationMessage message) async {
    final TextEditingController controller = TextEditingController(
      text: message.body,
    );

    final String? updatedText = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit message'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Update your message'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!mounted || updatedText == null || updatedText.isEmpty) return;
    if (updatedText == message.body.trim()) return;

    try {
      await MessagingService.updateMessage(
        messageId: message.id,
        body: updatedText,
      );
      await _loadMessages(scrollToBottom: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to edit message: $e')));
    }
  }

  Future<void> _deleteMessage(ConversationMessage message) async {
    final bool shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Delete message'),
              content: const Text(
                'This message will be removed from the chat.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!mounted || !shouldDelete) return;

    try {
      await MessagingService.deleteMessage(message.id);
      await _loadMessages(scrollToBottom: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete message: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.inquiry.buyerName)),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Messages',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.inquiry.conversationTitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _isLoadingMessages
                        ? const _InquiryThreadLoadingPlaceholder()
                        : _messages.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              Center(child: Text('No messages yet.')),
                            ],
                          )
                        : ListView.separated(
                            controller: _messagesScrollController,
                            itemCount:
                                _messages.length +
                                (_isLoadingMoreMessages ? 1 : 0),
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              if (_isLoadingMoreMessages && index == 0) {
                                return const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              }

                              final int messageIndex = _isLoadingMoreMessages
                                  ? index - 1
                                  : index;
                              final ConversationMessage message =
                                  _messages[messageIndex];
                              final ThemeData theme = Theme.of(context);
                              final bool isAgentMessage = message.isFrom(
                                _currentUserId,
                              );
                              final Color bubbleColor = isAgentMessage
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.secondaryContainer;
                              final Color textColor = isAgentMessage
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSecondaryContainer;
                              final Color metaColor = isAgentMessage
                                  ? textColor.withValues(alpha: 0.75)
                                  : textColor.withValues(alpha: 0.8);

                              return Align(
                                alignment: isAgentMessage
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: GestureDetector(
                                  onLongPress:
                                      isAgentMessage && !message.isPending
                                      ? () => _showMessageActions(message)
                                      : null,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 320,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: bubbleColor,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            message.body,
                                            style: TextStyle(
                                              color: textColor,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            isAgentMessage
                                                ? (message.isPending
                                                      ? 'Sending...'
                                                      : 'Sent')
                                                : _formatInboxTime(
                                                    message.createdAt,
                                                  ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: metaColor,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Type your reply...',
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendReply(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _isSending
                          ? SizedBox(
                              key: const ValueKey('sending'),
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            )
                          : IconButton(
                              key: const ValueKey('send'),
                              onPressed: _sendReply,
                              icon: Icon(
                                Icons.send_rounded,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InquiryThreadLoadingPlaceholder extends StatelessWidget {
  const _InquiryThreadLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    final Color baseColor = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
    final Color highlightColor = Color.alphaBlend(
      Colors.white.withValues(alpha: 0.35),
      baseColor,
    );

    return ListView(
      children: List<Widget>.generate(6, (index) {
        final bool isAgentBubble = index.isOdd;
        return Align(
          alignment: isAgentBubble
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              width: isAgentBubble ? 260 : 200,
              height: 72,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _OptimizedPropertyImages {
  const _OptimizedPropertyImages({
    required this.detailBytes,
    required this.thumbnailBytes,
  });

  final Uint8List detailBytes;
  final Uint8List thumbnailBytes;
}
