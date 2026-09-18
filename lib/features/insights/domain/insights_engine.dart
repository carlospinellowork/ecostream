import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/financial_calculator.dart';
import '../../../core/utils/recurrence.dart';
import '../../billing/domain/plan.dart';
import '../../categories/domain/category_model.dart';
import '../../subscriptions/domain/subscription_model.dart';
import 'insight.dart';

/// Gera os insights financeiros a partir das assinaturas do usuário.
///
/// Totalmente determinístico e sem dependência de Flutter ou de I/O: as mesmas
/// entradas produzem sempre as mesmas conclusões. É o que torna possível testar
/// cada regra isoladamente, o que é obrigatório aqui — um insight errado manda o
/// usuário cancelar algo que ele usa (CLAUDE.md §10).
class InsightsEngine {
  const InsightsEngine({this.now});

  /// Referência temporal. Injetável para tornar os testes determinísticos.
  final DateTime? now;

  DateTime get _reference => now ?? DateTime.now();

  /// Executa todas as regras e devolve os insights ordenados por relevância.
  List<Insight> analyze(List<SubscriptionModel> subscriptions) {
    final active = subscriptions.where((s) => s.isActive).toList(growable: false);
    if (active.isEmpty) return const <Insight>[];

    final insights = <Insight>[
      ..._wastedSpend(active),
      ..._annualSwitchOpportunities(active),
      ..._overlappingServices(active),
      ..._priceIncreases(active),
      ..._costPerUseOutliers(active),
      ..._concentration(active),
      ..._billingSpike(active),
      ..._projection(active),
    ];

    // Ordena por severidade e, dentro dela, pelo dinheiro em jogo. O usuário lê de
    // cima para baixo e precisa encontrar o maior ganho primeiro.
    insights.sort((a, b) {
      final bySeverity = b.severity.index.compareTo(a.severity.index);
      if (bySeverity != 0) return bySeverity;
      return b.potentialAnnualSavings.compareTo(a.potentialAnnualSavings);
    });

    return List<Insight>.unmodifiable(insights);
  }

  /// Soma de tudo que poderia ser economizado por ano se o usuário agisse em todos
  /// os insights acionáveis. É o número do topo da tela e o argumento do paywall.
  double totalPotentialAnnualSavings(List<SubscriptionModel> subscriptions) {
    return analyze(subscriptions)
        .where((i) => i.isActionable)
        .fold<double>(0, (sum, i) => sum + i.potentialAnnualSavings);
  }

  // --- Regra 1: serviços pagos e não usados ---

  /// Serviço marcado como "não uso mais" é desperdício integral; "raramente" é
  /// candidato a revisão. Os dois viram insights, com severidades diferentes.
  List<Insight> _wastedSpend(List<SubscriptionModel> subs) {
    final unused = subs.where((s) => s.usageLevel == UsageLevel.never).toList();
    final rarely = subs.where((s) => s.usageLevel == UsageLevel.low).toList();

    final result = <Insight>[];

    if (unused.isNotEmpty) {
      final annual = unused.fold<double>(0, (sum, s) => sum + s.annualEquivalent);
      result.add(
        Insight(
          id: 'wasted_never',
          kind: InsightKind.wastedSpend,
          severity: InsightSeverity.critical,
          title: 'Você paga por ${unused.length} '
              '${unused.length == 1 ? 'serviço que não usa' : 'serviços que não usa'}',
          description: '${_nameList(unused)} ${unused.length == 1 ? 'está' : 'estão'} '
              'marcado${unused.length == 1 ? '' : 's'} como sem uso e '
              '${unused.length == 1 ? 'custa' : 'custam'} '
              '${CurrencyFormatter.format(annual)} por ano. '
              'Cancelar hoje devolve esse valor inteiro ao seu orçamento.',
          potentialAnnualSavings: annual,
          subscriptionIds: unused.map((s) => s.id).toList(growable: false),
          actionLabel: 'Revisar agora',
        ),
      );
    }

    if (rarely.isNotEmpty) {
      final annual = rarely.fold<double>(0, (sum, s) => sum + s.annualEquivalent);
      result.add(
        Insight(
          id: 'wasted_low',
          kind: InsightKind.wastedSpend,
          severity: InsightSeverity.warning,
          title: '${rarely.length} '
              '${rarely.length == 1 ? 'serviço usado' : 'serviços usados'} raramente',
          description: '${_nameList(rarely)} '
              '${rarely.length == 1 ? 'consome' : 'consomem'} '
              '${CurrencyFormatter.format(annual)} por ano com uso baixo. '
              'Pausar em vez de cancelar costuma preservar seu histórico no serviço.',
          potentialAnnualSavings: annual,
          subscriptionIds: rarely.map((s) => s.id).toList(growable: false),
          actionLabel: 'Pausar ou cancelar',
        ),
      );
    }

    return result;
  }

