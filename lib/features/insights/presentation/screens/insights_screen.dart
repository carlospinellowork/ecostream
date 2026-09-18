import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/custom_card.dart';
import '../../../../core/widgets/pro_badge.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../billing/presentation/controllers/entitlement_controller.dart';
import '../../../subscriptions/presentation/controllers/subscription_controller.dart';
import '../../domain/insight.dart';
import '../controllers/insights_controller.dart';

/// Tela de insights e economia.
///
/// Todos os insights aparecem, inclusive os do Pro — estes com o detalhe borrado e o
/// **valor em reais visível**. Esconder a conclusão inteira tira o motivo de assinar
/// (CLAUDE.md §8).
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  Future<void> _applyCancellation(
    BuildContext context,
    WidgetRef ref,
    Insight insight,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Marcar como cancelada?'),
        content: Text(
          insight.subscriptionIds.length == 1
              ? 'A assinatura será marcada como cancelada no EcoStream. '
                  'Lembre-se de cancelar também no site do serviço.'
              : '${insight.subscriptionIds.length} assinaturas serão marcadas como '
                  'canceladas no EcoStream. Lembre-se de cancelar também nos sites '
                  'dos serviços.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Marcar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final error = await ref
        .read(subscriptionControllerProvider.notifier)
        .cancelMany(insight.subscriptionIds);

    if (!context.mounted) return;
    if (error != null) {
      AppSnackBar.showError(context, error.message);
      return;
    }
    AppSnackBar.showSuccess(context, 'Pronto. Seu gasto mensal foi recalculado.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final insights = ref.watch(insightsProvider);
    final savings = ref.watch(potentialAnnualSavingsProvider);
    final entitlements = ref.watch(entitlementsProvider);
    final subState = ref.watch(subscriptionControllerProvider);

    if (subState.status == LoadStatus.loading || subState.status == LoadStatus.initial) {
      return Scaffold(
        appBar: AppBar(title: const Text('Insights & Economia')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (insights.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Insights & Economia')),
        body: AppEmptyState(
          icon: Icons.lightbulb_outline,
          title: 'Nada a analisar ainda',
          message: 'Cadastre suas assinaturas e informe com que frequência usa cada '
              'uma. A partir daí apontamos onde está sobrando dinheiro.',
          actionLabel: 'Cadastrar assinatura',
          onAction: () => context.push(AppRoutes.addSubscription),
        ),
      );
    }

    final lockedSavings = insights
        .where((i) => i.isLocked && i.isActionable)
        .fold<double>(0, (sum, i) => sum + i.potentialAnnualSavings);

    return Scaffold(
      appBar: AppBar(title: const Text('Insights & Economia')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: <Widget>[
          _SavingsHeadline(annualSavings: savings),

          if (lockedSavings > 0) ...<Widget>[
            const SizedBox(height: 14),
            _UnlockPrompt(lockedSavings: lockedSavings),
          ],

          const SizedBox(height: 24),
          const SectionHeader(title: 'O que encontramos'),
          const SizedBox(height: 12),

          ...insights.map((insight) {
            final unlocked = insight.requiredFeature == null ||
                entitlements.can(insight.requiredFeature!);

            final card = _InsightCard(
              insight: insight,
              onAction: insight.kind == InsightKind.wastedSpend && unlocked
                  ? () => _applyCancellation(context, ref, insight)
                  : null,
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: unlocked
                  ? card
                  : ProLockedOverlay(
                      headline: insight.isActionable
                          ? '${CurrencyFormatter.format(insight.potentialAnnualSavings)} '
                              'por ano'
                          : null,
                      onUnlock: () =>
                          context.push('${AppRoutes.paywall}?origem=insight-${insight.id}'),
                      child: card,
                    ),
            );
          }),

          const SizedBox(height: 8),
          Text(
            'As sugestões usam o nível de uso que você informou em cada assinatura. '
            'Mantenha-o atualizado para recomendações mais precisas.',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SavingsHeadline extends StatelessWidget {
  const _SavingsHeadline({required this.annualSavings});

  final double annualSavings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSavings = annualSavings > 0;

    return CustomCard(
      elevated: true,
      backgroundColor: hasSavings
          ? AppColors.warning.withValues(alpha: 0.10)
          : AppColors.success.withValues(alpha: 0.10),
      borderColor: (hasSavings ? AppColors.warning : AppColors.success)
          .withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                hasSavings ? Icons.savings_outlined : Icons.verified_outlined,
                color: hasSavings ? AppColors.warning : AppColors.success,
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasSavings ? 'Economia disponível' : 'Carteira enxuta',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              hasSavings
                  ? '${CurrencyFormatter.format(annualSavings)} por ano'
                  : 'Nada a cortar por aqui',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
                color: hasSavings ? AppColors.warning : AppColors.success,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasSavings
                ? 'Somando tudo que identificamos de gasto evitável nas suas '
                    'assinaturas ativas.'
                : 'Não encontramos desperdício óbvio nas suas assinaturas ativas. '
                    'Continue registrando o uso para novas análises.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _UnlockPrompt extends StatelessWidget {
  const _UnlockPrompt({required this.lockedSavings});

  final double lockedSavings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomCard(
      onTap: () => context.push('${AppRoutes.paywall}?origem=insights-bloqueados'),
      backgroundColor: AppColors.pro.withValues(alpha: 0.08),
      borderColor: AppColors.pro.withValues(alpha: 0.3),
      child: Row(
        children: <Widget>[
          const Icon(Icons.lock_outline, color: AppColors.pro, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${CurrencyFormatter.format(lockedSavings)} por ano em análises '
                  'bloqueadas',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text('Toque para ver o que o Pro mostra', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.pro),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight, this.onAction});

  final Insight insight;
  final VoidCallback? onAction;

  /// Ícone e cor por tipo de insight, para leitura rápida na lista.
  (IconData, Color) get _visual => switch (insight.kind) {
        InsightKind.wastedSpend => (Icons.money_off_outlined, AppColors.error),
        InsightKind.annualSwitch => (Icons.swap_horiz_rounded, AppColors.success),
        InsightKind.overlap => (Icons.content_copy_outlined, AppColors.secondary),
        InsightKind.priceIncrease => (Icons.trending_up_rounded, AppColors.warning),
        InsightKind.concentration => (Icons.pie_chart_outline, AppColors.info),
        InsightKind.costPerUse => (Icons.calculate_outlined, AppColors.catAI),
        InsightKind.projection => (Icons.timeline_outlined, AppColors.secondary),
        InsightKind.billingSpike => (Icons.event_busy_outlined, AppColors.warning),
        InsightKind.summary => (Icons.info_outline, AppColors.info),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = _visual;

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            insight.title,
                            style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
                          ),
                        ),
                        if (insight.isLocked) ...<Widget>[
                          const SizedBox(width: 8),
                          const ProBadge(compact: true),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(insight.description, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          if (insight.isActionable) ...<Widget>[
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${CurrencyFormatter.format(insight.potentialAnnualSavings)}/ano',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                    ),
                  ),
                ),
                const Spacer(),
                if (onAction != null && insight.actionLabel != null)
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(insight.actionLabel!),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
