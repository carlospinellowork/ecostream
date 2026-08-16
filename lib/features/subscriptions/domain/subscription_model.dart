import '../../../core/utils/financial_calculator.dart';

enum SubscriptionStatus { active, paused, cancelled }

enum UsageLevel { low, medium, high }

class SubscriptionModel {
  final String id;
  final String userId;
  final String name;
  final String categoryId;
  final String? logoUrl;
  final double price;
  final String currency;
  final String billingCycle;
  final int billingDay;
  final DateTime nextBillingDate;
  final SubscriptionStatus status;
  final String paymentMethod;
  final String? notes;
  final UsageLevel usageLevel;
  final DateTime createdAt;

  const SubscriptionModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.categoryId,
    this.logoUrl,
    required this.price,
    this.currency = 'BRL',
    required this.billingCycle,
    required this.billingDay,
    required this.nextBillingDate,
    this.status = SubscriptionStatus.active,
    required this.paymentMethod,
    this.notes,
    this.usageLevel = UsageLevel.medium,
    required this.createdAt,
  });

  /// Valor mensal equivalente calculado pela camada de domínio.
  double get monthlyEquivalent {
    return FinancialCalculator.calculateMonthlyEquivalent(
      price: price,
      billingCycle: billingCycle,
    );
  }

  /// Valor anual equivalente calculado pela camada de domínio.
  double get annualEquivalent {
    return FinancialCalculator.calculateAnnualEquivalent(
      price: price,
      billingCycle: billingCycle,
    );
  }

  SubscriptionModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? categoryId,
    String? logoUrl,
    double? price,
    String? currency,
    String? billingCycle,
    int? billingDay,
    DateTime? nextBillingDate,
    SubscriptionStatus? status,
    String? paymentMethod,
    String? notes,
    UsageLevel? usageLevel,
    DateTime? createdAt,
  }) {
    return SubscriptionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      logoUrl: logoUrl ?? this.logoUrl,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      billingCycle: billingCycle ?? this.billingCycle,
      billingDay: billingDay ?? this.billingDay,
      nextBillingDate: nextBillingDate ?? this.nextBillingDate,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      usageLevel: usageLevel ?? this.usageLevel,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
