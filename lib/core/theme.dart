// DDE-Mart driver app — design system.
//
// Brand: deep royal blue + amber accent. Every screen pulls colors, type,
// radii, shadows and gradients from here — no hardcoded off-theme colors.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App theme mode (system / light / dark), persisted locally.
class ThemeModeStore extends StateNotifier<ThemeMode> {
  ThemeModeStore() : super(ThemeMode.system) {
    _restore();
  }

  static const _key = 'ui.theme_mode';

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = switch (prefs.getString(_key)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {
      // Corrupt prefs never block launch.
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        switch (mode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        },
      );
    } catch (_) {
      // Persistence is best-effort.
    }
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeStore, ThemeMode>(
  (ref) => ThemeModeStore(),
);

class DdeTheme {
  static const primary = Color(0xFF1D4ED8);
  static const primaryDark = Color(0xFF1E3A8A);
  static const primaryDeep = Color(0xFF0B1B4D);
  static const accent = Color(0xFFF59E0B);
  static const accentDeep = Color(0xFFB45309);
  static const danger = Color(0xFFE11D48);
  static const success = Color(0xFF16A34A);
  static const successDark = Color(0xFF15803D);

  // Radii.
  static const radiusCard = 20.0;
  static const radiusCardLg = 24.0;
  static const radiusSheet = 28.0;
  static const radiusPill = 999.0;
  static const pad = 16.0;

  // Full type scale (display w800, titles w700).
  static const displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.15,
  );
  static const displayMedium = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.2,
  );
  static const titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
    height: 1.25,
  );
  static const titleMedium = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );
  static const titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.35,
  );

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      secondary: accent,
      brightness: Brightness.light,
    );
    return _base(scheme);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      secondary: accent,
      brightness: Brightness.dark,
    );
    return _base(scheme);
  }

  static ThemeData _base(ColorScheme scheme) {
    final text = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
    ).textTheme;
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text.copyWith(
        displayLarge: displayLarge.copyWith(color: scheme.onSurface),
        displayMedium: displayMedium.copyWith(color: scheme.onSurface),
        headlineSmall: const TextStyle(fontWeight: FontWeight.w800),
        headlineMedium: const TextStyle(fontWeight: FontWeight.w800),
        titleLarge: titleLarge.copyWith(color: scheme.onSurface),
        titleMedium: titleMedium.copyWith(color: scheme.onSurface),
        titleSmall: titleSmall.copyWith(color: scheme.onSurface),
        labelLarge: const TextStyle(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusSheet)),
        ),
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCardLg),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
      ),
    );
  }

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Soft layered shadow (never flat grey elevation).
  static List<BoxShadow> softShadow(BuildContext context) {
    final dark = isDark(context);
    return [
      BoxShadow(
        color: (dark ? Colors.black : primaryDark).withValues(
          alpha: dark ? 0.45 : 0.10,
        ),
        blurRadius: 24,
        offset: const Offset(0, 12),
      ),
      BoxShadow(
        color: (dark ? Colors.black : primaryDark).withValues(
          alpha: dark ? 0.25 : 0.06,
        ),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// Primary header gradient (extends the legacy headerGradient).
  static BoxDecoration headerGradient(BuildContext context) {
    final dark = isDark(context);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? [primaryDark, primaryDeep]
            : [primary, primaryDark],
      ),
    );
  }

  /// Warm amber accent gradient for highlights, badges and CTAs.
  static BoxDecoration accentGradient(BuildContext context) {
    final dark = isDark(context);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark ? [accent, accentDeep] : [accent, const Color(0xFFFBBF24)],
      ),
    );
  }

  /// Green success gradient for earnings and completed states.
  static BoxDecoration successGradient(BuildContext context) {
    final dark = isDark(context);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? [successDark, const Color(0xFF14532D)]
            : [success, const Color(0xFF4ADE80)],
      ),
    );
  }

  /// Gradient tile decoration for icon tiles (StatCard, headers).
  static BoxDecoration iconTile(
    BuildContext context, {
    bool accent = false,
    bool success = false,
    double radius = 14,
  }) {
    final base = success
        ? successGradient(context)
        : accent
            ? accentGradient(context)
            : headerGradient(context);
    return base.copyWith(borderRadius: BorderRadius.circular(radius));
  }
}
