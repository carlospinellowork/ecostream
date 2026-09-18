import '../../../core/domain/billing_cycle.dart';
import '../../../core/utils/financial_calculator.dart';
import '../../../core/utils/recurrence.dart';

enum SubscriptionStatus {
  active('Ativa'),
  paused('Pausada'),
  cancelled('Cancelada');

  const SubscriptionStatus(this.label);

  final String label;

  static SubscriptionStatus fromStorage(String? raw) {
    for (final status in SubscriptionStatus.values) {
      if (status.name == raw) return status;
    }
    return SubscriptionStatus.active;
  }
}

/// Uso percebido do serviço, informado pelo usuário.
///
/// É autodeclarado de propósito: medir uso real exigiria integração com cada
/// serviço, o que não existe. O usuário sabe se assiste Disney+ toda semana ou
/// nunca, e essa resposta já é suficiente para o insight de corte.
enum UsageLevel {
  never('Não uso mais', 0),
  low('Raramente', 1),
  medium('Às vezes', 4),
  high('Quase todo dia', 20);

  const UsageLevel(this.label, this.estimatedUsesPerMonth);

  final String label;

  /// Estimativa de usos por mês, base do cálculo de custo por uso.
  final int estimatedUsesPerMonth;

  static UsageLevel fromStorage(String? raw) {
    for (final level in UsageLevel.values) {
      if (level.name == raw) return level;
    }
    return UsageLevel.medium;
  }
}

/// Registro de mudança de preço, para detectar aumentos silenciosos.
class PricePoint {
  const PricePoint({required this.price, required this.changedAt});

  factory PricePoint.fromJson(Map<String, dynamic> json) => PricePoint(
        price: (json['price'] as num).toDouble(),
        changedAt: DateTime.parse(json['changedAt'] as String),
      );

  final double price;
  final DateTime changedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'price': price,
        'changedAt': changedAt.toIso8601String(),
      };
}

