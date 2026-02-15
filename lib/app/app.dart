import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/locale_provider.dart';
import '../core/providers/theme_provider.dart';
import 'router/router.dart';

// ─── Seed colours ─────────────────────────────────────────────────────────────
// Primary: deep indigo-blue.  Secondary: teal-cyan accent.
const _seed      = Color(0xFF3D5AFE); // vivid indigo
const _secondary = Color(0xFF00BCD4); // cyan accent

ThemeData _light() {
  final cs = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: Brightness.light,
    secondary: _secondary,
  ).copyWith(
    // Warmer surface tints for depth
    surface: const Color(0xFFF8F9FF),
    surfaceContainerLow:  const Color(0xFFEFF1FB),
    surfaceContainerHigh: const Color(0xFFE3E6F5),
    primaryContainer: const Color(0xFFDDE3FF),
    secondaryContainer: const Color(0xFFCBF0F8),
  );

  return ThemeData(
    colorScheme: cs,
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF3F4FA),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: cs.onSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: const TextStyle(
        fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: cs.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: s.contains(WidgetState.selected) ? cs.primary : cs.onSurfaceVariant,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: cs.primary,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cs.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dividerTheme: const DividerThemeData(space: 1, thickness: 1),
  );
}

ThemeData _dark() {
  final cs = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: Brightness.dark,
    secondary: _secondary,
  ).copyWith(
    surface: const Color(0xFF12131A),
    surfaceContainerLow:  const Color(0xFF1C1E2C),
    surfaceContainerHigh: const Color(0xFF252840),
    primaryContainer: const Color(0xFF1F2A6B),
    secondaryContainer: const Color(0xFF003E4A),
    onSurface: const Color(0xFFE8EAFF),
  );

  return ThemeData(
    colorScheme: cs,
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0D0E18),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF1C1E2C),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF12131A),
      foregroundColor: cs.onSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: const TextStyle(
        fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFFE8EAFF),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF12131A),
      indicatorColor: cs.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: s.contains(WidgetState.selected) ? cs.primary : cs.onSurfaceVariant,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: cs.primary,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cs.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dividerTheme: const DividerThemeData(space: 1, thickness: 1),
  );
}

class VBusApp extends ConsumerWidget {
  const VBusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router    = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);
    final locale    = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'VBUS',
      debugShowCheckedModeBanner: false,
      theme:      _light(),
      darkTheme:  _dark(),
      themeMode:  themeMode,
      locale:     locale,
      supportedLocales: const [Locale('en'), Locale('hi')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
