class FinancialCalculator {
  FinancialCalculator._();

  /// Calcula o valor mensal equivalente com base no preço e periodicidade.
  static double calculateMonthlyEquivalent({
    required double price,
    required String billingCycle,
  }) {
    final cycle = billingCycle.toLowerCase().trim();
    switch (cycle) {
      case 'mensal':
        return price;
      case 'anual':
        return price / 12.0;
      case 'semanal':
        return (price * 52.0) / 12.0;
      case 'trimestral':
        return price / 3.0;
      case 'semestral':
        return price / 6.0;
      case 'personalizada':
      default:
        return price;
    }
  }

  /// Calcula o valor anual equivalente com base no preço e periodicidade.
  static double calculateAnnualEquivalent({
    required double price,
    required String billingCycle,
  }) {
    final monthly = calculateMonthlyEquivalent(
      price: price,
      billingCycle: billingCycle,
    );
    return monthly * 12.0;
  }
}
