import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:logging/logging.dart';

import 'app/app.dart';
import 'core/constants/app_config.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Attach a root listener immediately so the logging package never queues
  // records without a handler (prevents "too many loggers" warnings from
  // supabase_flutter / realtime-dart internals).
  Logger.root.level = Level.WARNING;
  Logger.root.onRecord.listen((_) {});

  assert(
    AppConfig.supabaseUrl.isNotEmpty,
    'SUPABASE_URL is empty — run with: flutter run --dart-define-from-file=.env.json',
  );

  await NotificationService.init();
  await preLoadLocale();
  await preLoadTheme();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    debug: false,
  );

  runApp(const ProviderScope(child: VBusApp()));
}

// Global Supabase client — use anywhere: supabase.from('table')...
final supabase = Supabase.instance.client;
