class EmailUtils {
  static const _studentRegex =
      r'^[a-z]+\.[0-9]{2}[a-z]{3}[0-9]{5}@vitbhopal\.ac\.in$';

  static bool isStudentEmail(String email) =>
      RegExp(_studentRegex, caseSensitive: false).hasMatch(email);

  static bool isFacultyEmail(String email) =>
      email.toLowerCase().endsWith('@vitbhopal.ac.in') &&
      !isStudentEmail(email);

  static bool isValidUniversityEmail(String email) =>
      email.toLowerCase().endsWith('@vitbhopal.ac.in');

  // Maps conductor username to synthetic email for Supabase auth
  // Conductor_11 → conductor_11@vbus.internal
  static String conductorEmail(String username) =>
      '${username.toLowerCase()}@vbus.internal';
}