/// Uma assinatura recorrente do usuário.
class SubscriptionModel {
  const SubscriptionModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.categoryId,
    required this.price,
    required this.cycle,
    required this.billingDay,
    required this.nextBillingDate,
    required this.paymentMethod,
    required this.createdAt,
    this.logoUrl,
    this.currency = 'BRL',
    this.status = SubscriptionStatus.active,
    this.notes,
    this.usageLevel = UsageLevel.medium,
    this.priceHistory = const <PricePoint>[],
    this.annualPlanPrice,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    final rawHistory = json['priceHistory'];
    return SubscriptionModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      categoryId: json['categoryId'] as String,
      logoUrl: json['logoUrl'] as String?,
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'BRL',
      // Aceita o formato antigo, em que o ciclo era uma string em português.
      cycle: BillingCycle.fromStorage(
        json['cycle'] as String? ?? json['billingCycle'] as String?,
      ),
      billingDay: json['billingDay'] as int? ?? 1,
      nextBillingDate: DateTime.parse(json['nextBillingDate'] as String),
      status: SubscriptionStatus.fromStorage(json['status'] as String?),
      paymentMethod: json['paymentMethod'] as String? ?? 'Outro',
      notes: json['notes'] as String?,
      usageLevel: UsageLevel.fromStorage(json['usageLevel'] as String?),
      createdAt: DateTime.parse(json['createdAt'] as String),
      priceHistory: rawHistory is List
          ? rawHistory
              .whereType<Map<String, dynamic>>()
              .map(PricePoint.fromJson)
              .toList(growable: false)
          : const <PricePoint>[],
      annualPlanPrice: (json['annualPlanPrice'] as num?)?.toDouble(),
    );
  }

  final String id;
  final String userId;
  final String name;
  final String categoryId;
  final String? logoUrl;
  final double price;
  final String currency;
  final BillingCycle cycle;

  /// Dia do mês contratado para a cobrança. Preservado separadamente de
  /// [nextBillingDate] porque, ao passar por fevereiro, a data efetiva é reduzida
  /// (31 → 28) e sem a âncora a assinatura ficaria presa no dia 28 para sempre.
  final int billingDay;

  final DateTime nextBillingDate;
  final SubscriptionStatus status;
  final String paymentMethod;
  final String? notes;
  final UsageLevel usageLevel;
  final DateTime createdAt;

  /// Preços anteriores, do mais antigo para o mais recente.
  final List<PricePoint> priceHistory;

  /// Preço do plano anual do mesmo serviço, quando o usuário informa.
  /// Habilita o insight de migração mensal → anual.
  final double? annualPlanPrice;

  bool get isActive => status == SubscriptionStatus.active;

  double get monthlyEquivalent =>
      FinancialCalculator.monthlyEquivalent(price: price, cycle: cycle);

  double get annualEquivalent =>
      FinancialCalculator.annualEquivalent(price: price, cycle: cycle);

  /// Custo estimado por uso no mês. `null` quando o usuário marcou que não usa —
  /// nesse caso o número relevante é o desperdício total, não o custo unitário.
  double? get costPerUse => FinancialCalculator.costPerUse(
        monthlyPrice: monthlyEquivalent,
        usesPerMonth: usageLevel.estimatedUsesPerMonth,
      );

  /// Preço da primeira vez que foi registrado, se houver histórico.
  double get originalPrice =>
      priceHistory.isEmpty ? price : priceHistory.first.price;

  /// Aumento acumulado desde o primeiro registro, em pontos percentuais.
  /// `null` quando não há histórico para comparar.
  double? get priceIncreasePercent {
    if (priceHistory.isEmpty) return null;
    final original = originalPrice;
    if (original <= 0) return null;
    return ((price - original) / original) * 100;
  }

  /// Economia anual ao migrar para o plano anual informado.
  /// `null` quando não há preço anual conhecido ou a assinatura já é anual.
  double? get annualSwitchSavings {
    final annualPrice = annualPlanPrice;
    if (annualPrice == null || cycle == BillingCycle.annual) return null;
    final savings = FinancialCalculator.annualSavingsBySwitchingCycle(
      price: price,
      currentCycle: cycle,
      targetPrice: annualPrice,
      targetCycle: BillingCycle.annual,
    );
    // Migração que não economiza não é sugestão, é ruído.
    return savings > 0 ? savings : null;
  }

  /// Recalcula [nextBillingDate] para a próxima ocorrência futura.
  ///
  /// Assinaturas cadastradas há meses ficam com a data no passado. Rolar para a
  /// frente evita o painel mostrar "atrasada há 74 dias" para algo que na verdade
  /// é cobrado normalmente todo mês.
  SubscriptionModel rolledForward({DateTime? now}) {
    final reference = now ?? DateTime.now();
    if (!Recurrence.dateOnly(nextBillingDate).isBefore(Recurrence.dateOnly(reference))) {
      return this;
    }
    return copyWith(
      nextBillingDate: Recurrence.nextOccurrence(
        lastBillingDate: nextBillingDate,
        cycle: cycle,
        reference: reference,
        anchorDay: billingDay,
      ),
    );
  }

  /// Aplica um novo preço, arquivando o anterior no histórico.
  SubscriptionModel withNewPrice(double newPrice, {DateTime? at}) {
    if (newPrice == price) return this;
    return copyWith(
      price: newPrice,
      priceHistory: <PricePoint>[
        ...priceHistory,
        PricePoint(price: price, changedAt: at ?? DateTime.now()),
      ],
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
    BillingCycle? cycle,
    int? billingDay,
    DateTime? nextBillingDate,
    SubscriptionStatus? status,
    String? paymentMethod,
    String? notes,
    UsageLevel? usageLevel,
    DateTime? createdAt,
    List<PricePoint>? priceHistory,
    double? annualPlanPrice,
  }) {
    return SubscriptionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      logoUrl: logoUrl ?? this.logoUrl,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      cycle: cycle ?? this.cycle,
      billingDay: billingDay ?? this.billingDay,
      nextBillingDate: nextBillingDate ?? this.nextBillingDate,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      usageLevel: usageLevel ?? this.usageLevel,
      createdAt: createdAt ?? this.createdAt,
      priceHistory: priceHistory ?? this.priceHistory,
      annualPlanPrice: annualPlanPrice ?? this.annualPlanPrice,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'userId': userId,
        'name': name,
        'categoryId': categoryId,
        'logoUrl': logoUrl,
        'price': price,
        'currency': currency,
        'cycle': cycle.name,
        'billingDay': billingDay,
        'nextBillingDate': nextBillingDate.toIso8601String(),
        'status': status.name,
        'paymentMethod': paymentMethod,
        'notes': notes,
        'usageLevel': usageLevel.name,
        'createdAt': createdAt.toIso8601String(),
        'priceHistory': priceHistory.map((p) => p.toJson()).toList(growable: false),
        'annualPlanPrice': annualPlanPrice,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SubscriptionModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SubscriptionModel($id, $name, $price/${cycle.name})';
}
