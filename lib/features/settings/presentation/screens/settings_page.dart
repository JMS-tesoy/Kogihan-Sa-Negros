import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/state/app_display_preferences.dart'
    as app_display_preferences;
import '../../../../app/state/app_display_preferences.dart'
    show appFontScaleNotifier, appThemeNotifier;
import '../../../../app/state/app_pin_code.dart';
import '../../../../core/constants/storage_constants.dart';
import '../../../../features/auth/presentation/screens/change_password_screen.dart';
import '../../../../features/messaging/presentation/widgets/inbox_conversation_helpers.dart';
import '../../../../features/profile/presentation/screens/account_page.dart';
import '../../../../features/profile/presentation/screens/pin_code_screen.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  late bool _followSystemTheme;
  late ThemeMode _preferredThemeMode;
  bool _notifyNewProperties = true;
  bool _notifyPriceDrops = true;
  bool _notifyMessages = true;
  double _currentFontSizeScale = 1.0;

  @override
  void initState() {
    super.initState();
    final Brightness systemBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _followSystemTheme = appThemeNotifier.value == ThemeMode.system;
    final bool shouldUseDarkPreference =
        appThemeNotifier.value == ThemeMode.dark ||
        (appThemeNotifier.value == ThemeMode.system &&
            systemBrightness == Brightness.dark);
    _preferredThemeMode = shouldUseDarkPreference
        ? ThemeMode.dark
        : ThemeMode.light;
    _currentFontSizeScale = appFontScaleNotifier.value;
    unawaited(_loadPreferredThemeMode());
  }

  Future<void> _loadPreferredThemeMode() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? preferredThemeMode = preferences.getString(
      StorageConstants.preferredThemeMode,
    );
    if (!mounted || preferredThemeMode == null) return;

    setState(() {
      _preferredThemeMode = preferredThemeMode == 'dark'
          ? ThemeMode.dark
          : ThemeMode.light;
      if (!_followSystemTheme) {
        appThemeNotifier.value = _preferredThemeMode;
      }
    });
  }

  Widget _buildCompactSwitchTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool dense = false,
  }) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color activeSwitchColor = isDarkMode
        ? const Color(0xFF7DD3FC)
        : Theme.of(context).colorScheme.primary;
    return SwitchListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      value: value,
      dense: dense,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onChanged: onChanged,
      activeThumbColor: activeSwitchColor,
      controlAffinity: ListTileControlAffinity.trailing,
    );
  }

  Widget _buildAppearanceSwitchTile({
    required String title,
    String? subtitle,
    required bool value,
    ValueChanged<bool>? onChanged,
    bool isChild = false,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool isEnabled = onChanged != null;
    final Color activeSwitchColor = isDarkMode
        ? const Color(0xFF7DD3FC)
        : Theme.of(context).colorScheme.primary;

    return ListTile(
      enabled: isEnabled,
      dense: isChild,
      title: Text(title, style: isChild ? theme.textTheme.bodyMedium : null),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, style: isChild ? theme.textTheme.bodySmall : null),
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: isEnabled ? () => onChanged(!value) : null,
      trailing: Transform.scale(
        scale: 0.76,
        alignment: Alignment.centerRight,
        child: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: activeSwitchColor,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.30),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? Colors.black.withValues(alpha: 0.14)
                      : Colors.black.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _settingsDivider() {
    return const Divider(height: 1, indent: 16, endIndent: 16);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;
    final Color activeSwitchColor = isDarkMode
        ? const Color(0xFF7DD3FC)
        : theme.colorScheme.primary;
    final user = Supabase.instance.client.auth.currentUser;
    final String accountLabel = user?.email ?? 'Logged in account';

    return Scaffold(
      backgroundColor: isDarkMode
          ? theme.scaffoldBackgroundColor
          : const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: Theme(
        data: theme.copyWith(
          switchTheme: SwitchThemeData(
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return activeSwitchColor;
              }
              return null;
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return activeSwitchColor.withValues(alpha: 0.42);
              }
              return null;
            }),
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AccountPage(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode
                            ? Colors.black.withValues(alpha: 0.14)
                            : Colors.black.withValues(alpha: 0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        foregroundColor: theme.colorScheme.primary,
                        child: Text(
                          messageInitial(accountLabel),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Account Settings',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              accountLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _buildSectionCard(
              title: 'Notifications',
              children: [
                Transform.scale(
                  scale: 0.76,
                  alignment: Alignment.centerRight,
                  child: _buildCompactSwitchTile(
                    title: 'Push Notifications',
                    subtitle: 'Receive alerts for new lots',
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                    },
                  ),
                ),
                if (_notificationsEnabled) ...[
                  _settingsDivider(),
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      children: [
                        Transform.scale(
                          scale: 0.76,
                          alignment: Alignment.centerRight,
                          child: _buildCompactSwitchTile(
                            title: 'New Lot Alerts',
                            value: _notifyNewProperties,
                            dense: true,
                            onChanged: (value) {
                              setState(() => _notifyNewProperties = value);
                            },
                          ),
                        ),
                        _settingsDivider(),
                        Transform.scale(
                          scale: 0.76,
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
                        _settingsDivider(),
                        Transform.scale(
                          scale: 0.76,
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
                ],
              ],
            ),
            _buildSectionCard(
              title: 'Appearance',
              children: [
                ListTile(
                  title: const Text('Font Size'),
                  subtitle: Text(
                    'Adjust text size for better readability (${_currentFontSizeScale.toStringAsFixed(1)}x)',
                  ),
                  leading: const Icon(Icons.format_size),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 20),
                  child: Slider(
                    value: _currentFontSizeScale,
                    min: 0.8,
                    max: 1.5,
                    divisions: 7,
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
                    textScaler: TextScaler.linear(_currentFontSizeScale),
                  ),
                ),
              ],
            ),
            _buildSectionCard(
              title: 'Dark Mode',
              children: [
                _buildAppearanceSwitchTile(
                  title: 'Follow System Theme',
                  subtitle: 'Match your phone display mode',
                  value: _followSystemTheme,
                  isChild: true,
                  onChanged: (value) {
                    setState(() {
                      _followSystemTheme = value;
                      if (value) {
                        _preferredThemeMode = ThemeMode.light;
                        appThemeNotifier.value = ThemeMode.system;
                      } else {
                        appThemeNotifier.value = _preferredThemeMode;
                      }
                    });
                    unawaited(
                      app_display_preferences
                          .AppDisplayPreferences.persistFollowSystemThemePreference(
                        value,
                      ),
                    );
                    if (value) {
                      unawaited(
                        app_display_preferences
                            .AppDisplayPreferences.persistPreferredThemeMode(
                          ThemeMode.light,
                        ),
                      );
                    } else {
                      unawaited(
                        app_display_preferences
                            .AppDisplayPreferences.persistPreferredThemeMode(
                          _preferredThemeMode,
                        ),
                      );
                    }
                  },
                ),
                _settingsDivider(),
                _buildAppearanceSwitchTile(
                  title: 'Use Dark Theme',
                  subtitle: 'Use your preferred app theme',
                  value:
                      !_followSystemTheme &&
                      _preferredThemeMode == ThemeMode.dark,
                  isChild: true,
                  onChanged: _followSystemTheme
                      ? null
                      : (value) {
                          final ThemeMode selectedThemeMode = value
                              ? ThemeMode.dark
                              : ThemeMode.light;
                          setState(() {
                            _preferredThemeMode = selectedThemeMode;
                            appThemeNotifier.value = selectedThemeMode;
                          });
                          unawaited(
                            app_display_preferences
                                .AppDisplayPreferences.persistPreferredThemeMode(
                              selectedThemeMode,
                            ),
                          );
                        },
                ),
              ],
            ),
            _buildSectionCard(
              title: 'Security',
              children: [
                ListTile(
                  title: const Text('Password'),
                  subtitle: const Text('Update your account password'),
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
                _settingsDivider(),
                ValueListenableBuilder<String?>(
                  valueListenable: appPinCodeNotifier,
                  builder: (context, pinCode, child) {
                    return ListTile(
                      title: const Text('PIN Code'),
                      subtitle: Text(
                        pinCode == null
                            ? 'Protect access with a 4-digit PIN'
                            : 'PIN is configured',
                      ),
                      leading: const Icon(Icons.pin_outlined),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PinCodePage(),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
            _buildSectionCard(
              title: 'Support',
              children: [
                ListTile(
                  title: const Text('Help & Support'),
                  leading: const Icon(Icons.help_outline),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                _settingsDivider(),
                ListTile(
                  title: const Text('About'),
                  leading: const Icon(Icons.info_outline),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
