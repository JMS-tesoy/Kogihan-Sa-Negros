import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/widgets/app_snack_bar.dart';

class ChangePasswordPage extends StatefulWidget {
  final bool isPasswordRecovery;
  final WidgetBuilder? recoveryLoginBuilder;

  const ChangePasswordPage({
    super.key,
    this.isPasswordRecovery = false,
    this.recoveryLoginBuilder,
  });

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

  String? _validatePasswordComplexity(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters.';
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Password must include at least one uppercase letter.';
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Password must include at least one lowercase letter.';
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password must include at least one number.';
    }

    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      return 'Password must include at least one symbol.';
    }

    return null;
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

    final passwordError = _validatePasswordComplexity(newPassword);
    if (passwordError != null) {
      setState(() {
        _errorText = passwordError;
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

      AppSnackBar.success(context, 'Password updated successfully.');

      if (widget.isPasswordRecovery) {
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;

        final loginBuilder = widget.recoveryLoginBuilder;
        if (loginBuilder != null) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: loginBuilder),
            (route) => false,
          );
        } else {
          Navigator.pop(context);
        }
        return;
      }

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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final user = Supabase.instance.client.auth.currentUser;
    final String pageTitle = widget.isPasswordRecovery
        ? 'Create New Password'
        : 'Reset Password';
    final String heading = widget.isPasswordRecovery
        ? 'Create a new password'
        : 'Update your password';
    final String helperText = widget.isPasswordRecovery
        ? 'Choose a secure password for your account.'
        : 'Change the password for your current account.';
    final bool isDarkMode = theme.brightness == Brightness.dark;
    final Color pageBackgroundColor = isDarkMode
        ? theme.scaffoldBackgroundColor
        : const Color(0xFFF7F8FA);
    final Color cardBackgroundColor = isDarkMode
        ? theme.cardColor
        : Colors.white;
    final Color fieldFillColor = isDarkMode
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.72)
        : const Color(0xFFF9FAFB);
    final Color fieldBorderColor = isDarkMode
        ? colorScheme.outlineVariant
        : const Color(0xFFE4E7EC);
    final Color headingColor = isDarkMode
        ? colorScheme.onSurface
        : const Color(0xFF101828);
    final Color helperColor = isDarkMode
        ? colorScheme.onSurfaceVariant
        : const Color(0xFF667085);
    final Color accountTextColor = isDarkMode
        ? colorScheme.onSurface
        : const Color(0xFF475467);
    final Color errorBackgroundColor = isDarkMode
        ? colorScheme.errorContainer.withValues(alpha: 0.32)
        : const Color(0xFFFFF1F3);
    final Color errorBorderColor = isDarkMode
        ? colorScheme.error.withValues(alpha: 0.50)
        : const Color(0xFFFDA29B);
    final Color errorTextColor = isDarkMode
        ? colorScheme.onErrorContainer
        : const Color(0xFFB42318);

    return Scaffold(
      backgroundColor: pageBackgroundColor,
      appBar: AppBar(title: Text(pageTitle)),
      body: SafeArea(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: cardBackgroundColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode
                            ? Colors.black.withValues(alpha: 0.24)
                            : const Color(0x12000000),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          height: 86,
                          width: 86,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Container(
                              height: 64,
                              width: 64,
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.lock_reset_outlined,
                                color: colorScheme.onPrimary,
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        heading,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: headingColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        helperText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: helperColor,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: fieldFillColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: fieldBorderColor),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.alternate_email,
                              color: helperColor,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                user?.email ?? 'Logged in account',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: accountTextColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _newPasswordController,
                        obscureText: _obscureNewPassword,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'New password',
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
                          fillColor: fieldFillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(color: fieldBorderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use 8+ characters with uppercase, lowercase, number, and symbol.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: helperColor,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        onSubmitted: (_) {
                          if (!_isLoading) _changePassword();
                        },
                        decoration: InputDecoration(
                          labelText: 'Confirm new password',
                          prefixIcon: const Icon(Icons.verified_user_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: fieldFillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(color: fieldBorderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                      if (_errorText != null) ...[
                        const SizedBox(height: 14),
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
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _changePassword,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Update Password'),
                        ),
                      ),
                    ],
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
