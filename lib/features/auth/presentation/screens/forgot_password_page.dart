import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/auth_config.dart';
import '../../../../core/widgets/app_snack_bar.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  Timer? _resetCountdownTimer;
  bool _isLoading = false;
  bool _emailSent = false;
  int _resetCountdown = 0;
  String? _errorText;

  @override
  void dispose() {
    _resetCountdownTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  void _startResetCountdown() {
    _resetCountdownTimer?.cancel();
    setState(() {
      _emailSent = true;
      _resetCountdown = 60;
    });

    _resetCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_resetCountdown <= 1) {
        timer.cancel();
        setState(() {
          _resetCountdown = 0;
        });
        return;
      }

      setState(() {
        _resetCountdown--;
      });
    });
  }

  Future<void> _sendResetEmail() async {
    if (_resetCountdown > 0) return;

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
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: AuthConfig.redirectUrl,
      );

      if (!mounted) return;

      AppSnackBar.success(
        context,
        'Password reset email sent. Check your inbox.',
      );

      _startResetCountdown();
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
    final Color errorBackgroundColor = isDarkMode
        ? colorScheme.errorContainer.withValues(alpha: 0.32)
        : const Color(0xFFFFF1F3);
    final Color errorBorderColor = isDarkMode
        ? colorScheme.error.withValues(alpha: 0.50)
        : const Color(0xFFFDA29B);
    final Color errorTextColor = isDarkMode
        ? colorScheme.onErrorContainer
        : const Color(0xFFB42318);
    final Color successBackgroundColor = isDarkMode
        ? const Color(0xFF052E16)
        : const Color(0xFFECFDF3);
    final Color successBorderColor = isDarkMode
        ? const Color(0xFF22C55E).withValues(alpha: 0.50)
        : const Color(0xFFABEFC6);
    final Color successTextColor = isDarkMode
        ? const Color(0xFF86EFAC)
        : const Color(0xFF067647);

    return Scaffold(
      backgroundColor: pageBackgroundColor,
      appBar: AppBar(title: const Text('Reset Password')),
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
                                Icons.lock_outline,
                                color: colorScheme.onPrimary,
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Forgot your password?',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: headingColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your email and we will send you a secure reset link.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: helperColor,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.email],
                        onSubmitted: (_) {
                          if (!_isLoading && _resetCountdown == 0) {
                            _sendResetEmail();
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Email address',
                          hintText: 'name@example.com',
                          prefixIcon: const Icon(Icons.email_outlined),
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
                      if (_emailSent && _errorText == null) ...[
                        const SizedBox(height: 14),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: successBackgroundColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: successBorderColor),
                            ),
                            child: Text(
                              _resetCountdown > 0
                                  ? 'Reset link sent. Check your inbox.'
                                  : 'Reset link sent. You can resend now.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: successTextColor),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading || _resetCountdown > 0
                              ? null
                              : _sendResetEmail,
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
                              : _resetCountdown > 0
                              ? Text('Resend in ${_resetCountdown}s')
                              : const Text('Send Reset Email'),
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