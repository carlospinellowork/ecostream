/// Plano do usuário.
enum Plan {
  free('Gratuito'),
  pro('Pro');

  const Plan(this.label);

  final String label;

  static Plan fromStorage(String? raw) => switch (raw) {
        'pro' => Plan.pro,
        _ => Plan.free,
      };
}

/// Recursos que podem ser bloqueados por plano.
///
/// Enumerar as capacidades — em vez de espalhar `if (plan == Plan.pro)` — permite
/// mudar a fronteira do paywall em um único lugar e testar a matriz inteira.
enum Feature {
  unlimitedSubscriptions('Assinaturas ilimitadas'),
  advancedInsights('Insights avançados'),
  annualSwitchAdvisor('Consultor de migração anual'),
  duplicateDetection('Detecção de serviços sobrepostos'),
  costPerUseAnalysis('Análise de custo por uso'),
  fiveYearProjection('Projeção de 5 anos'),
  customReminders('Lembretes personalizados'),
  csvExport('Exportação em CSV'),
  priceHistory('Histórico de preços');

  const Feature(this.label);

  final String label;
}

/// Um item vendável.
class PlanOffer {
  const PlanOffer({
    required this.id,
    required this.title,
    required this.price,
    required this.months,
    this.highlight = false,
    this.badge,
  });

  final String id;
  final String title;

  /// Preço total cobrado no período (não mensalizado).
  final double price;

  /// Duração do período contratado, em meses.
  final int months;

  /// Oferta destacada visualmente no paywall.
  final bool highlight;

  /// Selo curto, ex.: "Mais popular".
  final String? badge;

  /// Custo mensal equivalente, usado para comparar ofertas de períodos diferentes.
  double get monthlyEquivalent => price / months;
}

/// Catálogo de preços do EcoStream Pro.
///
/// A ancoragem é intencional: o plano mensal existe principalmente para dar
/// referência ao anual. Quem compara R$ 12,90/mês com R$ 7,99/mês percebe o desconto
/// sem precisar de cálculo, e o anual reduz churn e custo de cobrança.
///
/// Os valores estão em BRL e precisam ser espelhados nos produtos configurados na
/// Play Store e na App Store — a loja é a fonte de verdade em produção.
class PricingCatalog {
  PricingCatalog._();

  static const PlanOffer monthly = PlanOffer(
    id: 'ecostream_pro_monthly',
    title: 'Mensal',
    price: 12.90,
    months: 1,
  );

  static const PlanOffer annual = PlanOffer(
    id: 'ecostream_pro_annual',
    title: 'Anual',
    price: 95.90,
    months: 12,
    highlight: true,
    badge: 'Mais popular',
  );

  static const List<PlanOffer> offers = <PlanOffer>[annual, monthly];

  /// Duração do teste gratuito do Pro.
  static const Duration trialDuration = Duration(days: 7);

  /// Desconto do anual sobre 12 meses do mensal, em pontos percentuais.
  static double get annualDiscountPercent {
    final fullPrice = monthly.price * annual.months;
    return ((fullPrice - annual.price) / fullPrice) * 100;
  }

  /// Quanto o usuário deixa de gastar escolhendo o anual em vez do mensal.
  static double get annualSavings => monthly.price * annual.months - annual.price;

  static PlanOffer? offerById(String id) {
    for (final offer in offers) {
      if (offer.id == id) return offer;
    }
    return null;
  }
}

/// Limites do plano gratuito.
class FreePlanLimits {
  FreePlanLimits._();

  /// Quantidade máxima de assinaturas ativas no plano gratuito.
  ///
  /// 5 é escolhido de propósito: cobre com folga quem tem só streaming, então o app
  /// entrega valor real de graça, mas quem tem o problema que o EcoStream resolve
  /// (10, 15 assinaturas espalhadas) esbarra no limite exatamente quando já viu o
  /// benefício.
  static const int maxSubscriptions = 5;

  /// Lembretes por assinatura no plano gratuito.
  static const int maxRemindersPerSubscription = 1;

  /// Antecedência fixa do lembrete gratuito, em dias.
  static const int fixedReminderLeadDays = 1;
}
