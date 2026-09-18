import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/financial_calculator.dart';
import '../../../../core/utils/recurrence.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/custom_card.dart';
import '../../../../core/widgets/financial_stat_card.dart';
import '../../../../core/widgets/pro_badge.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../billing/domain/plan.dart';
import '../../../billing/presentation/controllers/entitlement_controller.dart';
import '../../../categories/domain/category_model.dart';
import '../../../insights/presentation/controllers/insights_controller.dart';
import '../../../reminders/presentation/controllers/reminder_controller.dart';
import '../../../subscriptions/domain/subscription_model.dart';
import '../../../subscriptions/presentation/controllers/subscription_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final subState = ref.watch(subscriptionControllerProvider);
    final savings = ref.watch(potentialAnnualSavingsProvider);
    final isPro = ref.watch(isProProvider);
    final entitlements = ref.watch(entitlementsProvider);

    // Mantém a agenda de lembretes em sincronia com as assinaturas. O dashboard é a
    // primeira tela autenticada, então é o ponto natural para ligar o observador.
    ref.watch(reminderSyncProvider);

    final upcoming = subState.upcomingBilling();
    final remainingSlots = entitlements.remainingSubscriptionSlots(subState.activeCount);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Olá, ${user?.firstName ?? 'Usuário'}',
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
            ),
            Text(
              'Resumo das suas assinaturas',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
            ),
          ],
        ),
        actions: <Widget>[
          if (isPro)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Center(child: ProBadge(compact: true)),
            ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 28),
            tooltip: 'Nova assinatura',
            onPressed: () => context.push(AppRoutes.addSubscription),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: switch (subState.status) {
        LoadStatus.initial || LoadStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
        LoadStatus.error => AppEmptyState(
            icon: Icons.cloud_off_outlined,
            iconColor: AppColors.error,
            title: 'Não foi possível carregar',
            message: subState.errorMessage ?? 'Tente novamente em instantes.',
            actionLabel: 'Tentar de novo',
            onAction: () => ref.read(subscriptionControllerProvider.notifier).load(),
          ),
        LoadStatus.ready when subState.subscriptions.isEmpty => AppEmptyState(
            icon: Icons.subscriptions_outlined,
            title: 'Nenhuma assinatura ainda',
            message: 'Cadastre a primeira e descubra quanto suas assinaturas custam '
                'por mês e por ano.',
            actionLabel: 'Cadastrar assinatura',
            onAction: () => context.push(AppRoutes.addSubscription),
          ),
        LoadStatus.ready => RefreshIndicator(
            onRefresh: () => ref.read(subscriptionControllerProvider.notifier).load(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: <Widget>[
                _SpendBanner(
                  monthly: subState.totalMonthlySpend,
                  annual: subState.totalAnnualSpend,
                  activeCount: subState.activeCount,
                ),
                const SizedBox(height: 16),

                if (savings > 0) ...<Widget>[
                  _SavingsCallout(annualSavings: savings),
                  const SizedBox(height: 16),
                ],

                Row(
                  children: <Widget>[
                    Expanded(
                      child: FinancialStatCard(
                        title: 'Gasto mensal',
                        value: CurrencyFormatter.format(subState.totalMonthlySpend),
                        icon: Icons.calendar_month_outlined,
                        iconColor: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FinancialStatCard(
                        title: 'Em 5 anos',
                        value: CurrencyFormatter.compact(
                          FinancialCalculator.projectedCost(
                            monthlySpend: subState.totalMonthlySpend,
                            years: 5,
                          ),
                        ),
                        subtitle: 'Sem contar reajustes',
                        icon: Icons.trending_up_outlined,
                        iconColor: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                SectionHeader(
                  title: 'Próximas cobranças',
                  actionLabel: 'Ver calendário',
                  onAction: () => context.go(AppRoutes.calendar),
                ),
                const SizedBox(height: 10),
                _UpcomingList(upcoming: upcoming),
                const SizedBox(height: 24),

                const SectionHeader(title: 'Distribuição por categoria'),
                const SizedBox(height: 10),
                _CategoryBreakdown(
                  spendByCategory: subState.spendByCategory,
                  total: subState.totalMonthlySpend,
                ),

                if (remainingSlots != null) ...<Widget>[
                  const SizedBox(height: 24),
                  _PlanUsageCard(
                    used: subState.activeCount,
                    limit: FreePlanLimits.maxSubscriptions,
                  ),
                ],
              ],
            ),
          ),
      },
    );
  }
}

/// Banner principal: o número que o usuário abre o app para ver.
class _SpendBanner extends StatelessWidget {
  const _SpendBanner({
    required this.monthly,
    required this.annual,
    required this.activeCount,
  });

  final double monthly;
  final double annual;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppColors.primary, Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'VOCÊ GASTA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Colors.white70,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$activeCount ${activeCount == 1 ? 'ativa' : 'ativas'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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
              '${CurrencyFormatter.format(monthly)} / mês',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Equivale a ${CurrencyFormatter.format(annual)} por ano',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chamada para a economia identificada. Leva direto aos insights.
class _SavingsCallout extends StatelessWidget {
  const _SavingsCallout({required this.annualSavings});

  final double annualSavings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomCard(
      onTap: () => context.go(AppRoutes.insights),
      backgroundColor: AppColors.warning.withValues(alpha: 0.10),
      borderColor: AppColors.warning.withValues(alpha: 0.35),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.savings_outlined, color: AppColors.warning, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${CurrencyFormatter.format(annualSavings)} por ano',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'é o que identificamos de economia possível',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _UpcomingList extends StatelessWidget {
  const _UpcomingList({required this.upcoming});

  final List<SubscriptionModel> upcoming;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (upcoming.isEmpty) {
      return CustomCard(
        child: Row(
          children: <Widget>[
            const Icon(Icons.task_alt, size: 24, color: AppColors.success),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Nenhuma cobrança nos próximos 7 dias.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: upcoming.map((sub) {
        final category = CategoryModel.byId(sub.categoryId);
        final days = Recurrence.daysUntil(sub.nextBillingDate);
        final isUrgent = days <= 1;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: CustomCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            onTap: () => context.push(AppRoutes.editSubscriptionPath(sub.id)),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(category.icon, color: category.color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        sub.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(category.name, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      CurrencyFormatter.format(sub.price),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isUrgent ? AppColors.error : AppColors.warning)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        Recurrence.humanizeDueDate(sub.nextBillingDate),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isUrgent ? AppColors.error : AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.spendByCategory, required this.total});

  final Map<String, double> spendByCategory;
  final double total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Ordena por gasto, do maior para o menor: a categoria que mais pesa vem primeiro.
    final entries = spendByCategory.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return CustomCard(
        child: Text(
          'Cadastre assinaturas para ver a distribuição.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return CustomCard(
      child: Column(
        children: entries.map((entry) {
          final category = CategoryModel.byId(entry.key);
          final percent = FinancialCalculator.percentageOf(
            part: entry.value,
            total: total,
          );

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(category.icon, size: 18, color: category.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
                      ),
                    ),
                    Text(
                      '${CurrencyFormatter.format(entry.value)} '
                      '(${percent.toStringAsFixed(0)}%)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (percent / 100).clamp(0.0, 1.0),
                    backgroundColor: category.color.withValues(alpha: 0.15),
                    color: category.color,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

/// Uso do limite do plano gratuito.
///
/// Aparece só para quem está no gratuito. Mostra a barra enchendo, o que comunica o
/// limite antes de o usuário bater nele e ser interrompido no meio de um cadastro.
class _PlanUsageCard extends StatelessWidget {
  const _PlanUsageCard({required this.used, required this.limit});

  final int used;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = (used / limit).clamp(0.0, 1.0);
    final isFull = used >= limit;

    return CustomCard(
      onTap: () => context.push('${AppRoutes.paywall}?origem=dashboard-limite'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Plano gratuito',
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
                ),
              ),
              const ProBadge(label: 'VER PRO', compact: true),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: isFull ? AppColors.error : AppColors.primary,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFull
                ? 'Você usou todas as $limit assinaturas do plano gratuito. '
                    'O Pro libera quantidade ilimitada.'
                : '$used de $limit assinaturas usadas.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
