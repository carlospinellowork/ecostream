class AppConstants {
  AppConstants._();

  static const String appName = 'EcoStream';
  static const String appTagline = 'Hub de Assinaturas & Serviços Digitais';

  // Moeda Padrão
  static const String defaultCurrency = 'BRL';
  static const String defaultCurrencySymbol = 'R\$';

  // Periodicidades de Cobrança
  static const List<String> billingCycles = [
    'mensal',
    'anual',
    'semanal',
    'trimestral',
    'semestral',
    'personalizada',
  ];

  // Métodos de Pagamento
  static const List<String> paymentMethods = [
    'Cartão de Crédito',
    'Cartão de Débito',
    'Pix',
    'Boleto',
    'PayPal',
    'Débito Automático',
    'Outro',
  ];
}
