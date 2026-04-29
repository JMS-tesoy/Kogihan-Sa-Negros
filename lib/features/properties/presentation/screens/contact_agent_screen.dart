import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../messaging/data/services/messaging_service.dart';
import '../../data/datasources/shared_properties.dart';

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
