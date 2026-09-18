import 'package:ecostream/core/domain/billing_cycle.dart';
import 'package:ecostream/core/utils/financial_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FinancialCalculator.monthlyEquivalent', () {
    test('ciclo mensal devolve o próprio preço', () {
      expect(
        FinancialCalculator.monthlyEquivalent(
          price: 59.90,
          cycle: BillingCycle.monthly,
        ),
        closeTo(59.90, 0.001),
      );
    });

    test('ciclo anual divide por 12', () {
      expect(
        FinancialCalculator.monthlyEquivalent(
          price: 399.90,
          cycle: BillingCycle.annual,
        ),
        closeTo(33.325, 0.001),
      );
    });

    test('ciclo semestral divide por 6', () {
      expect(
        FinancialCalculator.monthlyEquivalent(
          price: 120,
          cycle: BillingCycle.semiannual,
        ),
        closeTo(20, 0.001),
      );
    });

    test('ciclo trimestral divide por 3', () {
      expect(
        FinancialCalculator.monthlyEquivalent(
          price: 90,
          cycle: BillingCycle.quarterly,
        ),
        closeTo(30, 0.001),
      );
    });

    test('converte ciclo semanal usando 52 semanas por ano, não 4 por mês', () {
      // Regressão: `preco * 4` daria 40,00 e subestimaria o gasto anual em
      // quase um mês inteiro. O correto é 10 * 52 / 12 = 43,33.
      final monthly = FinancialCalculator.monthlyEquivalent(
        price: 10,
        cycle: BillingCycle.weekly,
      );
      expect(monthly, closeTo(43.3333, 0.001));
      expect(monthly, isNot(closeTo(40, 0.01)));
    });
  });

  group('FinancialCalculator.annualEquivalent', () {
    test('mensal multiplica por 12', () {
      expect(
        FinancialCalculator.annualEquivalent(
          price: 59.90,
          cycle: BillingCycle.monthly,
        ),
        closeTo(718.80, 0.01),
      );
    });

    test('anual devolve o próprio preço', () {
      expect(
        FinancialCalculator.annualEquivalent(
          price: 399.90,
          cycle: BillingCycle.annual,
        ),
        closeTo(399.90, 0.01),
      );
    });

    test('semanal multiplica por 52', () {
      expect(
        FinancialCalculator.annualEquivalent(price: 10, cycle: BillingCycle.weekly),
        closeTo(520, 0.01),
      );
    });
  });

  group('FinancialCalculator.annualSavingsBySwitchingCycle', () {
    test('mensal para anual com desconto devolve economia positiva', () {
      // R$ 19,90/mês = R$ 238,80/ano contra R$ 179,00 no plano anual.
      final savings = FinancialCalculator.annualSavingsBySwitchingCycle(
        price: 19.90,
        currentCycle: BillingCycle.monthly,
        targetPrice: 179,
        targetCycle: BillingCycle.annual,
      );
      expect(savings, closeTo(59.80, 0.01));
    });

    test('plano anual mais caro devolve economia negativa', () {
      final savings = FinancialCalculator.annualSavingsBySwitchingCycle(
        price: 10,
        currentCycle: BillingCycle.monthly,
        targetPrice: 200,
        targetCycle: BillingCycle.annual,
      );
      expect(savings, closeTo(-80, 0.01));
    });
  });

  group('FinancialCalculator.costPerUse', () {
    test('divide o preço mensal pelo número de usos', () {
      expect(
        FinancialCalculator.costPerUse(monthlyPrice: 40, usesPerMonth: 4),
        closeTo(10, 0.001),
      );
    });

    test('devolve null quando não há uso, em vez de Infinity', () {
      // Regressão: dividir por zero produziria `Infinity` e a UI mostraria
      // "R$ Infinity" ao usuário.
      expect(
        FinancialCalculator.costPerUse(monthlyPrice: 40, usesPerMonth: 0),
        isNull,
      );
      expect(
        FinancialCalculator.costPerUse(monthlyPrice: 40, usesPerMonth: -3),
        isNull,
      );
    });
  });

  group('FinancialCalculator.percentageOf', () {
    test('calcula o percentual', () {
      expect(FinancialCalculator.percentageOf(part: 25, total: 200), closeTo(12.5, 0.001));
    });

    test('total zero devolve zero em vez de NaN', () {
      expect(FinancialCalculator.percentageOf(part: 25, total: 0), 0);
    });
  });

  group('FinancialCalculator.projectedCost', () {
    test('projeta cinco anos de gasto mensal', () {
      expect(
        FinancialCalculator.projectedCost(monthlySpend: 49, years: 5),
        closeTo(2940, 0.01),
      );
    });
  });
}
