import '../../billing/domain/plan.dart';

/// Categoria do insight. Determina ícone, cor e ordenação na tela.
enum InsightKind {
  /// Dinheiro parado: serviço pago e não usado.
  wastedSpend,

  /// Economia disponível trocando o ciclo de cobrança.
  annualSwitch,

  /// Serviços sobrepostos na mesma categoria.
  overlap,

  /// Preço subiu desde o cadastro.
  priceIncrease,

  /// Concentração de gasto em uma categoria.
  concentration,

  /// Custo por uso fora da curva.
  costPerUse,

  /// Projeção de longo prazo.
  projection,

  /// Mês com acúmulo de cobranças.
  billingSpike,

  /// Resumo informativo, sem ação.
  summary,
}

/// Urgência, usada para ordenar a lista.
enum InsightSeverity { info, opportunity, warning, critical }

/// Uma conclusão acionável sobre os gastos do usuário.
///
/// Objeto puro, sem Flutter: é produzido pelo [InsightsEngine] e consumido pela UI.
/// Isso permite testar toda a regra de negócio sem montar widget.
class Insight {
  const Insight({
    required this.id,
    required this.kind,
    required this.severity,
    required this.title,
    required this.description,
    this.potentialAnnualSavings = 0,
    this.requiredFeature,
    this.subscriptionIds = const <String>[],
    this.actionLabel,
  });

  /// Identificador estável, para o usuário poder dispensar o insight sem que ele
  /// volte na próxima abertura.
  final String id;

  final InsightKind kind;
  final InsightSeverity severity;
  final String title;
  final String description;

  /// Quanto o usuário economiza por ano se agir. Zero quando é apenas informativo.
  final double potentialAnnualSavings;

  /// Recurso exigido para ver o conteúdo. `null` = disponível no plano gratuito.
  ///
  /// Insights bloqueados não são omitidos: aparecem com o **valor em reais visível**
  /// e o detalhe borrado. Esconder por completo perde a chance de conversão;
  /// mostrar "R$ 412/ano em economia identificada" é o argumento (CLAUDE.md §8).
  final Feature? requiredFeature;

  /// Assinaturas envolvidas, para a tela oferecer a ação direta.
  final List<String> subscriptionIds;

  /// Rótulo do botão de ação, quando houver.
  final String? actionLabel;

  bool get isActionable => potentialAnnualSavings > 0;

  bool get isLocked => requiredFeature != null;
}
