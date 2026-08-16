import 'package:flutter_test/flutter_test.dart';
import 'package:ecostream/core/utils/financial_calculator.dart';

void main() {
  group('FinancialCalculator Tests', () {
    test('Calcula equivalente mensal e anual para ciclo mensal', () {
      const price = 59.90;
      final monthly = FinancialCalculator.calculateMonthlyEquivalent(
        price: price,
        billingCycle: 'mensal',
      );
      final annual = FinancialCalculator.calculateAnnualEquivalent(
        price: price,
        billingCycle: 'mensal',
      );

      expect(monthly, equals(59.90));
      expect(annual, closeTo(718.80, 0.01));
    });

    test('Calcula equivalente mensal para ciclo anual', () {
      const price = 399.90;
      final monthly = FinancialCalculator.calculateMonthlyEquivalent(
        price: price,
        billingCycle: 'anual',
      );
      final annual = FinancialCalculator.calculateAnnualEquivalent(
        price: price,
        billingCycle: 'anual',
      );

      expect(monthly, closeTo(33.325, 0.01));
      expect(annual, equals(399.90));
    });

    test('Calcula equivalente mensal para ciclo semestral', () {
      const price = 120.00;
      final monthly = FinancialCalculator.calculateMonthlyEquivalent(
        price: price,
        billingCycle: 'semestral',
      );

      expect(monthly, equals(20.00));
    });
  });
}
