import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/custom_card.dart';
import '../../../../core/widgets/financial_stat_card.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../categories/domain/category_model.dart';
import '../../../subscriptions/domain/subscription_model.dart';
import '../../../subscriptions/presentation/controllers/subscription_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final subState = ref.watch(subscriptionControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final upcoming = subState.upcomingBillingIn7Days;
    final userName = authState.user?.name ?? 'Usuário';

    // Agrupamento por Categoria para o Gráfico/Lista de Distribuição
    final Map<String, double> categorySpendMap = {};
    for (var sub in subState.subscriptions) {
      if (sub.status == SubscriptionStatus.active) {
        categorySpendMap[sub.categoryId] = (categorySpendMap[sub.categoryId] ?? 0.0) + sub.monthlyEquivalent;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Olá, $userName 👋',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            Text(
              'Resumo das suas assinaturas',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 28),
            tooltip: 'Nova Assinatura',
            onPressed: () => context.push('/add-subscription'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner Principal: Destaque Gasto Mensal e Anual
              CustomCard(
                backgroundColor: isDark ? AppColors.cardDark : AppColors.primary,
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.primary),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'VOCÊ GASTA',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: isDark ? AppColors.textSecondaryDark : Colors.white70,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, size: 14, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  '${subState.activeCount} ativas',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${CurrencyFormatter.formatBRL(subState.totalMonthlySpend)} / mês',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Equivalente a ${CurrencyFormatter.formatBRL(subState.totalAnnualSpend)} / ano',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.primaryDark : Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Métricas em Grid
              Row(
                children: [
                  Expanded(
                    child: FinancialStatCard(
                      title: 'Gasto Mensal',
                      value: CurrencyFormatter.formatBRL(subState.totalMonthlySpend),
                      icon: Icons.calendar_month_outlined,
                      iconColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FinancialStatCard(
                      title: 'Gasto Anual',
                      value: CurrencyFormatter.formatBRL(subState.totalAnnualSpend),
                      icon: Icons.trending_up_outlined,
                      iconColor: AppColors.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Próximas Cobranças (Próximos 7 Dias)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Próximas Cobranças',
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
                  ),
                  TextButton(
                    onPressed: () => context.go('/calendar'),
                    child: const Text('Ver Calendário'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (upcoming.isEmpty)
                CustomCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Icon(Icons.task_alt, size: 32, color: AppColors.success),
                          const SizedBox(height: 8),
                          Text(
                            'Nenhuma cobrança agendada para os próximos 7 dias.',
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: upcoming.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final sub = upcoming[index];
                    final now = DateTime.now();
                    final diffDays = sub.nextBillingDate.difference(DateTime(now.year, now.month, now.day)).inDays;

                    String dueText;
                    if (diffDays == 0) {
                      dueText = 'Hoje';
                    } else if (diffDays == 1) {
                      dueText = 'Amanhã';
                    } else {
                      dueText = 'Em $diffDays dias';
                    }

                    final cat = CategoryModel.defaultCategories.firstWhere(
                      (c) => c.id == sub.categoryId,
                      orElse: () => CategoryModel.defaultCategories.last,
                    );

                    return CustomCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: cat.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(cat.icon, color: cat.color, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sub.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  cat.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                CurrencyFormatter.formatBRL(sub.price),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: diffDays <= 1
                                      ? AppColors.error.withOpacity(0.15)
                                      : AppColors.warning.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  dueText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: diffDays <= 1 ? AppColors.error : AppColors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

              const SizedBox(height: 28),

              // Distribuição por Categoria
              Text(
                'Distribuição por Categoria',
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 12),

              CustomCard(
                child: Column(
                  children: CategoryModel.defaultCategories.where((cat) {
                    return (categorySpendMap[cat.id] ?? 0.0) > 0;
                  }).map((cat) {
                    final spend = categorySpendMap[cat.id] ?? 0.0;
                    final total = subState.totalMonthlySpend;
                    final percentage = total > 0 ? (spend / total) * 100 : 0.0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(cat.icon, size: 18, color: cat.color),
                                  const SizedBox(width: 8),
                                  Text(
                                    cat.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                ],
                              ),
                              Text(
                                '${CurrencyFormatter.formatBRL(spend)} (${percentage.toStringAsFixed(0)}%)',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percentage / 100,
                              backgroundColor: cat.color.withOpacity(0.15),
                              color: cat.color,
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
