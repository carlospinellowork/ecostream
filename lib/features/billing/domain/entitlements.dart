import 'plan.dart';

/// Direitos de acesso do usuário: o que ele pode fazer, agora.
///
/// Fonte única de verdade do paywall. A UI **nunca** compara `plan == Plan.pro`
/// direto; pergunta `entitlements.can(Feature.x)`. Assim, mudar a fronteira do
/// paywall ou rodar um experimento de pricing é uma alteração local
/// (CLAUDE.md §8).
class Entitlements {
  const Entitlements({
    required this.plan,
    this.trialStartedAt,
    this.expiresAt,
    this.activeOfferId,
  });

  /// Estado de quem nunca comprou nem testou.
  static const Entitlements free = Entitlements(plan: Plan.free);

  factory Entitlements.fromJson(Map<String, dynamic> json) {
    return Entitlements(
      plan: Plan.fromStorage(json['plan'] as String?),
      trialStartedAt: _parseDate(json['trialStartedAt']),
      expiresAt: _parseDate(json['expiresAt']),
      activeOfferId: json['activeOfferId'] as String?,
    );
  }

  final Plan plan;

  /// Quando o teste gratuito começou. `null` se nunca foi iniciado.
  final DateTime? trialStartedAt;

  /// Fim da vigência do Pro (compra ou trial). `null` = sem prazo.
  final DateTime? expiresAt;

  final String? activeOfferId;

  /// Se o trial já foi usado. Só se pode testar uma vez por conta.
  bool get hasUsedTrial => trialStartedAt != null;

  /// Se o Pro está valendo neste instante.
  bool isProActive({DateTime? now}) {
    if (plan != Plan.pro) return false;
    final deadline = expiresAt;
    if (deadline == null) return true;
    return (now ?? DateTime.now()).isBefore(deadline);
  }

  /// Se a vigência atual é um teste gratuito, e não uma compra.
  bool isInTrial({DateTime? now}) {
    if (!hasUsedTrial || !isProActive(now: now)) return false;
    return activeOfferId == null;
  }

  /// Dias restantes de vigência. `null` quando não há prazo.
  int? daysRemaining({DateTime? now}) {
    final deadline = expiresAt;
    if (deadline == null) return null;
    final reference = now ?? DateTime.now();
    final diff = deadline.difference(reference).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// Autorização de um recurso.
  ///
  /// Hoje o corte é binário (tudo do Pro ou nada). O `switch` exaustivo existe para
  /// que, ao criar uma `Feature` nova, o compilador force a decisão de onde ela cai —
  /// em vez de ela virar "grátis" por omissão.
  bool can(Feature feature, {DateTime? now}) {
    if (isProActive(now: now)) return true;

    return switch (feature) {
      Feature.unlimitedSubscriptions => false,
      Feature.advancedInsights => false,
      Feature.annualSwitchAdvisor => false,
      Feature.duplicateDetection => false,
      Feature.costPerUseAnalysis => false,
      Feature.fiveYearProjection => false,
      Feature.customReminders => false,
      Feature.csvExport => false,
      Feature.priceHistory => false,
    };
  }

  /// Quantas assinaturas o usuário ainda pode cadastrar.
  ///
  /// `null` significa ilimitado.
  int? remainingSubscriptionSlots(int currentCount, {DateTime? now}) {
    if (can(Feature.unlimitedSubscriptions, now: now)) return null;
    final remaining = FreePlanLimits.maxSubscriptions - currentCount;
    return remaining < 0 ? 0 : remaining;
  }

  bool canAddSubscription(int currentCount, {DateTime? now}) {
    final remaining = remainingSubscriptionSlots(currentCount, now: now);
    return remaining == null || remaining > 0;
  }

  Entitlements copyWith({
    Plan? plan,
    DateTime? trialStartedAt,
    DateTime? expiresAt,
    String? activeOfferId,
  }) {
    return Entitlements(
      plan: plan ?? this.plan,
      trialStartedAt: trialStartedAt ?? this.trialStartedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      activeOfferId: activeOfferId ?? this.activeOfferId,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'plan': plan.name,
        'trialStartedAt': trialStartedAt?.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'activeOfferId': activeOfferId,
      };

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Entitlements &&
          other.plan == plan &&
          other.trialStartedAt == trialStartedAt &&
          other.expiresAt == expiresAt &&
          other.activeOfferId == activeOfferId;

  @override
  int get hashCode => Object.hash(plan, trialStartedAt, expiresAt, activeOfferId);
}
