/// Supabase project settings.
///
/// The publishable key is designed to ship inside the app: Row Level
/// Security in the database decides what each user can read or change.
/// Never put the secret / service_role key in the app.
///
/// Override per build if needed:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xzyhartphvcmrrjvball.supabase.co',
  );

  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_1aH8Ftf3dxOP_kokH9tQkQ_ewiayrWF',
  );
}
