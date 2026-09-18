/// Chaves de persistência local.
///
/// Centralizadas para evitar colisão e digitação errada espalhada pelo código.
/// Chaves por usuário são derivadas do `userId` — ao trocar de conta no mesmo
/// aparelho os dados não se misturam.
class StorageKeys {
  StorageKeys._();

  // --- Preferências globais (não sensíveis) ---
  static const String themeMode = 'app.theme_mode';

  // --- Autenticação ---
  /// Índice de contas cadastradas neste aparelho (JSON).
  static const String authAccounts = 'auth.accounts';

  /// Id do usuário da sessão ativa.
  static const String authActiveUserId = 'auth.active_user_id';

  /// Token de sessão. Vai para o armazenamento seguro, nunca para SharedPreferences.
  static const String authSessionToken = 'auth.session_token';

  /// Credencial (hash + salt) de um usuário, no armazenamento seguro.
  static String authCredential(String userId) => 'auth.credential.$userId';

  // --- Dados por usuário ---
  static String subscriptions(String userId) => 'data.subscriptions.$userId';

  static String reminderSettings(String userId) => 'data.reminder_settings.$userId';

  static String entitlement(String userId) => 'data.entitlement.$userId';

  /// Marcações de insights dispensados, para não repetir a mesma sugestão.
  static String dismissedInsights(String userId) => 'data.dismissed_insights.$userId';

  /// Se a carteira de exemplo já foi semeada para este usuário.
  ///
  /// Por usuário, e não global: só a conta de demonstração é semeada, e uma vez só.
  /// Depois disso, lista vazia significa que o usuário apagou tudo de propósito —
  /// repovoar seria desrespeitoso.
  static String demoSeeded(String userId) => 'data.demo_seeded.$userId';
}
