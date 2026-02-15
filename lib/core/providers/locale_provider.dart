import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();
const _key = 'app_locale';

// Loaded synchronously before runApp — no async race.
Locale _cachedLocale = const Locale('en');

Future<void> preLoadLocale() async {
  final code = await _storage.read(key: _key);
  if (code != null && code != 'en') {
    _cachedLocale = Locale(code);
  }
}

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() => _cachedLocale;

  Future<void> setLocale(Locale locale) async {
    _cachedLocale = locale; // keep cache in sync in case provider is recreated
    state = locale;
    await _storage.write(key: _key, value: locale.languageCode);
  }

  bool get isHindi => state.languageCode == 'hi';
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);
