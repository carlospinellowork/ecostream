import '../domain/billing_cycle.dart';

/// Conversões entre periodicidades de cobrança.
///
/// Ponto único de verdade: nenhuma tela recalcula equivalência por conta própria.
/// Ver CLAUDE.md §6.
class FinancialCalculator {
  FinancialCalculator._();

  /// Valor mensal equivalente de uma cobrança de [price] a cada ciclo [cycle].
  ///
  /// Base do cálculo: `price * occurrencesPerYear / 12`. Para semanal isso dá
  /// `price * 52 / 12`, e não `price * 4` — a diferença é de quase um mês de gasto
  /// por ano, o que distorceria todo o painel do usuário.
  static double monthlyEquivalent({
    required double price,
    required BillingCycle cycle,
  }) {
    return price * cycle.occurrencesPerYear / 12.0;
  }

  /// Valor anual equivalente de uma cobrança de [price] a cada ciclo [cycle].
  static double annualEquivalent({
    required double price,
    required BillingCycle cycle,
  }) {
    return price * cycle.occurrencesPerYear;
  }

  /// Quanto se economiza por ano ao migrar de [currentCycle] para [targetCycle],
  /// dado o preço atual [price] e o preço do plano alvo [targetPrice].
  ///
  /// Resultado positivo significa economia. É a base do insight de migração anual,
  /// que costuma ser o maior ganho isolado do usuário (10% a 20% ao ano).
  static double annualSavingsBySwitchingCycle({
    required double price,
    required BillingCycle currentCycle,
    required double targetPrice,
    required BillingCycle targetCycle,
  }) {
    final current = annualEquivalent(price: price, cycle: currentCycle);
    final target = annualEquivalent(price: targetPrice, cycle: targetCycle);
    return current - target;
  }

  /// Projeção de custo acumulado em [years] anos, sem correção de inflação.
  ///
  /// Serve para dar dimensão ao gasto recorrente: "R$ 49/mês" não assusta,
  /// "R$ 2.940 em 5 anos" assusta — e é o mesmo número.
  static double projectedCost({
    required double monthlySpend,
    required int years,
  }) {
    assert(years > 0, 'A projeção exige um horizonte de pelo menos 1 ano.');
    return monthlySpend * 12.0 * years;
  }

  /// Custo por uso estimado no mês, dado um número de usos.
  ///
  /// Devolve `null` quando não há uso registrado — dividir por zero aqui produziria
  /// `Infinity` e vazaria para a UI como "R$ Infinity".
  static double? costPerUse({
    required double monthlyPrice,
    required int usesPerMonth,
  }) {
    if (usesPerMonth <= 0) return null;
    return monthlyPrice / usesPerMonth;
  }

  /// Percentual que [part] representa de [total], protegido contra total zero.
  static double percentageOf({required double part, required double total}) {
    if (total <= 0) return 0;
    return (part / total) * 100.0;
  }
}
