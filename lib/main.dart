import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

final ValueNotifier<ThemeMode> appThemeNotifier = ValueNotifier(ThemeMode.light);

void main() {
  runApp(const RealEstateApp());
}

class RealEstateApp extends StatelessWidget {
  const RealEstateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Land Finder',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
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
          home: const HomePage(),
        );
      },
    );
  }
}

class Property {
  final String title;
  final String location;
  final String price;
  final int priceValue;
  final String size;
  final int sizeValue;
  final String tag;
  final Color imageColor;

  const Property({
    required this.title,
    required this.location,
    required this.price,
    required this.priceValue,
    required this.size,
    required this.sizeValue,
    required this.tag,
    required this.imageColor,
  });
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

  String? _profileImagePath;
  final ImagePicker _imagePicker = ImagePicker();

  final List<Property> _allProperties = const [
    Property(
      title: 'Prime Residential Lot',
      location: 'Dumaguete City',
      price: '₱1,200,000',
      priceValue: 1200000,
      size: '500 sqm',
      sizeValue: 500,
      tag: 'Featured',
      imageColor: Color(0xFF9CCC65),
    ),
    Property(
      title: 'Mountain View Land',
      location: 'Valencia',
      price: '₱2,450,000',
      priceValue: 2450000,
      size: '1,200 sqm',
      sizeValue: 1200,
      tag: 'Hot Deal',
      imageColor: Color(0xFFA1887F),
    ),
    Property(
      title: 'Farm Lot Investment',
      location: 'Bais City',
      price: '₱3,100,000',
      priceValue: 3100000,
      size: '2,000 sqm',
      sizeValue: 2000,
      tag: 'New',
      imageColor: Color(0xFF64B5F6),
    ),
    Property(
      title: 'Highway Frontage Lot',
      location: 'Sibulan',
      price: '₱4,800,000',
      priceValue: 4800000,
      size: '1,500 sqm',
      sizeValue: 1500,
      tag: 'Premium',
      imageColor: Color(0xFFBA68C8),
    ),
    Property(
      title: 'Affordable Starter Lot',
      location: 'Bayawan City',
      price: '₱900,000',
      priceValue: 900000,
      size: '300 sqm',
      sizeValue: 300,
      tag: 'Budget',
      imageColor: Color(0xFFFFB74D),
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    return _allProperties.where((property) {
      final bool matchesSearch = _searchQuery.isEmpty ||
          property.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          property.location.toLowerCase().contains(_searchQuery.toLowerCase()) ||
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
      SavedTab(
        savedProperties: _savedProperties.toList(),
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

  const SavedTab({
    super.key,
    required this.savedProperties,
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
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
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

class MessagesTab extends StatelessWidget {
  const MessagesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inbox',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  _buildMessageTile(
                    context,
                    'Juan Dela Cruz',
                    'Hi, are you still interested in the Mountain View Land?',
                    '10:30 AM',
                    true,
                  ),
                  const SizedBox(height: 12),
                  _buildMessageTile(
                    context,
                    'Maria Santos',
                    'The documents for the Prime Residential Lot are ready.',
                    'Yesterday',
                    false,
                  ),
                  const SizedBox(height: 12),
                  _buildMessageTile(
                    context,
                    'System',
                    'Welcome to Kogihan Sa Negros! Explore our premium properties.',
                    'Oct 12',
                    false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageTile(
    BuildContext context,
    String sender,
    String snippet,
    String time,
    bool isUnread,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color:
              Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
          child: Text(sender[0]),
        ),
        title: Text(
          sender,
          style: TextStyle(
            fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          snippet,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
            color: isUnread
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              time,
              style: TextStyle(
                fontSize: 12,
                color: isUnread
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isUnread) ...[
              const SizedBox(height: 4),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ]
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatPage(
                senderName: sender,
                initialMessage: snippet,
              ),
            ),
          );
        },
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
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
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
          ],
        ),
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isMe;

  ChatMessage({required this.text, required this.isMe});
}

class ChatPage extends StatefulWidget {
  final String senderName;
  final String initialMessage;

  const ChatPage({
    super.key,
    required this.senderName,
    required this.initialMessage,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  late List<ChatMessage> _messages;

  @override
  void initState() {
    super.initState();
    _messages = [
      ChatMessage(text: widget.initialMessage, isMe: false),
    ];
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: _messageController.text.trim(),
            isMe: true,
          ),
        );
        _messageController.clear();
      });
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
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg.isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: msg.isMe
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: msg.isMe
                            ? const Radius.circular(0)
                            : const Radius.circular(16),
                        bottomLeft: !msg.isMe
                            ? const Radius.circular(0)
                            : const Radius.circular(16),
                      ),
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        color: msg.isMe
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
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
                    child: IconButton(
                      icon: Icon(
                        Icons.send_rounded,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      onPressed: _sendMessage,
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
  bool _locationEnabled = true;
  late bool _darkModeEnabled;

  @override
  void initState() {
    super.initState();
    _darkModeEnabled = appThemeNotifier.value == ThemeMode.dark;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Push Notifications'),
            subtitle: const Text('Receive alerts for new properties'),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Switch to a darker theme'),
            value: _darkModeEnabled,
            onChanged: (value) {
              setState(() {
                _darkModeEnabled = value;
                appThemeNotifier.value =
                    value ? ThemeMode.dark : ThemeMode.light;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Location Services'),
            subtitle: const Text('Allow app to access your location'),
            value: _locationEnabled,
            onChanged: (value) {
              setState(() {
                _locationEnabled = value;
              });
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('About'),
            leading: const Icon(Icons.info_outline),
            onTap: () {},
          ),
          ListTile(
            title: const Text('Log Out'),
            leading: const Icon(Icons.logout, color: Colors.red),
            textColor: Colors.red,
            onTap: () {},
          ),
        ],
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
        TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search by city, barangay, or price',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Theme.of(context).cardColor,
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
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
                items: const [
                  'Below ₱1M',
                  '₱1M - ₱3M',
                  'Above ₱3M',
                ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
        ),
        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              overflow: TextOverflow.ellipsis,
            ),
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
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        TextButton(
          onPressed: onPressed,
          child: Text(actionText),
        ),
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
                      isSaved
                          ? Icons.favorite
                          : Icons.favorite_border_rounded,
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
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
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
                      foregroundColor:
                          Theme.of(context).colorScheme.onPrimary,
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

  const PropertyDetailsPage({
    super.key,
    required this.property,
  });

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
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
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
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ContactAgentPage extends StatefulWidget {
  final Property property;

  const ContactAgentPage({
    super.key,
    required this.property,
  });

  @override
  State<ContactAgentPage> createState() => _ContactAgentPageState();
}

class _ContactAgentPageState extends State<ContactAgentPage> {
  late TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(
      text:
          'Hi, I am interested in the ${widget.property.title} located at ${widget.property.location}. Please send me more details.',
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Agent'),
        centerTitle: true,
      ),
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildTextField(context, 'Full Name', Icons.person_outline),
            const SizedBox(height: 12),
            _buildTextField(
              context,
              'Email or Phone Number',
              Icons.contact_mail_outlined,
            ),
            const SizedBox(height: 24),
            Text(
              'Message',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message sent to agent successfully!'),
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
                child: const Text(
                  'Send Message',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(BuildContext context, String hint, IconData icon) {
    return TextField(
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
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}