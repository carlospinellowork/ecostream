/// Constantes de identidade e de domínio do app.
class AppConstants {
  AppConstants._();

  static const String appName = 'EcoStream';
  static const String appTagline = 'Hub de assinaturas e serviços digitais';

  /// Mantenha em sincronia com o campo `version` do `pubspec.yaml`.
  static const String appVersion = 'v1.1.0';

  // --- Moeda ---
  static const String defaultCurrency = 'BRL';
  static const String defaultCurrencySymbol = r'R$';

  // --- Conta de demonstração ---
  //
  // Serve para avaliar o app sem cadastro. É uma conta local real, com senha, e é a
  // **única** que recebe a carteira de exemplo — uma conta criada de verdade pelo
  // usuário começa vazia, porque semear Netflix e Disney+ falsos no cadastro de
  // alguém seria mentir sobre os dados dele.
  static const String demoEmail = 'demo@ecostream.app';
  static const String demoName = 'Visitante EcoStream';

  /// Senha fixa da conta de demonstração.
  ///
  /// Não é segredo: a conta existe apenas neste aparelho, não tem dado real e é
  /// criada pelo próprio app. Guardá-la aqui em claro não expõe nada.
  static const String demoPassword = 'ecostream-demo-2026';

  /// Formas de pagamento oferecidas no cadastro.
  ///
  /// Livre e ordenada pela frequência de uso no Brasil — cartão de crédito é a
  /// forma dominante em assinatura recorrente, então vem primeiro e é o padrão.
  static const List<String> paymentMethods = <String>[
    'Cartão de Crédito',
    'Pix',
    'Débito Automático',
    'Cartão de Débito',
    'Boleto',
    'PayPal',
    'Google Play',
    'App Store',
    'Outro',
  ];
}
