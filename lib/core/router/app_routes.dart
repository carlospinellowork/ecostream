/// Caminhos e nomes de rota.
///
/// Centralizados para que nenhuma tela escreva `context.go('/dashbord')` e descubra
/// o erro em produção. A constante quebra na compilação; a string, não.
class AppRoutes {
  AppRoutes._();

  // --- Públicas ---
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/cadastro';
  static const String forgotPassword = '/recuperar-senha';

  // --- Autenticadas (dentro do shell com barra de navegação) ---
  static const String dashboard = '/inicio';
  static const String subscriptions = '/assinaturas';
  static const String calendar = '/calendario';
  static const String insights = '/insights';
  static const String profile = '/perfil';

  // --- Autenticadas (tela cheia, empilhadas sobre o shell) ---
  static const String addSubscription = '/assinaturas/nova';
  static const String editSubscription = '/assinaturas/:id/editar';
  static const String paywall = '/pro';
  static const String notificationSettings = '/perfil/notificacoes';

  /// Monta o caminho de edição com o id preenchido.
  static String editSubscriptionPath(String id) => '/assinaturas/$id/editar';

  /// Rotas que um usuário não autenticado pode acessar.
  static const Set<String> publicRoutes = <String>{
    splash,
    login,
    register,
    forgotPassword,
  };
}