  // --- Regra 2: migração para plano anual ---

  /// Migrar de mensal para anual costuma render de 10% a 20% ao ano e é o ganho
  /// mais fácil de capturar: o usuário não perde nenhum serviço.
  List<Insight> _annualSwitchOpportunities(List<SubscriptionModel> subs) {
    final candidates = subs
        .where((s) => s.annualSwitchSavings != null)
        .toList(growable: false);
    if (candidates.isEmpty) return const <Insight>[];

    final total = candidates.fold<double>(0, (sum, s) => sum + s.annualSwitchSavings!);

    return <Insight>[
      Insight(
        id: 'annual_switch',
        kind: InsightKind.annualSwitch,
        severity: InsightSeverity.opportunity,
        title: 'Troque para o plano anual e economize '
            '${CurrencyFormatter.format(total)}',
        description: '${_nameList(candidates)} '
            '${candidates.length == 1 ? 'oferece' : 'oferecem'} plano anual mais barato '
            'que o mensal. Você mantém exatamente os mesmos serviços.',
        potentialAnnualSavings: total,
        requiredFeature: Feature.annualSwitchAdvisor,
        subscriptionIds: candidates.map((s) => s.id).toList(growable: false),
        actionLabel: 'Ver planos anuais',
      ),
    ];
  }

  // --- Regra 3: serviços sobrepostos ---

  /// Três ou mais serviços na mesma categoria indicam sobreposição real (o caso
  /// clássico: quatro streamings de vídeo). A economia estimada é o **mais barato**
  /// do excedente, não a soma — a sugestão é cortar um, não todos.
  List<Insight> _overlappingServices(List<SubscriptionModel> subs) {
    final byCategory = <String, List<SubscriptionModel>>{};
    for (final sub in subs) {
      byCategory.putIfAbsent(sub.categoryId, () => <SubscriptionModel>[]).add(sub);
    }

    final result = <Insight>[];
    byCategory.forEach((categoryId, items) {
      if (items.length < _overlapThreshold) return;

      final sorted = items.toList()
        ..sort((a, b) => a.annualEquivalent.compareTo(b.annualEquivalent));
      final cheapest = sorted.first;
      final categoryName = CategoryModel.byId(categoryId).name;
      final monthlyTotal = items.fold<double>(0, (sum, s) => sum + s.monthlyEquivalent);

      result.add(
        Insight(
          id: 'overlap_$categoryId',
          kind: InsightKind.overlap,
          severity: InsightSeverity.opportunity,
          title: '${items.length} serviços de $categoryName ao mesmo tempo',
          description: 'Você mantém ${_nameList(items)}, somando '
              '${CurrencyFormatter.format(monthlyTotal)} por mês. '
              'Alternar entre eles — assinar um, cancelar o outro — costuma entregar '
              'o mesmo catálogo por menos.',
          potentialAnnualSavings: cheapest.annualEquivalent,
          requiredFeature: Feature.duplicateDetection,
          subscriptionIds: items.map((s) => s.id).toList(growable: false),
          actionLabel: 'Comparar serviços',
        ),
      );
    });

    return result;
  }

  // --- Regra 4: aumentos de preço ---

