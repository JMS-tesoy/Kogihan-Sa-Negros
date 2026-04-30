import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../home/presentation/widgets/top_header.dart';
import '../../data/services/auth_session_service.dart';
import '../helpers/auth_error_messages.dart';
import '../helpers/dev_auth_shortcuts.dart';
import '../navigation/auth_navigation.dart';
import '../widgets/google_logo_icon.dart';
import 'forgot_password_page.dart';
import 'sign_up_page.dart';

class LegacyLoginPage extends StatefulWidget {
  final WidgetBuilder loginBuilder;
  final WidgetBuilder homeBuilder;
  final WidgetBuilder adminBuilder;

  const LegacyLoginPage({
    super.key,
    required this.loginBuilder,
    required this.homeBuilder,
    required this.adminBuilder,
  });

  @override
  State<LegacyLoginPage> createState() => _LegacyLoginPageState();
}

class _LegacyLoginPageState extends State<LegacyLoginPage> {
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
    await openPasswordRecoveryPage(
      context,
      loginBuilder: widget.loginBuilder,
    );

    if (mounted) {
      _isOpeningPasswordRecovery = false;
    }
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
                  const KsnHeaderLogo(size: 88),
                  const SizedBox(height: 12),
                  Text(
                    'Kogihan Sa Negros',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'finding you an asset that fits your budget',
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
                      child: AutofillGroup(
                        child: Column(
                          children: [
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [
                                AutofillHints.email,
                                AutofillHints.username,
                              ],
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
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
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
                                    : const GoogleLogoIcon(),
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
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
                                      MaterialPageRoute(
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
