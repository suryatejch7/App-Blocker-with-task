/// Local environment configuration placeholder.
///
/// This app now runs fully local and does not require remote credentials.
class EnvConfig {
  EnvConfig._();

  static Future<void> initialize() async {}

  static String get supabaseUrl => '';
  static String get supabaseAnonKey => '';

  static bool get isValid => true;

  static void validate() {}
}