  /// Reajuste silencioso é a forma mais comum de perder dinheiro em assinatura:
  /// sobe R$ 5, ninguém percebe, e em três anos o serviço custa o dobro.
  List<Insight> _priceIncreases(List<SubscriptionModel> subs) {
    final increased = subs.where((s) {
      final percent = s.priceIncreasePercent;
      return percent != null && percent >= _priceIncreaseThresholdPercent;
    }).toList(growable: false);

    if (increased.isEmpty) return const <Insight>[];

    final extraPerYear = increased.fold<double>(
      0,
      (sum, s) =>
          sum +
          FinancialCalculator.annualEquivalent(price: s.price, cycle: s.cycle) -
          FinancialCalculator.annualEquivalent(price: s.originalPrice, cycle: s.cycle),
    );

    return <Insight>[
      Insight(
        id: 'price_increase',
        kind: InsightKind.priceIncrease,
        severity: InsightSeverity.warning,
        title: 'Reajuste detectado em ${increased.length} '
            '${increased.length == 1 ? 'assinatura' : 'assinaturas'}',
        description: '${_nameList(increased)} '
            '${increased.length == 1 ? 'ficou' : 'ficaram'} mais caro'
            '${increased.length == 1 ? '' : 's'} desde o cadastro. '
            'A diferença soma ${CurrencyFormatter.format(extraPerYear)} a mais por ano.',
        requiredFeature: Feature.priceHistory,
        subscriptionIds: increased.map((s) => s.id).toList(growable: false),
        actionLabel: 'Ver histórico',
      ),
    ];
  }

  // --- Regra 5: custo por uso fora da curva ---

  /// Preço absoluto engana: R$ 120/mês numa academia usada cinco vezes por semana é
  /// barato; R$ 40 num streaming visto uma vez por mês é caro. O custo por uso
  /// corrige essa leitura.
  List<Insight> _costPerUseOutliers(List<SubscriptionModel> subs) {
    final expensive = subs.where((s) {
      final cost = s.costPerUse;
      return cost != null && cost >= _costPerUseThreshold;
    }).toList()
      ..sort((a, b) => (b.costPerUse ?? 0).compareTo(a.costPerUse ?? 0));

    if (expensive.isEmpty) return const <Insight>[];

    final worst = expensive.first;
    return <Insight>[
      Insight(
        id: 'cost_per_use',
        kind: InsightKind.costPerUse,
        severity: InsightSeverity.opportunity,
        title: '${worst.name} sai a '
            '${CurrencyFormatter.format(worst.costPerUse!)} por uso',
        description: 'Considerando o uso que você informou, cada acesso a '
            '${worst.name} custa ${CurrencyFormatter.format(worst.costPerUse!)}. '
            'Vale comparar com a compra avulsa do que você realmente consome.',
        potentialAnnualSavings: worst.annualEquivalent,
        requiredFeature: Feature.costPerUseAnalysis,
        subscriptionIds: <String>[worst.id],
        actionLabel: 'Reavaliar',
      ),
    ];
  }

  // --- Regra 6: concentração por categoria ---

  List<Insight> _concentration(List<SubscriptionModel> subs) {
    final total = subs.fold<double>(0, (sum, s) => sum + s.monthlyEquivalent);
    if (total <= 0) return const <Insight>[];

    final byCategory = <String, double>{};
    for (final sub in subs) {
      byCategory[sub.categoryId] = (byCategory[sub.categoryId] ?? 0) + sub.monthlyEquivalent;
    }

    var topId = '';
    var topSpend = 0.0;
    byCategory.forEach((id, spend) {
      if (spend > topSpend) {
        topSpend = spend;
        topId = id;
      }
    });
    if (topId.isEmpty) return const <Insight>[];

    final percent = FinancialCalculator.percentageOf(part: topSpend, total: total);
    if (percent < _concentrationThresholdPercent) return const <Insight>[];

    return <Insight>[
      Insight(
        id: 'concentration_$topId',
        kind: InsightKind.concentration,
        severity: InsightSeverity.info,
        title: '${percent.toStringAsFixed(0)}% do seu gasto está em '
            '${CategoryModel.byId(topId).name}',
        description: 'São ${CurrencyFormatter.format(topSpend)} por mês numa única '
            'categoria. Concentração alta não é problema em si, mas é onde um corte '
            'faz mais diferença.',
      ),
    ];
  }

  // --- Regra 7: mês com acúmulo de cobranças ---

