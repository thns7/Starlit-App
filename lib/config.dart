/// Configuração do Supabase.
///
/// Os valores podem ser sobrescritos na hora do build:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
///
/// A chave "anon"/"publishable" é pública por natureza: a segurança dos dados
/// vem das políticas de Row Level Security definidas em supabase/migrations.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://qqdppsccsyevazhophsk.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_T4n44fHZYJf-K4uk0NSOQw_E1mTl1nJ',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
