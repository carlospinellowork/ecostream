import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/custom_card.dart';
import 'package:ecostream/features/categories/domain/category_model.dart';
import 'package:ecostream/features/subscriptions/domain/subscription_model.dart';
import 'package:ecostream/features/subscriptions/presentation/controllers/subscription_controller.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subState = ref.watch(subscriptionControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final activeSubs = subState.subscriptions.where((s) => s.status == SubscriptionStatus.active).toList();

    // 1. Regra Determinística: Serviços Pouco Utilizados
    final lowUsageSubs = activeSubs.where((s) => s.usageLevel == UsageLevel.low).toList();
    final potentialSavingsMonthly = lowUsageSubs.fold(0.0, (sum, s) => sum + s.monthlyEquivalent);
    final potentialSavingsAnnual = potentialSavingsMonthly * 12.0;

    // 2. Regra Determinística: Categoria Maior Gasto
    final Map<String, double> categorySpendMap = {};
    for (var sub in activeSubs) {
      categorySpendMap[sub.categoryId] = (categorySpendMap[sub.categoryId] ?? 0.0) + sub.monthlyEquivalent;
    }

    String topCategoryName = 'Nenhuma';
    double topCategorySpend = 0.0;
    double topCategoryPercent = 0.0;

    categorySpendMap.forEach((catId, spend) {
      if (spend > topCategorySpend) {
        topCategorySpend = spend;
        final cat = CategoryModel.defaultCategories.firstWhere((c) => c.id == catId, orElse: () => CategoryModel.defaultCategories.last);
        topCategoryName = cat.name;
        topCategoryPercent = subState.totalMonthlySpend > 0 ? (spend / subState.totalMonthlySpend) * 100 : 0.0;
      }
    });

    // 3. Regra Determinística: Gastos com IA
    final aiSpend = categorySpendMap['cat_ai'] ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights & Economia'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner de Oportunidades de Economia
            CustomCard(
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFFEF3C7),
              border: Border.all(color: AppColors.warning.withOpacity(0.4)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lightbulb_outlined, color: AppColors.warning, size: 28),
                      const SizedBox(width: 10),
                      Text(
                        'Oportunidade de Economia',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Você poderia economizar ${CurrencyFormatter.formatBRL(potentialSavingsMonthly)} / mês',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Economia anual estimada em ${CurrencyFormatter.formatBRL(potentialSavingsAnnual)} cancelando serviços de baixo uso.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.textSecondaryDark : const Color(0xFF78350F),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Análises Inteligentes',
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 12),

            // Card 1: Resumo Geral
            _InsightItemCard(
              icon: Icons.account_balance_wallet_outlined,
              iconColor: AppColors.primary,
              title: 'Total de Compromissos Reais',
              description: 'Seu gasto mensal recorrente atual é de ${CurrencyFormatter.formatBRL(subState.totalMonthlySpend)} em ${subState.activeCount} assinaturas ativas.',
            ),
            const SizedBox(height: 12),

            // Card 2: Maior Categoria de Gastos
            if (topCategorySpend > 0) ...[
              _InsightItemCard(
                icon: Icons.pie_chart_outline,
                iconColor: AppColors.secondary,
                title: 'Concentração de Gastos',
                description: '$topCategoryName representa ${topCategoryPercent.toStringAsFixed(0)}% das suas assinaturas (${CurrencyFormatter.formatBRL(topCategorySpend)}/mês).',
              ),
              const SizedBox(height: 12),
            ],

            // Card 3: Gastos com Ferramentas de IA
            if (aiSpend > 0) ...[
              _InsightItemCard(
                icon: Icons.psychology_outlined,
                iconColor: AppColors.catAI,
                title: 'Investimento em Inteligência Artificial',
                description: 'Você investe ${CurrencyFormatter.formatBRL(aiSpend)} por mês em ferramentas e assistentes de IA.',
              ),
              const SizedBox(height: 12),
            ],

            // Card 4: Serviços com uso Baixo
            _InsightItemCard(
              icon: Icons.warning_amber_rounded,
              iconColor: AppColors.error,
              title: '${lowUsageSubs.length} Serviços com Baixa Utilização',
              description: 'Identificamos que serviços como ${lowUsageSubs.map((e) => e.name).join(', ')} possuem baixo uso recente.',
            ),

            const SizedBox(height: 28),

            Text(
              'Recomendações de Ação',
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 12),

            ...lowUsageSubs.map((sub) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: CustomCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sub.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Gasto: ${CurrencyFormatter.formatBRL(sub.price)}/${sub.billingCycle}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Pausar/Cancelar',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

class _InsightItemCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const _InsightItemCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