  /// Vários débitos no mesmo intervalo curto estouram o limite do cartão e geram
  /// juros — um problema de fluxo de caixa, não de valor total.
  List<Insight> _billingSpike(List<SubscriptionModel> subs) {
    final today = Recurrence.dateOnly(_reference);
    final horizon = today.add(const Duration(days: 7));

    final upcoming = subs
        .where((s) {
          final date = Recurrence.dateOnly(s.nextBillingDate);
          return !date.isBefore(today) && !date.isAfter(horizon);
        })
        .toList(growable: false);

    if (upcoming.length < _billingSpikeThreshold) return const <Insight>[];

    final total = upcoming.fold<double>(0, (sum, s) => sum + s.price);
    return <Insight>[
      Insight(
        id: 'billing_spike',
        kind: InsightKind.billingSpike,
        severity: InsightSeverity.warning,
        title: '${upcoming.length} cobranças nos próximos 7 dias',
        description: 'Somam ${CurrencyFormatter.format(total)} concentrados na mesma '
            'semana. Se o limite do cartão estiver apertado, vale antecipar o '
            'pagamento de uma delas ou mudar a data de vencimento.',
        subscriptionIds: upcoming.map((s) => s.id).toList(growable: false),
      ),
    ];
  }

  // --- Regra 8: projeção de longo prazo ---

  /// "R$ 49 por mês" não assusta ninguém; "R$ 2.940 em cinco anos" assusta — e é
  /// exatamente o mesmo dinheiro. A projeção existe para dar essa dimensão.
  List<Insight> _projection(List<SubscriptionModel> subs) {
    final monthly = subs.fold<double>(0, (sum, s) => sum + s.monthlyEquivalent);
    if (monthly <= 0) return const <Insight>[];

    final fiveYears = FinancialCalculator.projectedCost(monthlySpend: monthly, years: 5);
    return <Insight>[
      Insight(
        id: 'projection_5y',
        kind: InsightKind.projection,
        severity: InsightSeverity.info,
        title: 'Em 5 anos: ${CurrencyFormatter.format(fiveYears)}',
        description: 'Mantendo o ritmo atual de ${CurrencyFormatter.format(monthly)} '
            'por mês, é quanto suas assinaturas vão custar até '
            '${_reference.year + 5}. Sem contar reajustes.',
        requiredFeature: Feature.fiveYearProjection,
      ),
    ];
  }

  // --- Auxiliares ---

  /// Lista nomes de forma legível: "A, B e C". Acima de três, resume.
  static String _nameList(List<SubscriptionModel> subs) {
    final names = subs.map((s) => s.name).toList(growable: false);
    if (names.isEmpty) return '';
    if (names.length == 1) return names.first;
    if (names.length == 2) return '${names[0]} e ${names[1]}';
    if (names.length == 3) return '${names[0]}, ${names[1]} e ${names[2]}';
    return '${names[0]}, ${names[1]} e outros ${names.length - 2}';
  }

  /// A partir de 3 serviços na mesma categoria a sobreposição deixa de ser escolha
  /// e passa a ser acúmulo. Dois streamings é comum e proposital.
  static const int _overlapThreshold = 3;

  /// Abaixo de 5% o "aumento" costuma ser arredondamento ou correção cambial.
  static const double _priceIncreaseThresholdPercent = 5;

  /// R$ 15 por uso é o ponto em que sai mais barato pagar avulso na maioria das
  /// categorias (ingresso, diária de academia, aluguel de filme).
  static const double _costPerUseThreshold = 15;

  /// Metade do orçamento numa categoria só já merece um alerta.
  static const double _concentrationThresholdPercent = 50;

  /// Quatro débitos em sete dias é o que costuma estourar limite de cartão.
  static const int _billingSpikeThreshold = 4;
}

/// Extensão de conveniência para a UI somar economias sem repetir o filtro.
extension InsightListX on List<Insight> {
  double get totalAnnualSavings =>
      where((i) => i.isActionable).fold<double>(0, (sum, i) => sum + i.potentialAnnualSavings);

  List<Insight> get actionable => where((i) => i.isActionable).toList(growable: false);
}
