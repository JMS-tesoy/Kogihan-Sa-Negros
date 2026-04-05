import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'agent_dashboard_page.dart';
import 'messaging_service.dart';
import 'shared_properties.dart';

final ValueNotifier<ThemeMode> appThemeNotifier = ValueNotifier(
  ThemeMode.light,
);
final ValueNotifier<double> appFontScaleNotifier = ValueNotifier(1.0);
final ValueNotifier<String?> appPinCodeNotifier = ValueNotifier(null);

String _messageInitial(String value) {
  final String trimmed = value.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed[0].toUpperCase();
}

String _formatMessageTime(DateTime? value) {
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

Widget _buildPropertyImage({
  required Property property,
  required double height,
  required Widget fallbackChild,
  BorderRadius? borderRadius,
}) {
  final Widget fallback = Container(
    height: height,
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          property.imageColor,
          property.imageColor.withOpacity(0.78),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: fallbackChild,
  );

  final String? imageUrl = property.imageUrl;
  if (imageUrl == null || imageUrl.isEmpty) {
    return borderRadius == null
        ? fallback
        : ClipRRect(borderRadius: borderRadius, child: fallback);
  }

  final Widget image = imageUrl.startsWith('http')
      ? Image.network(
          imageUrl,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        )
      : Image.asset(
          imageUrl,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        );

  return borderRadius == null
      ? image
      : ClipRRect(borderRadius: borderRadius, child: image);
}

ThemeData _buildLightTheme() {
  const Color seedColor = Color(0xFF2563EB);
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.light,
  ).copyWith(
    primary: const Color(0xFF2563EB),
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFDBEAFE),
    onPrimaryContainer: const Color(0xFF123B7A),
    secondary: const Color(0xFF64748B),
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFE8EEF6),
    onSecondaryContainer: const Color(0xFF243449),
    surface: const Color(0xFFFFFFFF),
    onSurface: const Color(0xFF0F172A),
    surfaceContainerHighest: const Color(0xFFEEF2F6),
    onSurfaceVariant: const Color(0xFF475569),
    outline: const Color(0xFFD7DFE8),
    outlineVariant: const Color(0xFFE6ECF2),
    shadow: const Color(0xFF0F172A),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    cardColor: scheme.surface,
    dividerColor: scheme.outlineVariant,
    canvasColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      surfaceTintColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        surfaceTintColor: Colors.transparent,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
      ),
    ),
    iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
    textTheme: ThemeData.light().textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      // TODO: Paste your actual Supabase URL and Anon Key here
      url: 'https://vludvvjkrrqzjahxjdjl.supabase.co',
      anonKey: 'sb_publishable_xrlYmyU6k2ItwhoSycq_iQ_4RxiPGdJ',
    );
    await loadProperties();
    developer.log('✅ Supabase connected successfully!', name: 'Supabase');
  } catch (e, stackTrace) {
    developer.log(
      '❌ Supabase connection failed',
      name: 'Supabase',
      error: e,
      stackTrace: stackTrace,
    );
  }

  runApp(const RealEstateApp());
}

