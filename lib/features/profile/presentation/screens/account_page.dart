import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/widgets/app_snack_bar.dart';
import '../../../subscription/data/services/subscription_service.dart';
import '../../../subscription/presentation/screens/subscription_screen.dart';
import '../../data/models/profile_model.dart';
import '../../data/services/buyer_profile_service.dart';
import '../widgets/profile_formatters.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  late Future<BuyerProfileData> _profileFuture;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _controllersInitialized = false;
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _profileFuture = loadCurrentBuyerProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _editableProfileValue(String value, String emptyLabel) {
    return value == emptyLabel ? '' : value;
  }

  void _populateControllers(BuyerProfileData profile) {
    if (_controllersInitialized) return;

    _nameController.text = profile.displayName == 'Buyer'
        ? ''
        : profile.displayName;
    _emailController.text = _editableProfileValue(
      profile.email,
      'No email available',
    );
    _phoneController.text = _editableProfileValue(
      profile.phone,
      'No phone available',
    );
    _controllersInitialized = true;
  }

  Future<void> _saveAccountProfile() async {
    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _errorText = 'You need to be signed in to update your account.';
      });
      return;
    }

    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim();
    final String phone = _phoneController.text.trim();

    if (name.isEmpty) {
      setState(() {
        _errorText = 'Please enter your name.';
      });
      return;
    }

    if (email.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() {
        _errorText = 'Please enter a valid email address.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      await Supabase.instance.client.from('profiles').upsert({
        'id': user.id,
        'full_name': name,
        'email': email.isEmpty ? null : email,
        'phone': phone.isEmpty ? null : phone,
      }, onConflict: 'id');

      if (!mounted) return;

      final BuyerProfileData savedProfile = await loadCurrentBuyerProfileData();

      if (!mounted) return;

      setState(() {
        _profileFuture = Future<BuyerProfileData>.value(savedProfile);
        _controllersInitialized = false;
        _isSaving = false;
      });

      AppSnackBar.success(context, 'Account details updated.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorText = 'Failed to update account details: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isDarkMode = theme.brightness == Brightness.dark;
    final Color fieldFillColor = isDarkMode
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.72)
        : const Color(0xFFF9FAFB);
    final Color fieldBorderColor = isDarkMode
        ? colorScheme.outlineVariant
        : const Color(0xFFE4E7EC);
    final Color errorBackgroundColor = isDarkMode
        ? colorScheme.errorContainer.withValues(alpha: 0.32)
        : const Color(0xFFFFF1F3);
    final Color errorBorderColor = isDarkMode
        ? colorScheme.error.withValues(alpha: 0.50)
        : const Color(0xFFFDA29B);
    final Color errorTextColor = isDarkMode
        ? colorScheme.onErrorContainer
        : const Color(0xFFB42318);

    InputDecoration accountInputDecoration({
      required String labelText,
      required IconData icon,
    }) {
      return InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: fieldFillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: fieldBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Account'), centerTitle: true),
      body: ValueListenableBuilder<UserSubscription>(
        valueListenable: appSubscriptionNotifier,
        builder: (context, currentSubscription, child) {
          return FutureBuilder<BuyerProfileData>(
            future: _profileFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final BuyerProfileData profile = resolveBuyerProfileData(
                snapshot.data,
                currentSubscription,
              );
              _populateControllers(profile);

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Account Details',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            decoration: accountInputDecoration(
                              labelText: 'Name',
                              icon: Icons.person_outline,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: accountInputDecoration(
                              labelText: 'Email',
                              icon: Icons.email_outlined,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) {
                              if (!_isSaving) _saveAccountProfile();
                            },
                            decoration: accountInputDecoration(
                              labelText: 'Phone',
                              icon: Icons.phone_outlined,
                            ),
                          ),
                          if (_errorText != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: errorBackgroundColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: errorBorderColor),
                              ),
                              child: Text(
                                _errorText!,
                                style: TextStyle(color: errorTextColor),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveAccountProfile,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Save Changes'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.workspace_premium_outlined),
                      title: const Text('Subscription'),
                      subtitle: Text(
                        profile.isPremium
                            ? '${profile.planName} until ${formatSubscriptionDate(profile.expiresAt)}'
                            : 'Current plan: ${profile.planName}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SubscriptionPage(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
