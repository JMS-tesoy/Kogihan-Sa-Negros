import 'package:flutter/material.dart';

ThemeData buildLandFinderLightTheme() {
  const Color seedColor = Color(0xFF2563EB);
  final ColorScheme scheme =
      ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFF2563EB),
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFDBEAFE),
        onPrimaryContainer: const Color(0xFF123B7A),
        secondary: const Color(0xFF64748B),
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFFE8EEF6),
        onSecondaryContainer: const Color(0xFF243449),
        surface: const Color(0xFFFFFFFF),
        onSurface: const Color(0xFF0F172A),
        surfaceContainerHighest: const Color(0xFFEEF2F6),
        onSurfaceVariant: const Color(0xFF475569),
        outline: const Color(0xFFD7DFE8),
        outlineVariant: const Color(0xFFE6ECF2),
        shadow: const Color(0xFF0F172A),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    cardColor: scheme.surface,
    dividerColor: scheme.outlineVariant,
    canvasColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      elevation: 12,
      indicatorColor: scheme.primaryContainer,
      shadowColor: scheme.shadow.withValues(alpha: 0.18),
      surfaceTintColor: Colors.transparent,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surface,
      selectedColor: scheme.primaryContainer,
      disabledColor: scheme.surfaceContainerHighest,
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      secondaryLabelStyle: TextStyle(color: scheme.onPrimaryContainer),
      side: BorderSide(color: scheme.outlineVariant),
      elevation: 5,
      pressElevation: 8,
      shadowColor: scheme.shadow.withValues(alpha: 0.20),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 6,
        shadowColor: scheme.shadow.withValues(alpha: 0.24),
        surfaceTintColor: Colors.transparent,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 6,
        shadowColor: scheme.shadow.withValues(alpha: 0.24),
        surfaceTintColor: Colors.transparent,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: scheme.surface,
        elevation: 4,
        shadowColor: scheme.shadow.withValues(alpha: 0.18),
        side: BorderSide(color: scheme.outlineVariant),
        surfaceTintColor: Colors.transparent,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: scheme.primary),
    ),
    iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
    textTheme: ThemeData.light().textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
  );
}

ThemeData buildLandFinderDarkTheme() {
  const Color seedColor = Color(0xFF2563EB);
  final ColorScheme scheme =
      ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFF60A5FA),
        onPrimary: const Color(0xFF07111F),
        primaryContainer: const Color(0xFF1E3A8A),
        onPrimaryContainer: const Color(0xFFDBEAFE),
        secondary: const Color(0xFF94A3B8),
        onSecondary: const Color(0xFF0F172A),
        secondaryContainer: const Color(0xFF1E293B),
        onSecondaryContainer: const Color(0xFFE2E8F0),
        surface: const Color(0xFF111827),
        onSurface: const Color(0xFFE5E7EB),
        surfaceContainerHighest: const Color(0xFF1F2937),
        onSurfaceVariant: const Color(0xFFCBD5E1),
        outline: const Color(0xFF475569),
        outlineVariant: const Color(0xFF334155),
        shadow: Colors.black,
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    cardColor: scheme.surface,
    dividerColor: scheme.outlineVariant,
    canvasColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      elevation: 10,
      indicatorColor: scheme.primaryContainer,
      shadowColor: Colors.black.withValues(alpha: 0.38),
      surfaceTintColor: Colors.transparent,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surface,
      selectedColor: scheme.primaryContainer,
      disabledColor: scheme.surfaceContainerHighest,
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      secondaryLabelStyle: TextStyle(color: scheme.onPrimaryContainer),
      side: BorderSide(color: scheme.outlineVariant),
      elevation: 4,
      pressElevation: 7,
      shadowColor: Colors.black.withValues(alpha: 0.42),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 5,
        shadowColor: Colors.black.withValues(alpha: 0.42),
        surfaceTintColor: Colors.transparent,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 5,
        shadowColor: Colors.black.withValues(alpha: 0.42),
        surfaceTintColor: Colors.transparent,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: scheme.surface,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.36),
        side: BorderSide(color: scheme.outlineVariant),
        surfaceTintColor: Colors.transparent,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: scheme.primary),
    ),
    iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
    textTheme: ThemeData.dark().textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
  );
}
