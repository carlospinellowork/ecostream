import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../subscriptions/presentation/controllers/subscription_controller.dart';
import '../../domain/insight.dart';
import '../../domain/insights_engine.dart';

/// Motor de insights com o relógio injetado, para que regras sensíveis a data
/// (acúmulo de cobranças, projeção) sejam testáveis.
final insightsEngineProvider = Provider<InsightsEngine>((ref) {
  final clock = ref.watch(clockProvider);
  return InsightsEngine(now: clock());
});

/// Insights do usuário, derivados das assinaturas ativas.
///
/// É um `Provider` derivado, e não um controller com estado próprio: os insights são
/// pura função das assinaturas. Guardar uma cópia só criaria a chance de ela ficar
/// dessincronizada depois de um cancelamento.
final insightsProvider = Provider<List<Insight>>((ref) {
  final subscriptions = ref.watch(subscriptionControllerProvider).subscriptions;
  return ref.watch(insightsEngineProvider).analyze(subscriptions);
});

/// Economia anual total identificada. É o número de topo da tela de Insights e o
/// argumento central do paywall.
final potentialAnnualSavingsProvider = Provider<double>((ref) {
  return ref.watch(insightsProvider).totalAnnualSavings;
});