class RealEstateApp extends StatelessWidget {
  const RealEstateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeNotifier,
      builder: (context, currentMode, child) {
        return ValueListenableBuilder<double>(
          valueListenable: appFontScaleNotifier,
          builder: (context, fontScale, child) {
            return MaterialApp(
              title: 'Land Finder',
              debugShowCheckedModeBanner: false,
              themeMode: currentMode,
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(fontScale)),
                  child: child!,
                );
              },
              theme: _buildLightTheme(),
              darkTheme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF2E7D32),
                  brightness: Brightness.dark,
                ),
                scaffoldBackgroundColor: const Color(0xFF121212),
              ),
              home: const LoginPage(),
            );
          },
        );
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String? _selectedLocation;
  String? _selectedLotSize;
  String? _selectedBudget;
  final Set<Property> _savedProperties = {};
  List<Property> _availableProperties = List<Property>.from(
    appPropertiesNotifier.value,
  );

  String? _profileImagePath;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    appPropertiesNotifier.addListener(_syncAvailableProperties);
    unawaited(loadProperties());
  }

  @override
  void dispose() {
    appPropertiesNotifier.removeListener(_syncAvailableProperties);
    _searchController.dispose();
    super.dispose();
  }

  void _syncAvailableProperties() {
    if (!mounted) return;
    setState(() {
      _availableProperties = List<Property>.from(appPropertiesNotifier.value);
    });
  }

  String _normalizeSearchText(String value) {
    return value.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  Future<void> _pickAvatarFromGallery() async {
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _profileImagePath = pickedFile.path;
      });
    }
  }

  Future<void> _pickAvatarFromCamera() async {
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _profileImagePath = pickedFile.path;
      });
    }
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAvatarFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAvatarFromCamera();
                },
              ),
              if (_profileImagePath != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Remove Avatar',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _profileImagePath = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  List<Property> get _filteredProperties {
    final String normalizedQuery = _normalizeSearchText(_searchQuery);
    final String numericQuery = _digitsOnly(_searchQuery);
    final bool hasSearchQuery =
        normalizedQuery.isNotEmpty || numericQuery.isNotEmpty;
    final bool hasLocationFilter = _selectedLocation != null;
    final bool hasLotSizeFilter = _selectedLotSize != null;
    final bool hasBudgetFilter = _selectedBudget != null;

    if (!hasSearchQuery) {
      return List<Property>.from(_availableProperties);
    }

    return _availableProperties.where((property) {
      if (hasLocationFilter && property.location != _selectedLocation) {
        return false;
      }

      if (hasLotSizeFilter) {
        final bool matchesLotSize = switch (_selectedLotSize) {
          'Below 500 sqm' => property.sizeValue < 500,
          '500 - 1000 sqm' =>
            property.sizeValue >= 500 && property.sizeValue <= 1000,
          'Above 1000 sqm' => property.sizeValue > 1000,
          _ => true,
        };

        if (!matchesLotSize) return false;
      }

      if (hasBudgetFilter) {
        final bool matchesBudget = switch (_selectedBudget) {
          'Below ₱1M' => property.priceValue < 1000000,
          '₱1M - ₱3M' =>
            property.priceValue >= 1000000 && property.priceValue <= 3000000,
          'Above ₱3M' => property.priceValue > 3000000,
          _ => true,
        };

        if (!matchesBudget) return false;
      }

      if (!hasSearchQuery) return true;

      final String normalizedTitle = _normalizeSearchText(property.title);
      final String normalizedLocation = _normalizeSearchText(property.location);
      final String normalizedPrice = _normalizeSearchText(property.price);

      if (normalizedTitle.contains(normalizedQuery) ||
          normalizedLocation.contains(normalizedQuery) ||
          normalizedPrice.contains(normalizedQuery)) {
        return true;
      }

      if (numericQuery.isEmpty) return false;

      final String numericPrice = _digitsOnly(property.price);
      return numericPrice.contains(numericQuery);
    }).toList(growable: false);
  }

  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _selectedLocation = null;
      _selectedLotSize = null;
      _selectedBudget = null;
    });
  }

  void _toggleSavedProperty(Property property) {
    setState(() {
      if (_savedProperties.contains(property)) {
        _savedProperties.remove(property);
      } else {
        _savedProperties.add(property);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomeTab(
        properties: _filteredProperties,
        savedProperties: _savedProperties,
        onToggleSave: _toggleSavedProperty,
        searchController: _searchController,
        onSearchChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        selectedLocation: _selectedLocation,
        selectedLotSize: _selectedLotSize,
        selectedBudget: _selectedBudget,
        onLocationChanged: (value) {
          setState(() {
            _selectedLocation = value;
          });
        },
        onLotSizeChanged: (value) {
          setState(() {
            _selectedLotSize = value;
          });
        },
        onBudgetChanged: (value) {
          setState(() {
            _selectedBudget = value;
          });
        },
        onResetFilters: _resetFilters,
      ),
      const MapTab(),
      SavedTab(
        savedProperties: _savedProperties.toList(),
        onToggleSave: _toggleSavedProperty,
      ),
      const MessagesTab(),
      ProfileTab(
        profileImagePath: _profileImagePath,
        onAvatarTap: _showAvatarOptions,
      ),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.mail_outline),
            selectedIcon: Icon(Icons.mail),
            label: 'Inbox',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  final List<Property> properties;
  final Set<Property> savedProperties;
  final ValueChanged<Property> onToggleSave;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final String? selectedLocation;
  final String? selectedLotSize;
  final String? selectedBudget;
  final ValueChanged<String?> onLocationChanged;
  final ValueChanged<String?> onLotSizeChanged;
  final ValueChanged<String?> onBudgetChanged;
  final VoidCallback onResetFilters;

  const HomeTab({
    super.key,
    required this.properties,
    required this.savedProperties,
    required this.onToggleSave,
    required this.searchController,
    required this.onSearchChanged,
    required this.selectedLocation,
    required this.selectedLotSize,
    required this.selectedBudget,
    required this.onLocationChanged,
    required this.onLotSizeChanged,
    required this.onBudgetChanged,
    required this.onResetFilters,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          const TopHeader(),
          const SizedBox(height: 12),
          SearchSection(
            searchController: searchController,
            onSearchChanged: onSearchChanged,
            selectedLocation: selectedLocation,
            selectedLotSize: selectedLotSize,
            selectedBudget: selectedBudget,
            onLocationChanged: onLocationChanged,
            onLotSizeChanged: onLotSizeChanged,
            onBudgetChanged: onBudgetChanged,
            onResetFilters: onResetFilters,
          ),
          const SizedBox(height: 16),
          SectionHeader(
            title: 'Recommended Properties',
            actionText: 'Reset',
            onPressed: onResetFilters,
          ),
          const SizedBox(height: 12),
          if (properties.isEmpty)
            const EmptyState()
          else
            ...properties.map(
              (property) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: PropertyCard(
                  property: property,
                  isSaved: savedProperties.contains(property),
                  onToggleSave: () => onToggleSave(property),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MapTab extends StatelessWidget {
  const MapTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: Text(
          'Map screen coming soon',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class SavedTab extends StatelessWidget {
  final List<Property> savedProperties;
  final ValueChanged<Property> onToggleSave;

  const SavedTab({
    super.key,
    required this.savedProperties,
    required this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saved Properties',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: savedProperties.isEmpty
                  ? const EmptyState(
                      icon: Icons.favorite_border_rounded,
                      message: 'No saved properties yet.',
                      subtitle:
                          'Tap the heart on any listing to keep it here for quick access.',
                    )
                  : ListView.separated(
                      itemCount: savedProperties.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final property = savedProperties[index];
                        return Card(
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 56,
                                height: 56,
                                child: _buildPropertyImage(
                                  property: property,
                                  height: 56,
                                  fallbackChild: const Center(
                                    child: Icon(
                                      Icons.landscape_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            title: Text(property.title),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 2),
                                Text(property.location),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    property.titleStatus,
                                    style: Theme.of(context).textTheme.labelSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            trailing: Text(property.price),
                            isThreeLine: true,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PropertyDetailsPage(
                                    property: property,
                                    isSaved: true,
                                    onToggleSave: () => onToggleSave(property),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key});

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _InboxCardPalette {
  final Color background;
  final Color border;
  final Color accent;
  final Color avatarBackground;
  final Color avatarForeground;

  const _InboxCardPalette({
    required this.background,
    required this.border,
    required this.accent,
    required this.avatarBackground,
    required this.avatarForeground,
  });
}

class _ChatColorPalette {
  final Color scaffoldBackground;
  final Color appBarBackground;
  final Color appBarForeground;
  final Color avatarBackground;
  final Color avatarForeground;
  final Color outgoingBubble;
  final Color outgoingText;
  final Color incomingBubble;
  final Color incomingText;
  final Color composerFill;
  final Color sendButtonBackground;
  final Color sendButtonForeground;

  const _ChatColorPalette({
    required this.scaffoldBackground,
    required this.appBarBackground,
    required this.appBarForeground,
    required this.avatarBackground,
    required this.avatarForeground,
    required this.outgoingBubble,
    required this.outgoingText,
    required this.incomingBubble,
    required this.incomingText,
    required this.composerFill,
    required this.sendButtonBackground,
    required this.sendButtonForeground,
  });
}

class _MessagesTabState extends State<MessagesTab> {
  bool _isLoading = true;
  String? _errorText;
  List<ConversationSummary> _conversations = const [];

  static const List<_InboxCardPalette> _lightInboxPalettes = [
    _InboxCardPalette(
      background: Color(0xFFF2F8F2),
      border: Color(0xFFB8D7BB),
      accent: Color(0xFF2E7D32),
      avatarBackground: Color(0xFFD9ECD8),
      avatarForeground: Color(0xFF1F5A24),
    ),
    _InboxCardPalette(
      background: Color(0xFFF3F7FD),
      border: Color(0xFFBDD0EA),
      accent: Color(0xFF2B6CB0),
      avatarBackground: Color(0xFFDCE7F8),
      avatarForeground: Color(0xFF1F4E85),
    ),
    _InboxCardPalette(
      background: Color(0xFFFBF6EF),
      border: Color(0xFFE5CFAE),
      accent: Color(0xFF9A6700),
      avatarBackground: Color(0xFFF2E4CA),
      avatarForeground: Color(0xFF704C00),
    ),
    _InboxCardPalette(
      background: Color(0xFFF8F3FA),
      border: Color(0xFFD7C3E3),
      accent: Color(0xFF7A4FA3),
      avatarBackground: Color(0xFFE9DAF1),
      avatarForeground: Color(0xFF5E3684),
    ),
  ];

  static const List<_InboxCardPalette> _darkInboxPalettes = [
    _InboxCardPalette(
      background: Color(0xFF1B2B1E),
      border: Color(0xFF355D3B),
      accent: Color(0xFF8FD694),
      avatarBackground: Color(0xFF29452E),
      avatarForeground: Color(0xFFD7F3D9),
    ),
    _InboxCardPalette(
      background: Color(0xFF182633),
      border: Color(0xFF31506B),
      accent: Color(0xFF8EC5FF),
      avatarBackground: Color(0xFF243A4E),
      avatarForeground: Color(0xFFD9ECFF),
    ),
    _InboxCardPalette(
      background: Color(0xFF2B2418),
      border: Color(0xFF5E4D2E),
      accent: Color(0xFFF0C674),
      avatarBackground: Color(0xFF433722),
      avatarForeground: Color(0xFFFFEDBF),
    ),
    _InboxCardPalette(
      background: Color(0xFF261D2D),
      border: Color(0xFF544064),
      accent: Color(0xFFD8B4F8),
      avatarBackground: Color(0xFF3B2C47),
      avatarForeground: Color(0xFFF2DFFF),
    ),
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_loadConversations());
  }

  _InboxCardPalette _paletteForConversation(
    BuildContext context,
    ConversationSummary conversation,
  ) {
    final bool isLightTheme = Theme.of(context).brightness == Brightness.light;
    final List<_InboxCardPalette> palettes = isLightTheme
        ? _lightInboxPalettes
        : _darkInboxPalettes;
    final int index = conversation.id.hashCode.abs() % palettes.length;
    return palettes[index];
  }

  Color? _propertyColorForConversation(ConversationSummary conversation) {
    final String? propertyId = conversation.propertyId;
    if (propertyId == null || propertyId.isEmpty) return null;

    for (final Property property in appPropertiesNotifier.value) {
      if (property.id == propertyId) return property.imageColor;
    }

    return null;
  }

  Future<void> _loadConversations({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        _isLoading = true;
        _errorText = null;
      });
    }

    try {
      final List<ConversationSummary> conversations =
          await MessagingService.fetchMyConversationSummaries();

      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _isLoading = false;
        _errorText = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorText = 'Failed to load inbox.';
      });
    }
  }

  Future<void> _openConversation(ConversationSummary conversation) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          conversationId: conversation.id,
          senderName: conversation.otherParticipantName,
          propertyColor: _propertyColorForConversation(conversation),
        ),
      ),
    );

    await _loadConversations(showLoader: false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Inbox',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BuyerChecklistPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.checklist),
                  label: const Text('Checklist'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadConversations(showLoader: false),
                child: Builder(
                  builder: (context) {
                    if (_isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (_errorText != null) {
                      return ListView(
                        children: [
                          const SizedBox(height: 120),
                          Center(
                            child: Text(
                              _errorText!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    if (_conversations.isEmpty) {
                      return ListView(
                        children: const [
                          SizedBox(height: 120),
                          Center(child: Text('No messages yet.')),
                        ],
                      );
                    }

                    return ListView.separated(
                      itemCount: _conversations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final ConversationSummary conversation =
                            _conversations[index];
                        return _buildMessageTile(context, conversation);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageTile(
    BuildContext context,
    ConversationSummary conversation,
  ) {
    final String previewText = conversation.lastMessagePreview.isNotEmpty
        ? conversation.lastMessagePreview
        : 'No messages yet.';
    final _InboxCardPalette palette = _paletteForConversation(
      context,
      conversation,
    );

    return Card(
      color: palette.background,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: palette.border,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: palette.avatarBackground,
          foregroundColor: palette.avatarForeground,
          child: Text(_messageInitial(conversation.title)),
        ),
        title: Text(
          conversation.title,
          style: TextStyle(
            fontWeight: conversation.isUnread
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            Text(
              conversation.otherParticipantName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              previewText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: conversation.isUnread
                    ? FontWeight.w600
                    : FontWeight.normal,
                color: conversation.isUnread
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatMessageTime(conversation.lastMessageAt),
              style: TextStyle(
                fontSize: 12,
                color: conversation.isUnread
                    ? palette.accent
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: conversation.isUnread
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            if (conversation.isUnread) ...[
              const SizedBox(height: 4),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: palette.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
        onTap: () => _openConversation(conversation),
      ),
    );
  }
}

class BuyerChecklistPage extends StatefulWidget {
  const BuyerChecklistPage({super.key});

  @override
  State<BuyerChecklistPage> createState() => _BuyerChecklistPageState();
}

class _BuyerChecklistPageState extends State<BuyerChecklistPage> {
  // Complete checklist categories
  final Map<String, Map<String, bool>> _checklist = {
    'About the land itself': {
      'What is the exact lot size?': false,
      'What is the shape of the property?': false,
      'Is the terrain flat, sloped, rocky, or flood-prone?': false,
      'What is the actual road access?': false,
      'Is it along a main road or interior road?': false,
      'Is the boundary clear and surveyed?': false,
      'Are the markers visible on site?': false,
      'What is the current use of the land?': false,
    },
    'About title and ownership': {
      'Is the title clean?': false,
      'Is it under one owner only?': false,
      'Is the title transferred already to the current owner?': false,
      'Are there any liens, mortgage, encumbrances, or adverse claims?': false,
      'Are real property taxes updated?': false,
      'Is there a tax declaration?': false,
      'Is the lot covered by TCT, CCT, or other documents?': false,
      'Are the documents ready for due diligence?': false,
    },
    'About legal and zoning': {
      'Is this land residential, commercial, agricultural, or industrial?':
          false,
      'Can I legally build a house, warehouse, resort, or business here?':
          false,
      'Is it inside a protected area, easement, or right-of-way?': false,
      'Are there zoning restrictions?': false,
      'Are there setback requirements?': false,
      'Is it allowed for foreigners through a corporation or other legal structure?':
          false,
    },
    'About utilities and development': {
      'Is there electricity already nearby?': false,
      'Is there water supply?': false,
      'Is internet signal strong?': false,
      'Is drainage available?': false,
      'Is the road concrete or rough road?': false,
      'Are there nearby developments already?': false,
      'How far is it from schools, hospitals, markets, airport, or city center?':
          false,
    },
    'About price and payment': {
      'What is the total price?': false,
      'What is the price per square meter?': false,
      'Is the price negotiable?': false,
      'What is included in the price?': false,
      'Who will pay for CGT, DST, transfer tax, registration, notary, and broker fees?':
          false,
      'Is installment allowed?': false,
      'What is the reservation fee?': false,
      'Are there hidden costs after purchase?': false,
    },
    'About safety and risk': {
      'Is the area flood-prone?': false,
      'Is there a history of landslide?': false,
      'Are there squatters, tenants, or occupants?': false,
      'Are there boundary disputes?': false,
      'Is the property under inheritance dispute?': false,
      'Is the area peaceful and safe?': false,
      'Are there future road projects that may affect the land?': false,
      'Is there any issue with access through another property?': false,
    },
    'About investment value': {
      'Why is the owner selling?': false,
      'How long has it been on the market?': false,
      'What makes this a good buy?': false,
      'What are the future developments in the area?': false,
      'What is the resale potential?': false,
      'Is the area appreciating?': false,
      'Is it good for flipping, farming, leasing, or long-term holding?': false,
    },
    'Questions buyers ask agents directly': {
      'Can you send the exact location pin?': false,
      'Can you send a copy of the title and tax declaration?': false,
      'Can I schedule a site visit?': false,
      'Can we verify the documents first before negotiating?': false,
      'Is your listing exclusive or direct to owner?': false,
      'How do you secure the transaction?': false,
      'What is your commission arrangement?': false,
      'Can you help with due diligence and transfer process?': false,
    },
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buyer Checklist'), centerTitle: true),
      body: ListView(
        children: _checklist.keys.map((category) {
          return ExpansionTile(
            title: Text(
              category,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            children: _checklist[category]!.keys.map((question) {
              return CheckboxListTile(
                title: Text(question),
                value: _checklist[category]![question],
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (bool? value) {
                  setState(() {
                    _checklist[category]![question] = value ?? false;
                  });
                },
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  final String? profileImagePath;
  final VoidCallback onAvatarTap;

  const ProfileTab({
    super.key,
    required this.profileImagePath,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: onAvatarTap,
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    backgroundImage: profileImagePath != null
                        ? FileImage(File(profileImagePath!))
                        : null,
                    child: profileImagePath == null
                        ? const Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: GestureDetector(
                    onTap: onAvatarTap,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.edit,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Boss JO',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Real Estate Buyer Profile',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 30),
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Account'),
                subtitle: const Text('Personal contact details'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AccountPage(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsPage(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Log Out'),
                textColor: Colors.red,
                onTap: () {
                  Supabase.instance.client.auth.signOut();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email'),
                subtitle: const Text('bossjo@example.com'),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.phone_outlined),
                title: const Text('Phone'),
                subtitle: const Text('+63 9XX XXX XXXX'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String senderName;
  final Color? propertyColor;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.senderName,
    this.propertyColor,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _messagesScrollController = ScrollController();
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorText;
  List<ConversationMessage> _messages = const [];
  RealtimeChannel? _messagesChannel;

  String get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  _ChatColorPalette _chatPalette(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color seedColor = widget.propertyColor ?? theme.colorScheme.primary;
    final ColorScheme chatScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: theme.brightness,
    );
    final bool isLightTheme = theme.brightness == Brightness.light;

    return _ChatColorPalette(
      scaffoldBackground: Color.alphaBlend(
        chatScheme.primary.withValues(alpha: isLightTheme ? 0.04 : 0.08),
        theme.scaffoldBackgroundColor,
      ),
      appBarBackground: Color.alphaBlend(
        chatScheme.primary.withValues(alpha: isLightTheme ? 0.12 : 0.18),
        theme.colorScheme.surface,
      ),
      appBarForeground: theme.colorScheme.onSurface,
      avatarBackground: chatScheme.primary,
      avatarForeground: chatScheme.onPrimary,
      outgoingBubble: chatScheme.primaryContainer,
      outgoingText: chatScheme.onPrimaryContainer,
      incomingBubble: chatScheme.secondaryContainer,
      incomingText: chatScheme.onSecondaryContainer,
      composerFill: Color.alphaBlend(
        chatScheme.primary.withValues(alpha: isLightTheme ? 0.08 : 0.14),
        theme.cardColor,
      ),
      sendButtonBackground: chatScheme.primary,
      sendButtonForeground: chatScheme.onPrimary,
    );
  }

  @override
  void initState() {
    super.initState();
    _subscribeToMessageUpdates();
    unawaited(_loadMessages(scrollToBottom: true));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messagesScrollController.dispose();
    if (_messagesChannel != null) {
      unawaited(Supabase.instance.client.removeChannel(_messagesChannel!));
    }
    super.dispose();
  }

  void _subscribeToMessageUpdates() {
    _messagesChannel = Supabase.instance.client
        .channel('buyer-chat-${widget.conversationId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: widget.conversationId,
          ),
          callback: (_) {
            if (!mounted) return;
            unawaited(_loadMessages(showLoader: false, scrollToBottom: true));
          },
        )
        .subscribe();
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

  Future<void> _loadMessages({
    bool showLoader = true,
    bool scrollToBottom = false,
  }) async {
    if (showLoader && mounted) {
      setState(() {
        _isLoading = true;
        _errorText = null;
      });
    }

    try {
      await MessagingService.markConversationAsRead(widget.conversationId);
      final List<ConversationMessage> messages =
          await MessagingService.fetchConversationMessages(
            widget.conversationId,
          );
      final int previousCount = _messages.length;

      if (!mounted) return;
      setState(() {
        _messages = messages;
        _isLoading = false;
        _errorText = null;
        _isSending = false;
      });
      if (scrollToBottom || messages.length > previousCount) {
        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isSending = false;
        _errorText = 'Failed to load messages.';
      });
    }
  }

  Future<void> _sendMessage() async {
    final String text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final ConversationMessage optimisticMessage = ConversationMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      conversationId: widget.conversationId,
      senderId: _currentUserId,
      body: text,
      createdAt: DateTime.now(),
      readAt: null,
    );

    setState(() {
      _isSending = true;
      _errorText = null;
      _messages = [..._messages, optimisticMessage];
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      await MessagingService.sendMessage(
        conversationId: widget.conversationId,
        body: text,
      );
      await _loadMessages(showLoader: false, scrollToBottom: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _errorText = 'Failed to send message.';
        _messages = _messages
            .where((message) => message.id != optimisticMessage.id)
            .toList();
        _messageController.text = text;
      });
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
      await _loadMessages(showLoader: false, scrollToBottom: true);
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
      await _loadMessages(showLoader: false, scrollToBottom: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete message: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final _ChatColorPalette palette = _chatPalette(context);

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: palette.appBarBackground,
        foregroundColor: palette.appBarForeground,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: palette.avatarBackground,
              foregroundColor: palette.avatarForeground,
              child: Text(
                widget.senderName[0],
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            Text(widget.senderName, style: const TextStyle(fontSize: 18)),
          ],
        ),
        titleSpacing: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Builder(
              builder: (context) {
                if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (_errorText != null && _messages.isEmpty) {
                  return Center(
                    child: Text(
                      _errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _messagesScrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final ConversationMessage msg = _messages[index];
                    final bool isMe = msg.isFrom(_currentUserId);
                    final Color bubbleColor = isMe
                        ? palette.outgoingBubble
                        : palette.incomingBubble;
                    final Color textColor = isMe
                        ? palette.outgoingText
                        : palette.incomingText;
                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: isMe && !msg.isPending
                            ? () => _showMessageActions(msg)
                            : null,
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey(msg.id),
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(
                                  isMe ? (1 - value) * 18 : -(1 - value) * 18,
                                  (1 - value) * 10,
                                ),
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: bubbleColor,
                              borderRadius: BorderRadius.circular(16).copyWith(
                                bottomRight: isMe
                                    ? const Radius.circular(0)
                                    : const Radius.circular(16),
                                bottomLeft: !isMe
                                    ? const Radius.circular(0)
                                    : const Radius.circular(16),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg.body,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 16,
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    msg.isPending ? 'Sending...' : 'Sent',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: textColor.withValues(alpha: 0.85),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_errorText != null && _messages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                _errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: palette.composerFill,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: palette.sendButtonBackground,
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
                                  palette.sendButtonForeground,
                                ),
                              ),
                            )
                          : IconButton(
                              key: const ValueKey('send'),
                              icon: Icon(
                                Icons.send_rounded,
                                color: palette.sendButtonForeground,
                              ),
                              onPressed: _sendMessage,
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

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  late bool _darkModeEnabled;
  bool _notifyNewProperties = true;
  bool _notifyPriceDrops = true;
  bool _notifyMessages = true;
  double _currentFontSizeScale = 1.0; // Default font size scale

  @override
  void initState() {
    super.initState();
    _darkModeEnabled = appThemeNotifier.value == ThemeMode.dark;
    _currentFontSizeScale = appFontScaleNotifier.value;
  }

  Widget _buildCompactSwitchTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool dense = false,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      value: value,
      dense: dense,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onChanged: onChanged,
      activeColor: Theme.of(context).colorScheme.primary,
      controlAffinity: ListTileControlAffinity.trailing,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: ListView(
        children: [
          Theme(
            data: Theme.of(context).copyWith(
              switchTheme: SwitchThemeData(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            child: Column(
              children: [
                Transform.scale(
                  scale: 0.88,
                  alignment: Alignment.centerRight,
                  child: _buildCompactSwitchTile(
                    title: 'Push Notifications',
                    subtitle: 'Receive alerts for new properties',
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                    },
                  ),
                ),
                // Font Sizing Feature
                ListTile(
                  title: const Text('Font Size'),
                  subtitle: Text(
                    'Adjust text size for better readability (${_currentFontSizeScale.toStringAsFixed(1)}x)',
                  ),
                  leading: const Icon(Icons.format_size),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Slider(
                    value: _currentFontSizeScale,
                    min: 0.8,
                    max: 1.5,
                    divisions:
                        7, // Allows for 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5
                    label: _currentFontSizeScale.toStringAsFixed(1),
                    onChanged: (double value) {
                      setState(() {
                        _currentFontSizeScale = value;
                        appFontScaleNotifier.value = value;
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 8.0,
                  ),
                  child: Text(
                    'This is an example text. Adjust the slider above to see the font size change.',
                    textScaleFactor: _currentFontSizeScale,
                  ),
                ),
                if (_notificationsEnabled)
                  Padding(
                    padding: const EdgeInsets.only(left: 32.0),
                    child: Column(
                      children: [
                        Transform.scale(
                          scale: 0.88,
                          alignment: Alignment.centerRight,
                          child: _buildCompactSwitchTile(
                            title: 'New Property Alerts',
                            value: _notifyNewProperties,
                            dense: true,
                            onChanged: (value) {
                              setState(() => _notifyNewProperties = value);
                            },
                          ),
                        ),
                        Transform.scale(
                          scale: 0.88,
                          alignment: Alignment.centerRight,
                          child: _buildCompactSwitchTile(
                            title: 'Price Drops on Saved',
                            value: _notifyPriceDrops,
                            dense: true,
                            onChanged: (value) {
                              setState(() => _notifyPriceDrops = value);
                            },
                          ),
                        ),
                        Transform.scale(
                          scale: 0.88,
                          alignment: Alignment.centerRight,
                          child: _buildCompactSwitchTile(
                            title: 'Agent Messages',
                            value: _notifyMessages,
                            dense: true,
                            onChanged: (value) {
                              setState(() => _notifyMessages = value);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                Transform.scale(
                  scale: 0.88,
                  alignment: Alignment.centerRight,
                  child: _buildCompactSwitchTile(
                    title: 'Dark Mode',
                    subtitle: 'Switch to a darker theme',
                    value: _darkModeEnabled,
                    onChanged: (value) {
                      setState(() {
                        _darkModeEnabled = value;
                        appThemeNotifier.value = value
                            ? ThemeMode.dark
                            : ThemeMode.light;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Reset Password'),
            subtitle: const Text('Change password for this account'),
            leading: const Icon(Icons.lock_reset),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChangePasswordPage(),
                ),
              );
            },
          ),
          ValueListenableBuilder<String?>(
            valueListenable: appPinCodeNotifier,
            builder: (context, pinCode, child) {
              return ListTile(
                title: const Text('PIN Code'),
                subtitle: Text(
                  pinCode == null ? 'Set a 4-digit PIN' : 'PIN is configured',
                ),
                leading: const Icon(Icons.pin_outlined),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PinCodePage()),
                  );
                },
              );
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Help & Support'),
            leading: const Icon(Icons.help_outline),
            onTap: () {},
          ),
          ListTile(
            title: const Text('About'),
            leading: const Icon(Icons.info_outline),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const String _devAgentShortcutUsername = '1q1q';
  static const String _devAgentShortcutPassword = '1q1q';
  static const String _devAgentEmail = 'johsah447@gmail.com';
  static const String _devAgentPassword = 'JMS_@26';
  static const String _devUserShortcutUsername = '2q2q';
  static const String _devUserShortcutPassword = '2q2q';
  static const String _devUserEmail = 'dev.user.2q2q@gmail.com';
  static const String _devUserPassword = '2q2q2q';

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String? _errorText;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (data.event == AuthChangeEvent.signedIn) {
        _routeByRole(data.session?.user);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _routeByRole(User? user) async {
    final role =
        ((user?.appMetadata['role'] ?? user?.userMetadata?['role']) as String?)
            ?.toLowerCase() ??
        'user';

    if (user != null) {
      await loadProperties();
    }

    if (!mounted) return;
    if (role == 'admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AdminHomePage(
            onLogout: () {
              Supabase.instance.client.auth.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    }
  }

  Future<void> _signInWithDevUserShortcut() async {
    try {
      final AuthResponse response = await Supabase.instance.client.auth
          .signInWithPassword(
            email: _devUserEmail,
            password: _devUserPassword,
          );
      await _routeByRole(response.user);
      return;
    } on AuthException catch (error) {
      final String message = error.message.toLowerCase();
      final bool shouldCreateAccount =
          message.contains('invalid login credentials') ||
          message.contains('user not found');

      if (!shouldCreateAccount) rethrow;
    }

    await Supabase.instance.client.auth.signUp(
      email: _devUserEmail,
      password: _devUserPassword,
      data: const {'role': 'user'},
    );

    final AuthResponse response = await Supabase.instance.client.auth
        .signInWithPassword(
          email: _devUserEmail,
          password: _devUserPassword,
        );
    await _routeByRole(response.user);
  }

  Future<void> _signIn() async {
    final enteredEmail = _emailController.text.trim();
    final enteredPassword = _passwordController.text;

    final bool isDevAgentShortcut =
        enteredEmail == _devAgentShortcutUsername &&
        enteredPassword == _devAgentShortcutPassword;
    final bool isDevUserShortcut =
        enteredEmail == _devUserShortcutUsername &&
        enteredPassword == _devUserShortcutPassword;

    if (isDevUserShortcut) {
      setState(() {
        _isLoading = true;
        _errorText = null;
      });

      try {
        await _signInWithDevUserShortcut();
      } on AuthException catch (e) {
        if (!mounted) return;
        setState(() {
          _errorText = e.message;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _errorText = 'Dev user login failed. Please try again.';
        });
      } finally {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    final email = isDevAgentShortcut ? _devAgentEmail : enteredEmail;
    final password = isDevAgentShortcut ? _devAgentPassword : enteredPassword;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorText = 'Please enter email and password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      await _routeByRole(response.user);
    } on AuthException catch (e) {
      if (!mounted) return;
      final String normalizedMessage = e.message.toLowerCase();
      setState(() {
        _errorText = normalizedMessage.contains('email rate limit exceeded')
            ? 'Too many signup attempts for now. The account may already exist, so try Login first. If it fails, wait a bit before signing up again.'
            : e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Login failed. Please try again.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _errorText = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb
            ? null
            : 'com.example.flutter_application_1://login-callback/',
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Google sign-in failed. Please try again.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isGoogleLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.landscape_rounded,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Land Finder',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Sign in to continue',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 6,
                    shadowColor: Colors.black12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: 'Email',
                              prefixIcon: const Icon(Icons.email_outlined),
                              filled: true,
                              fillColor: Theme.of(context).cardColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: Theme.of(context).cardColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          if (_errorText != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _errorText!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _signIn,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Login'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isGoogleLoading
                                  ? null
                                  : _signInWithGoogle,
                              icon: _isGoogleLoading
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.g_mobiledata),
                              label: const Text('Continue with Google'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SignUpPage(),
                                ),
                              );
                            },
                            child: const Text('Create an account'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ForgotPasswordPage(),
                                ),
                              );
                            },
                            child: const Text('Forgot password?'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorText = 'Please enter email and password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: const {'role': 'user'},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account created. Please verify your email before logging in.',
          ),
        ),
      );
      Navigator.pop(context);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Sign up failed. Please try again.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Center(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(_errorText!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signUp,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign Up'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorText = 'Please enter your email.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Check your inbox.'),
        ),
      );
      Navigator.pop(context);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Failed to send reset email. Please try again.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Center(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(_errorText!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendResetEmail,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send Reset Email'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorText;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _errorText = 'Please enter and confirm your new password.';
      });
      return;
    }

    if (newPassword.length < 6) {
      setState(() {
        _errorText = 'Password must be at least 6 characters.';
      });
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        _errorText = 'Passwords do not match.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
      Navigator.pop(context);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Failed to update password. Please try again.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Center(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  user?.email ?? 'Logged in account',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Change the password for your current account.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _newPasswordController,
                  obscureText: _obscureNewPassword,
                  decoration: InputDecoration(
                    hintText: 'New Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNewPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureNewPassword = !_obscureNewPassword;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    hintText: 'Confirm New Password',
                    prefixIcon: const Icon(Icons.verified_user_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(_errorText!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _changePassword,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Update Password'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TopHeader extends StatelessWidget {
  const TopHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isLightTheme = theme.brightness == Brightness.light;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kogihan Sa Negros',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Explore premium lots and investment-ready properties.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isLightTheme
                ? Color.alphaBlend(
                    theme.colorScheme.primary.withValues(alpha: 0.04),
                    theme.cardColor,
                  )
                : theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isLightTheme
                    ? theme.colorScheme.shadow.withValues(alpha: 0.06)
                    : const Color(0x14000000),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }
}

class SearchSection extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final String? selectedLocation;
  final String? selectedLotSize;
  final String? selectedBudget;
  final ValueChanged<String?> onLocationChanged;
  final ValueChanged<String?> onLotSizeChanged;
  final ValueChanged<String?> onBudgetChanged;
  final VoidCallback onResetFilters;

  const SearchSection({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.selectedLocation,
    required this.selectedLotSize,
    required this.selectedBudget,
    required this.onLocationChanged,
    required this.onLotSizeChanged,
    required this.onBudgetChanged,
    required this.onResetFilters,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isLightTheme = theme.brightness == Brightness.light;
    final Color searchSurface = isLightTheme
        ? Color.alphaBlend(
            theme.colorScheme.primary.withValues(alpha: 0.035),
            theme.colorScheme.surface,
          )
        : const Color(0xFFF1F4F6);
    final Color searchShadow = isLightTheme
        ? theme.colorScheme.shadow.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final Color textColor = isLightTheme
        ? theme.colorScheme.onSurface
        : const Color(0xFF1F2933);
    final Color mutedColor = isLightTheme
        ? theme.colorScheme.onSurfaceVariant
        : Colors.grey.shade700;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: searchSurface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: searchShadow,
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Search by city, barangay, or price',
              hintStyle: TextStyle(
                color: mutedColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Icon(Icons.search, color: mutedColor),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilterDropdown(
                label: 'Location',
                value: selectedLocation,
                items: const [
                  'Dumaguete City',
                  'Valencia',
                  'Bais City',
                  'Sibulan',
                  'Bayawan City',
                ],
                onChanged: onLocationChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilterDropdown(
                label: 'Lot Size',
                value: selectedLotSize,
                items: const [
                  'Below 500 sqm',
                  '500 - 1000 sqm',
                  'Above 1000 sqm',
                ],
                onChanged: onLotSizeChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilterDropdown(
                label: 'Budget',
                value: selectedBudget,
                items: const ['Below ₱1M', '₱1M - ₱3M', 'Above ₱3M'],
                onChanged: onBudgetChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class FilterDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const FilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final ThemeData theme = Theme.of(context);
    final Color dropdownSurface = isLightTheme
        ? Color.alphaBlend(
            theme.colorScheme.primary.withValues(alpha: 0.03),
            theme.colorScheme.surface,
          )
        : theme.cardColor;
    final Color dropdownShadow = isLightTheme
        ? theme.colorScheme.shadow.withValues(alpha: 0.05)
        : Colors.transparent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: dropdownSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isLightTheme
            ? [
                BoxShadow(
                  color: dropdownShadow,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        onChanged: onChanged,
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: isLightTheme
              ? theme.colorScheme.onSurfaceVariant
              : theme.iconTheme.color,
        ),
        style: TextStyle(
          color: isLightTheme
              ? theme.colorScheme.onSurface
              : theme.textTheme.bodyMedium?.color,
          fontWeight: FontWeight.w500,
        ),
        dropdownColor: theme.cardColor,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isLightTheme
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item, overflow: TextOverflow.ellipsis),
          );
        }).toList(),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String actionText;
  final VoidCallback? onPressed;

  const SectionHeader({
    super.key,
    required this.title,
    required this.actionText,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(onPressed: onPressed, child: Text(actionText)),
      ],
    );
  }
}

class PropertyCard extends StatelessWidget {
  final Property property;
  final bool isSaved;
  final VoidCallback onToggleSave;

  const PropertyCard({
    super.key,
    required this.property,
    required this.isSaved,
    required this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: isDark
            ? null
            : Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? const Color(0x12000000)
                : theme.colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                child: _buildPropertyImage(
                  property: property,
                  height: 210,
                  fallbackChild: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.landscape_rounded,
                          size: 64,
                          color: Colors.white,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Property Preview',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    property.tag,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: GestureDetector(
                  onTap: onToggleSave,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSaved ? Icons.favorite : Icons.favorite_border_rounded,
                      color: isSaved
                          ? Colors.red
                          : Theme.of(context).iconTheme.color,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  property.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        property.location,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_outlined,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            property.titleStatus,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      property.price,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E3A23)
                            : theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        property.size,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFF2E7D32)
                              : theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PropertyDetailsPage(
                            property: property,
                            isSaved: isSaved,
                            onToggleSave: onToggleSave,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('View Details'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PropertyDetailsPage extends StatefulWidget {
  final Property property;
  final bool isSaved;
  final VoidCallback onToggleSave;

  const PropertyDetailsPage({
    super.key,
    required this.property,
    required this.isSaved,
    required this.onToggleSave,
  });

  @override
  State<PropertyDetailsPage> createState() => _PropertyDetailsPageState();
}

class _PropertyDetailsPageState extends State<PropertyDetailsPage> {
  late bool _isSaved;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.isSaved;
  }

  void _handleToggleSave() {
    widget.onToggleSave();
    setState(() {
      _isSaved = !_isSaved;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Details'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPropertyImage(
              property: widget.property,
              height: 300,
              fallbackChild: const Center(
                child: Icon(
                  Icons.landscape_rounded,
                  size: 100,
                  color: Colors.white,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          widget.property.tag,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _handleToggleSave,
                        icon: Icon(
                          _isSaved
                              ? Icons.favorite
                              : Icons.favorite_border_rounded,
                          size: 28,
                          color: _isSaved
                              ? Colors.red
                              : Theme.of(context).iconTheme.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.pin_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.property.referenceCode,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.property.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.property.location,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_outlined,
                              size: 18,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.property.titleStatus,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Price',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.property.price,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Lot Size',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.property.size,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.property.description.trim().isEmpty
                        ? 'No description available for this property yet.'
                        : widget.property.description,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ContactAgentPage(property: widget.property),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Contact Agent',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

class ContactAgentPage extends StatefulWidget {
  final Property property;

  const ContactAgentPage({super.key, required this.property});

  @override
  State<ContactAgentPage> createState() => _ContactAgentPageState();
}

class _ContactAgentPageState extends State<ContactAgentPage> {
  late TextEditingController _messageController;
  late TextEditingController _fullNameController;
  late TextEditingController _contactController;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _contactController = TextEditingController();
    _messageController = TextEditingController(
      text:
          'Hi, I am interested in the ${widget.property.title} located at ${widget.property.location}. Please send me more details.',
    );
    unawaited(_loadProfile());
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _contactController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final MessagingProfile? profile =
          await MessagingService.fetchCurrentProfile();
      if (!mounted) return;

      _fullNameController.text = profile?.fullName?.trim().isNotEmpty == true
          ? profile!.fullName!.trim()
          : ((user.userMetadata?['full_name'] ??
                        user.userMetadata?['name'] ??
                        '')
                    as String)
                .trim();

      final String preferredContact = (profile?.phone ?? '').trim().isNotEmpty
          ? profile!.phone!.trim()
          : ((profile?.email ?? user.email ?? user.phone ?? '')).trim();
      _contactController.text = preferredContact;
    } catch (_) {}
  }

  Future<void> _sendInquiry() async {
    final String fullName = _fullNameController.text.trim();
    final String contactValue = _contactController.text.trim();
    final String message = _messageController.text.trim();

    if (fullName.isEmpty || contactValue.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete your name, contact, and message.'),
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await MessagingService.startConversationForProperty(
        property: widget.property,
        body: message,
        fullName: fullName,
        contactValue: contactValue,
      );

      if (!mounted) return;
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Message sent to agent successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Agent'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Icon(Icons.person, color: Colors.white, size: 36),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Juan Dela Cruz',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Senior Real Estate Agent',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'Your Details',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              context,
              'Full Name',
              Icons.person_outline,
              _fullNameController,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              context,
              'Email or Phone Number',
              Icons.contact_mail_outlined,
              _contactController,
            ),
            const SizedBox(height: 24),
            Text(
              'Message',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Enter your message',
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSending ? null : _sendInquiry,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Send Message',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context,
    String hint,
    IconData icon,
    TextEditingController controller,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class PinCodePage extends StatefulWidget {
  const PinCodePage({super.key});

  @override
  State<PinCodePage> createState() => _PinCodePageState();
}

class _PinCodePageState extends State<PinCodePage> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final currentPin = appPinCodeNotifier.value;
    if (currentPin != null) {
      _pinController.text = currentPin;
      _confirmPinController.text = currentPin;
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  void _savePinCode() {
    final pin = _pinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      setState(() {
        _errorText = 'PIN must be exactly 4 digits.';
      });
      return;
    }

    if (pin != confirmPin) {
      setState(() {
        _errorText = 'PIN entries do not match.';
      });
      return;
    }

    appPinCodeNotifier.value = pin;
    setState(() {
      _errorText = null;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('PIN code saved.')));
    Navigator.pop(context);
  }

  void _clearPinCode() {
    appPinCodeNotifier.value = null;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('PIN code removed.')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PIN Code'), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: InputDecoration(
                  hintText: 'Enter 4-digit PIN',
                  prefixIcon: const Icon(Icons.pin_outlined),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: InputDecoration(
                  hintText: 'Confirm PIN',
                  prefixIcon: const Icon(Icons.verified_user_outlined),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(_errorText!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _savePinCode,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Save PIN'),
                ),
              ),
              if (appPinCodeNotifier.value != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _clearPinCode,
                    child: const Text('Remove PIN'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subtitle;

  const EmptyState({
    super.key,
    this.icon = Icons.search_off,
    this.message = 'No properties matched your filters.',
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isLightTheme = theme.brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: isLightTheme
            ? Border.all(color: theme.colorScheme.outlineVariant)
            : null,
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
