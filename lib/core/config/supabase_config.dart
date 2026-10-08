// lib/core/config/supabase_config.dart

class SupabaseConfig {
  const SupabaseConfig._();

  /// Supabase Project URL
  /// Can be overridden at runtime via:
  /// flutter run --dart-define=SUPABASE_URL=...
  /// or --dart-define-from-file=.env
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://npmseeaohrxzhxpfifvl.supabase.co',
  );

  /// Supabase Publishable / Anon Key (Safe for client mobile distribution)
  /// NEVER place the service_role key here.
  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'sb_publishable_5dKP0gWUj7_hZh-DczgRXA_a0GLzTq1',
    ),
  );

  /// Optional app environment name
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  /// API timeout in seconds
  static const int apiTimeoutSeconds = int.fromEnvironment(
    'API_TIMEOUT_SECONDS',
    defaultValue: 30,
  );
}
