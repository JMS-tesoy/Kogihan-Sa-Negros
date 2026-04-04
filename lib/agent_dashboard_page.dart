import 'dart:math';

import 'package:flutter/material.dart';

import 'shared_properties.dart';

class AgentInquiry {
  final String id;
  final String buyerName;
  final String message;
  final String timeLabel;
  final bool isUnread;

  const AgentInquiry({
    required this.id,
    required this.buyerName,
    required this.message,
    required this.timeLabel,
    required this.isUnread,
  });

  AgentInquiry copyWith({
    String? id,
    String? buyerName,
    String? message,
    String? timeLabel,
    bool? isUnread,
  }) {
    return AgentInquiry(
      id: id ?? this.id,
      buyerName: buyerName ?? this.buyerName,
      message: message ?? this.message,
      timeLabel: timeLabel ?? this.timeLabel,
      isUnread: isUnread ?? this.isUnread,
    );
  }
}

class AdminHomePage extends StatefulWidget {
  final VoidCallback onLogout;

  const AdminHomePage({
    super.key,
    required this.onLogout,
  });

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final List<AgentInquiry> _inquiries = [
    const AgentInquiry(
      id: 'inquiry-1',
      buyerName: 'Juan Dela Cruz',
      message: 'Hi, is the Mountain View Land still available?',
      timeLabel: '10:30 AM',
      isUnread: true,
    ),
    const AgentInquiry(
      id: 'inquiry-2',
      buyerName: 'Maria Santos',
      message: 'Can you send the title copy for the Prime Residential Lot?',
      timeLabel: 'Yesterday',
      isUnread: true,
    ),
    const AgentInquiry(
      id: 'inquiry-3',
      buyerName: 'Carlo Reyes',
      message: 'I want to schedule a site visit this weekend.',
      timeLabel: 'Apr 2',
      isUnread: false,
    ),
  ];

  int get _unreadInquiryCount =>
      _inquiries.where((inquiry) => inquiry.isUnread).length;

  List<Property> get _properties => appPropertiesNotifier.value;

  @override
  void initState() {
    super.initState();
    appPropertiesNotifier.addListener(_refreshDashboard);
  }

  @override
  void dispose() {
    appPropertiesNotifier.removeListener(_refreshDashboard);
    super.dispose();
  }

  void _refreshDashboard() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openAddPropertyPage() async {
    final Property? newProperty = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PropertyFormPage(),
      ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add property: $e')),
      );
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
      MaterialPageRoute(
        builder: (context) => AgentInboxPage(
          inquiries: _inquiries,
          onMarkAsRead: _markInquiryAsRead,
        ),
      ),
    );

    if (!mounted) return;
  }

  Future<void> _updatePropertyRecord(Property updatedProperty) async {
    await updateProperty(updatedProperty);
  }

  Future<void> _deletePropertyRecord(String propertyId) async {
    await deleteProperty(propertyId);
  }

  void _markInquiryAsRead(String inquiryId) {
    final int index =
        _inquiries.indexWhere((inquiry) => inquiry.id == inquiryId);

    if (index == -1 || !_inquiries[index].isUnread) return;

    setState(() {
      _inquiries[index] = _inquiries[index].copyWith(isUnread: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.add_home_work, color: Color(0xFF2E7D32)),
              title: const Text('Add New Property'),
              subtitle: const Text('Create a new listing'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openAddPropertyPage,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.edit_note, color: Colors.orange),
              title: const Text('Manage Properties'),
              subtitle: Text('${_properties.length} listing(s) available'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openManagePropertiesPage,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.mail, color: Colors.blue),
              title: const Text('Agent Inbox'),
              subtitle: Text('$_unreadInquiryCount unread inquiry(s)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openInboxPage,
            ),
          ),
        ],
      ),
    );
  }
}

class PropertyFormPage extends StatefulWidget {
  final Property? initialProperty;

  const PropertyFormPage({
    super.key,
    this.initialProperty,
  });

  @override
  State<PropertyFormPage> createState() => _PropertyFormPageState();
}

class _PropertyFormPageState extends State<PropertyFormPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _priceController;
  late final TextEditingController _sizeController;
  late final TextEditingController _statusController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool get _isEditing => widget.initialProperty != null;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.initialProperty?.title ?? '');
    _locationController =
        TextEditingController(text: widget.initialProperty?.location ?? '');
    _priceController =
        TextEditingController(text: widget.initialProperty?.price ?? '');
    _sizeController =
        TextEditingController(text: widget.initialProperty?.size ?? '');
    _statusController =
        TextEditingController(text: widget.initialProperty?.tag ?? 'Active');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _sizeController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final int parsedPriceValue = _extractNumber(_priceController.text);
    final int parsedSizeValue = _extractNumber(_sizeController.text);

    final Property property = Property(
      id: widget.initialProperty?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      location: _locationController.text.trim(),
      price: _priceController.text.trim(),
      priceValue: parsedPriceValue > 0 ? parsedPriceValue : 0,
      size: _sizeController.text.trim(),
      sizeValue: parsedSizeValue > 0 ? parsedSizeValue : 0,
      tag: _statusController.text.trim(),
      imageColor: widget.initialProperty?.imageColor ?? _randomColor(),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Property' : 'Add New Property'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Clean title',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a clean title.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Grid coordinate',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a grid coordinate.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Price',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a price.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sizeController,
              decoration: const InputDecoration(
                labelText: 'Lot size',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a lot size.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _statusController,
              decoration: const InputDecoration(
                labelText: 'Card tag',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a card tag.';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
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

  @override
  void initState() {
    super.initState();
    _properties = List<Property>.from(widget.properties);
  }

  Future<void> _editProperty(Property property) async {
    final Property? updatedProperty = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PropertyFormPage(initialProperty: property),
      ),
    );

    if (updatedProperty == null || !mounted) return;

    final int index =
        _properties.indexWhere((item) => item.id == updatedProperty.id);

    if (index == -1) return;

    setState(() {
      _properties[index] = updatedProperty;
    });
    await widget.onUpdateProperty(updatedProperty);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${updatedProperty.title} updated successfully.')),
    );
  }

  Future<void> _deleteProperty(Property property) async {
    setState(() {
      _properties.removeWhere((item) => item.id == property.id);
    });
    await widget.onDeleteProperty(property.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${property.title} deleted.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Properties'),
      ),
      body: _properties.isEmpty
          ? const Center(
              child: Text('No properties available.'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _properties.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final Property property = _properties[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(property.title),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Grid: ${property.location}\n${property.price} • ${property.size}\nTag: ${property.tag}',
                      ),
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editProperty(property);
                        } else if (value == 'delete') {
                          _deleteProperty(property);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Text('Edit'),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                  ),
                );
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

  @override
  void initState() {
    super.initState();
    _inquiries = List<AgentInquiry>.from(widget.inquiries);
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
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InquiryDetailsPage(inquiry: inquiry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Inbox'),
      ),
      body: _inquiries.isEmpty
          ? const Center(
              child: Text('No buyer inquiries yet.'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _inquiries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final AgentInquiry inquiry = _inquiries[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(inquiry.buyerName[0]),
                    ),
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
    );
  }
}

class InquiryDetailsPage extends StatelessWidget {
  final AgentInquiry inquiry;

  const InquiryDetailsPage({
    super.key,
    required this.inquiry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(inquiry.buyerName),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Buyer Message',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(inquiry.message),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Received: ${inquiry.timeLabel}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Reply action for ${inquiry.buyerName}.'),
                    ),
                  );
                },
                icon: const Icon(Icons.reply),
                label: const Text('Reply'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
