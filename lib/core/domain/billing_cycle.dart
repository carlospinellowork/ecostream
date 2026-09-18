/// Periodicidade de cobrança de uma assinatura.
///
/// Substitui a antiga `String billingCycle`, que permitia valores inválidos e tinha um
/// caso `'personalizada'` que silenciosamente tratava o preço como mensal — ou seja,
/// subestimava o gasto anual do usuário. Um app de dinheiro não pode ter esse buraco.
///
/// A serialização usa [name] (inglês, estável). O rótulo em pt-BR é apenas apresentação
/// e pode mudar sem quebrar dados salvos.
enum BillingCycle {
  weekly('Semanal', 'semana'),
  monthly('Mensal', 'mês'),
  quarterly('Trimestral', 'trimestre'),
  semiannual('Semestral', 'semestre'),
  annual('Anual', 'ano');

  const BillingCycle(this.label, this.unitLabel);

  /// Rótulo exibido em seletores. Ex.: "Mensal".
  final String label;

  /// Unidade usada em frases de preço. Ex.: "R$ 59,90 / mês".
  final String unitLabel;

  /// Quantas cobranças acontecem em 12 meses.
  ///
  /// Semanal usa 52 semanas/ano (52/12 ≈ 4,333 por mês), e não "4 por mês" —
  /// arredondar para 4 esconde quase um mês de gasto por ano.
  double get occurrencesPerYear => switch (this) {
        BillingCycle.weekly => 52.0,
        BillingCycle.monthly => 12.0,
        BillingCycle.quarterly => 4.0,
        BillingCycle.semiannual => 2.0,
        BillingCycle.annual => 1.0,
      };

  /// Intervalo aproximado em dias, usado para projeções e calendário.
  int get approximateDays => switch (this) {
        BillingCycle.weekly => 7,
        BillingCycle.monthly => 30,
        BillingCycle.quarterly => 91,
        BillingCycle.semiannual => 182,
        BillingCycle.annual => 365,
      };

  /// Intervalo em meses, quando o ciclo é múltiplo de mês. `null` para semanal.
  int? get intervalInMonths => switch (this) {
        BillingCycle.weekly => null,
        BillingCycle.monthly => 1,
        BillingCycle.quarterly => 3,
        BillingCycle.semiannual => 6,
        BillingCycle.annual => 12,
      };

  /// Desserializa a partir de [name]. Aceita também os rótulos em português usados
  /// antes da migração para enum, para não perder dados de instalações antigas.
  static BillingCycle fromStorage(String? raw) {
    if (raw == null) return BillingCycle.monthly;
    final normalized = raw.toLowerCase().trim();
    for (final cycle in BillingCycle.values) {
      if (cycle.name.toLowerCase() == normalized) return cycle;
      if (cycle.label.toLowerCase() == normalized) return cycle;
    }
    return switch (normalized) {
      'semanal' => BillingCycle.weekly,
      'mensal' => BillingCycle.monthly,
      'trimestral' => BillingCycle.quarterly,
      'semestral' => BillingCycle.semiannual,
      'anual' => BillingCycle.annual,
      // Legado: 'personalizada' era tratada como mensal. Mantemos o comportamento
      // na leitura para não alterar retroativamente o histórico do usuário.
      _ => BillingCycle.monthly,
    };
  }
}
