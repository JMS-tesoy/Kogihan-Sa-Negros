import 'package:flutter/material.dart';

import '../../../../app/state/app_pin_code.dart';
import '../../../../core/widgets/app_snack_bar.dart';

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

    AppSnackBar.success(context, 'PIN code saved.');
    Navigator.pop(context);
  }

  void _clearPinCode() {
    appPinCodeNotifier.value = null;
    AppSnackBar.success(context, 'PIN code removed.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isDarkMode = theme.brightness == Brightness.dark;
    final Color cardBackgroundColor = isDarkMode
        ? theme.cardColor
        : Colors.white;
    final Color fieldFillColor = isDarkMode
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.72)
        : const Color(0xFFF9FAFB);
    final Color fieldBorderColor = isDarkMode
        ? colorScheme.outlineVariant
        : const Color(0xFFE4E7EC);
    final Color helperColor = colorScheme.onSurfaceVariant;
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
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('PIN Code')),
      body: SafeArea(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: cardBackgroundColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: <BoxShadow>[
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
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Center(
                        child: Container(
                          height: 78,
                          width: 78,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Container(
                              height: 56,
                              width: 56,
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.pin_outlined,
                                color: colorScheme.onPrimary,
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Secure access',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Set a 4-digit PIN to protect quick access to your account.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: helperColor,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 4,
                        decoration: InputDecoration(
                          hintText: 'Enter 4-digit PIN',
                          prefixIcon: const Icon(Icons.pin_outlined),
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
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 1.4,
                            ),
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
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                      if (_errorText != null) ...<Widget>[
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
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _savePinCode,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text('Save PIN'),
                        ),
                      ),
                      if (appPinCodeNotifier.value != null) ...<Widget>[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _clearPinCode,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text('Remove PIN'),
                          ),
                        ),
                      ],
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