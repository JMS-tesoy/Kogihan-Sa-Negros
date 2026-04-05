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
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF2E7D32),
                  brightness: Brightness.light,
                ),
                scaffoldBackgroundColor: const Color(0xFFF5F7FA),
              ),
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
    return _availableProperties.where((property) {
      final bool matchesSearch =
          _searchQuery.isEmpty ||
          property.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          property.location.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          property.price.toLowerCase().contains(_searchQuery.toLowerCase());

      final bool matchesLocation =
          _selectedLocation == null || property.location == _selectedLocation;

      final bool matchesLotSize = switch (_selectedLotSize) {
        null => true,
        'Below 500 sqm' => property.sizeValue < 500,
        '500 - 1000 sqm' =>
          property.sizeValue >= 500 && property.sizeValue <= 1000,
        'Above 1000 sqm' => property.sizeValue > 1000,
        _ => true,
      };

      final bool matchesBudget = switch (_selectedBudget) {
        null => true,
        'Below ₱1M' => property.priceValue < 1000000,
        '₱1M - ₱3M' =>
          property.priceValue >= 1000000 && property.priceValue <= 3000000,
        'Above ₱3M' => property.priceValue > 3000000,
        _ => true,
      };

      return matchesSearch &&
          matchesLocation &&
          matchesLotSize &&
          matchesBudget;
    }).toList();
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

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomeTab(
        properties: _filteredProperties,
        savedProperties: _savedProperties,
        onToggleSave: (property) {
          setState(() {
            if (_savedProperties.contains(property)) {
              _savedProperties.remove(property);
            } else {
              _savedProperties.add(property);
            }
          });
        },
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
      SavedTab(savedProperties: _savedProperties.toList()),
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

  const SavedTab({super.key, required this.savedProperties});

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
                  ? const EmptyState()
                  : ListView.separated(
                      itemCount: savedProperties.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final property = savedProperties[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.favorite,
                              color: Colors.red,
                            ),
                            title: Text(property.title),
                            subtitle: Text(property.location),
                            trailing: Text(property.price),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      PropertyDetailsPage(property: property),
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
                    backgroundColor: const Color(0xFF2E7D32),
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
                        color: const Color(0xFF2E7D32),
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

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.senderName,
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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
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
                    final bool isLightTheme =
                        Theme.of(context).brightness == Brightness.light;
                    final Color bubbleColor = isMe
                        ? (isLightTheme
                              ? const Color(0xFFDDF2E4)
                              : Theme.of(context).colorScheme.primaryContainer)
                        : (isLightTheme
                              ? const Color(0xFFE5EFFC)
                              : Theme.of(context).colorScheme.secondaryContainer);
                    final Color textColor = isMe
                        ? (isLightTheme
                              ? const Color(0xFF123524)
                              : Theme.of(context).colorScheme.onPrimaryContainer)
                        : (isLightTheme
                              ? const Color(0xFF17324D)
                              : Theme.of(context).colorScheme.onSecondaryContainer);
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
                      onSubmitted: (_) => _sendMessage(),
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
                              icon: Icon(
                                Icons.send_rounded,
                                color: Theme.of(context).colorScheme.onPrimary,
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

  Future<void> _signIn() async {
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
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      await _routeByRole(response.user);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = e.message;
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
                  const Icon(
                    Icons.landscape_rounded,
                    size: 80,
                    color: Color(0xFF2E7D32),
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
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 12,
                offset: Offset(0, 4),
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
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F4F6),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            style: const TextStyle(
              color: Color(0xFF1F2933),
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Search by city, barangay, or price',
              hintStyle: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Icon(Icons.search, color: Colors.grey.shade800),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isLightTheme
            ? const Color(0xFFF1F4F6)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isLightTheme
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
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
              ? const Color(0xFF52606D)
              : Theme.of(context).iconTheme.color,
        ),
        style: TextStyle(
          color: isLightTheme
              ? const Color(0xFF1F2933)
              : Theme.of(context).textTheme.bodyMedium?.color,
          fontWeight: FontWeight.w500,
        ),
        dropdownColor: Theme.of(context).cardColor,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isLightTheme
                ? const Color(0xFF52606D)
                : Theme.of(context).colorScheme.onSurfaceVariant,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 6),
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
                child: Container(
                  height: 210,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        property.imageColor,
                        property.imageColor.withOpacity(0.75),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(
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
                    color: const Color(0xFF2E7D32),
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
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      property.price,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2E7D32),
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
                            : const Color(0xFFEAF6EC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        property.size,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E7D32),
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
                          builder: (context) =>
                              PropertyDetailsPage(property: property),
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

class PropertyDetailsPage extends StatelessWidget {
  final Property property;

  const PropertyDetailsPage({super.key, required this.property});

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
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    property.imageColor,
                    property.imageColor.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
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
                          color: const Color(0xFF2E7D32),
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
                      IconButton(
                        onPressed: () {},
                        icon: Icon(
                          Icons.favorite_border_rounded,
                          size: 28,
                          color: Theme.of(context).iconTheme.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    property.title,
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
                        property.location,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                            property.price,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
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
                            property.size,
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
                    'This is a premium property located in the heart of the region. Perfect for investment or building your dream home, it offers great accessibility and scenic surroundings. Contact an agent for an exact lot plan and title verification.',
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
                  builder: (context) => ContactAgentPage(property: property),
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
                const CircleAvatar(
                  radius: 32,
                  backgroundColor: Color(0xFF2E7D32),
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
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_off, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'No properties matched your filters.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
