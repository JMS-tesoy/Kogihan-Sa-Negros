import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/bootstrap/land_finder_app_bootstrap.dart';
import '../../../home/presentation/widgets/top_header.dart';
import '../../data/services/auth_session_service.dart';
import '../helpers/auth_error_messages.dart';
import '../helpers/dev_auth_shortcuts.dart';
import '../navigation/auth_navigation.dart';
import '../widgets/google_logo_icon.dart';
import 'forgot_password_page.dart';
import 'sign_up_page.dart';

class LoginPageView extends StatefulWidget {
  final WidgetBuilder loginBuilder;
  final WidgetBuilder homeBuilder;
  final WidgetBuilder adminBuilder;

  const LoginPageView({
    super.key,
    required this.loginBuilder,
    required this.homeBuilder,
    required this.adminBuilder,
  });

  @override
  State<LoginPageView> createState() => _LoginPageViewState();
}

class _LoginPageViewState extends State<LoginPageView> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String? _errorText;
  StreamSubscription<AuthState>? _authSubscription;
  bool _isRouting = false;
  bool _isOpeningPasswordRecovery = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = AuthSessionService.listenForLoginRouting(
      onPasswordRecovery: _openPasswordRecoveryPage,
      onSignedIn: _routeToAuthenticatedUser,
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _routeToAuthenticatedUser(User? user) async {
    if (user == null || !mounted || _isRouting || _isOpeningPasswordRecovery) {
      return;
    }

    _isRouting = true;
    try {
      await onUserLoggedIn();
      if (!mounted) return;
      await routeAuthenticatedUser(
        context,
        user: user,
        adminBuilder: widget.adminBuilder,
        homeBuilder: widget.homeBuilder,
      );
    } finally {
      if (mounted) {
        _isRouting = false;
      }
    }
  }

  Future<void> _openPasswordRecoveryPage() async {
    if (!mounted || _isOpeningPasswordRecovery) return;

    _isOpeningPasswordRecovery = true;
    await openPasswordRecoveryPage(context, loginBuilder: widget.loginBuilder);

    if (mounted) {
      _isOpeningPasswordRecovery = false;
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  Future<void> _signIn() async {
    final enteredEmail = _emailController.text.trim();
    final enteredPassword = _passwordController.text;

    final DevAuthShortcutResult devShortcut = devAuthShortcutForCredentials(
      email: enteredEmail,
      password: enteredPassword,
    );

    final String? disabledDevShortcutMessage = devShortcut.disabledMessage;

    if (disabledDevShortcutMessage != null) {
      setState(() {
        _errorText = disabledDevShortcutMessage;
      });
      return;
    }

    if (devShortcut.isUser) {
      setState(() {
        _isLoading = true;
        _errorText = null;
      });

      try {
        final User? user = await AuthSessionService.signInWithDevUserShortcut();
        await _routeToAuthenticatedUser(user);
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
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
      return;
    }

    final email = devShortcut.emailFor(enteredEmail);
    final password = devShortcut.passwordFor(enteredPassword);

    if (email.isEmpty) {
      setState(() {
        _errorText = 'Please enter your email address.';
      });
      return;
    }

    if (!_isValidEmail(email)) {
      setState(() {
        _errorText = 'Please enter a valid email address.';
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _errorText = 'Please enter your password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final User? user = await AuthSessionService.signInWithPassword(
        email: email,
        password: password,
      );
      await _routeToAuthenticatedUser(user);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = passwordSignInErrorMessage(e.message);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Login failed. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _errorText = null;
    });

    try {
      await AuthSessionService.signInWithGoogle();
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
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  InputDecoration _authInputDecoration({
    required BuildContext context,
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isDarkMode = theme.brightness == Brightness.dark;

    final Color fillColor = isDarkMode
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.34)
        : const Color(0xFFF8FAFC);

    final Color enabledBorderColor = isDarkMode
        ? colorScheme.outlineVariant.withValues(alpha: 0.34)
        : const Color(0xFFE2E8F0);

    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: Icon(prefixIcon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      labelStyle: theme.textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: theme.textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.58),
      ),
      prefixIconColor: WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return colorScheme.primary;
        }
        return colorScheme.onSurfaceVariant;
      }),
      suffixIconColor: WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return colorScheme.primary;
        }
        return colorScheme.onSurfaceVariant;
      }),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: enabledBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colorScheme.error, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isDarkMode = theme.brightness == Brightness.dark;

    final Color cardColor = isDarkMode
        ? theme.cardColor.withValues(alpha: 0.78)
        : Colors.white;

    final Color errorBackgroundColor = isDarkMode
        ? colorScheme.errorContainer.withValues(alpha: 0.32)
        : const Color(0xFFFFF1F3);

    final Color errorBorderColor = isDarkMode
        ? colorScheme.error.withValues(alpha: 0.50)
        : const Color(0xFFFDA29B);

    return Scaffold(
      body: Center(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const KsnHeaderLogo(size: 88),
                  const SizedBox(height: 14),
                  Text(
                    'KSN Property Finder',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Finding you an asset that fits your Budget',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Card(
                    elevation: 0,
                    color: cardColor,
                    shadowColor: Colors.black.withValues(alpha: 0.16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                      side: BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: isDarkMode ? 0.12 : 0.28,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const <String>[
                                AutofillHints.email,
                                AutofillHints.username,
                              ],
                              onChanged: (_) {
                                if (_errorText != null) {
                                  setState(() => _errorText = null);
                                }
                              },
                              decoration: _authInputDecoration(
                                context: context,
                                labelText: 'Email address',
                                hintText: 'name@example.com',
                                prefixIcon: Icons.email_outlined,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const <String>[
                                AutofillHints.password,
                              ],
                              onChanged: (_) {
                                if (_errorText != null) {
                                  setState(() => _errorText = null);
                                }
                              },
                              onSubmitted: (_) {
                                if (!_isLoading) {
                                  _signIn();
                                }
                              },
                              decoration: _authInputDecoration(
                                context: context,
                                labelText: 'Password',
                                hintText: 'Enter your password',
                                prefixIcon: Icons.lock_outline,
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
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
                              ),
                            ),
                            if (_errorText != null) ...<Widget>[
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: errorBackgroundColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: errorBorderColor),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Icon(
                                      Icons.error_outline_rounded,
                                      size: 20,
                                      color: colorScheme.error,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _errorText!,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: isDarkMode
                                                  ? colorScheme.onErrorContainer
                                                  : const Color(0xFFB42318),
                                              height: 1.35,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _signIn,
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
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
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
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
                                    : const GoogleLogoIcon(),
                                label: const Text('Continue with Google'),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  side: BorderSide(
                                    color: colorScheme.outline.withValues(
                                      alpha: 0.34,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (context) =>
                                            const SignUpPage(),
                                      ),
                                    );
                                  },
                                  child: const Text('Sign up'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (context) =>
                                            const ForgotPasswordPage(),
                                      ),
                                    );
                                  },
                                  child: const Text('Recover access'),
                                ),
                              ],
                            ),
                          ],
                        ),
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
