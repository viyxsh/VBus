import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // Live-prototype mode: the app behaves normally but never writes to the
  // backend — seat bookings, chat, pins, profile edits and trip/attendance
  // actions all return a simulated success so a public demo can't corrupt real
  // data or leak between visitors. Defaults to ON for the web demo build and
  // OFF on mobile; force either way with --dart-define=DEMO_MODE=true|false.
  static const String _demoModeOverride = String.fromEnvironment('DEMO_MODE');
  static bool get demoMode =>
      _demoModeOverride.isEmpty ? kIsWeb : _demoModeOverride == 'true';

  // Demo accounts for the web demo's one-tap "dummy" sign-in. Supplied via
  // --dart-define-from-file=.env.json (kept out of source control).
  static const String demoStudentEmail =
      String.fromEnvironment('DEMO_STUDENT_EMAIL');
  static const String demoStudentPassword =
      String.fromEnvironment('DEMO_STUDENT_PASSWORD');
  static const String demoConductorUsername =
      String.fromEnvironment('DEMO_CONDUCTOR_USERNAME');
  static const String demoConductorPassword =
      String.fromEnvironment('DEMO_CONDUCTOR_PASSWORD');

  static bool get hasDemoStudent =>
      demoStudentEmail.isNotEmpty && demoStudentPassword.isNotEmpty;
  static bool get hasDemoConductor =>
      demoConductorUsername.isNotEmpty && demoConductorPassword.isNotEmpty;
}
