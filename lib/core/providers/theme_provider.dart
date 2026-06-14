import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();
const _key = 'theme_mode';

// Loaded synchronously before runApp — no async race on first frame.
ThemeMode _cachedTheme = ThemeMode.system;

Future<void> preLoadTheme() async {
  final val = await _storage.read(key: _key);
  if (val == 'dark')  _cachedTheme = ThemeMode.dark;
  if (val == 'light') _cachedTheme = ThemeMode.light;
}

class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => _cachedTheme;

  Future<void> setMode(ThemeMode mode) async {
    _cachedTheme = mode;
    state = mode;
    await _storage.write(
      key: _key,
      value: mode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  bool get isDark => state == ThemeMode.dark;
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);
