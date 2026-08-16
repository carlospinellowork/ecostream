import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/custom_card.dart';
import '../../../categories/domain/category_model.dart';
import '../../domain/subscription_model.dart';
import '../controllers/subscription_controller.dart';
import 'add_subscription_modal.dart';

class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subState = ref.watch(subscriptionControllerProvider);
    final subController = ref.read(subscriptionControllerProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filtered = subState.filteredSubscriptions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Assinaturas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary, size: 28),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const AddSubscriptionModal(),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Barra de Busca e Filtros
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                // Campo de Busca
                TextField(
                  onChanged: (val) => subController.setSearchQuery(val),
                  decoration: InputDecoration(
                    hintText: 'Pesquisar assinatura...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Abas de Filtro de Status
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Todas (${subState.subscriptions.length})',
                        isSelected: subState.statusFilter == 'all',
                        onTap: () => subController.setStatusFilter('all'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Ativas (${subState.activeCount})',
                        isSelected: subState.statusFilter == 'active',
                        onTap: () => subController.setStatusFilter('active'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Pausadas',
                        isSelected: subState.statusFilter == 'paused',
                        onTap: () => subController.setStatusFilter('paused'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Canceladas',
                        isSelected: subState.statusFilter == 'cancelled',
                        onTap: () => subController.setStatusFilter('cancelled'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Lista de Assinaturas
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_outlined,
                            size: 64,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Nenhuma assinatura encontrada',
                            style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tente alterar os termos de pesquisa ou adicione uma nova assinatura.',
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final sub = filtered[index];
                      final cat = CategoryModel.defaultCategories.firstWhere(
                        (c) => c.id == sub.categoryId,
                        orElse: () => CategoryModel.defaultCategories.last,
                      );

                      return CustomCard(
                        onTap: () {
                          _showSubscriptionOptions(context, ref, sub);
                        },
                        child: Row(
                          children: [
                            // Ícone / Logo da Assinatura
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: cat.color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(cat.icon, color: cat.color, size: 26),
                            ),
                            const SizedBox(width: 14),

                            // Informações
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        sub.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (sub.status == SubscriptionStatus.paused) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.warning.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'Pausada',
                                            style: TextStyle(fontSize: 10, color: AppColors.warning, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ] else if (sub.status == SubscriptionStatus.cancelled) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.error.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'Cancelada',
                                            style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${cat.name} • ${sub.paymentMethod}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Próxima cobrança: ${DateFormat('dd/MM').format(sub.nextBillingDate)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Valor Financeiro
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  CurrencyFormatter.formatBRL(sub.price),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '/${sub.billingCycle}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showSubscriptionOptions(BuildContext context, WidgetRef ref, SubscriptionModel sub) {
    final controller = ref.read(subscriptionControllerProvider.notifier);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
                  title: const Text('Editar Assinatura'),
                  onTap: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => AddSubscriptionModal(subscriptionToEdit: sub),
                    );
                  },
                ),
                if (sub.status == SubscriptionStatus.active)
                  ListTile(
                    leading: const Icon(Icons.pause_circle_outline, color: AppColors.warning),
                    title: const Text('Pausar Assinatura'),
                    onTap: () {
                      controller.toggleStatus(sub.id, SubscriptionStatus.paused);
                      Navigator.pop(context);
                    },
                  )
                else
                  ListTile(
                    leading: const Icon(Icons.play_circle_outline, color: AppColors.success),
                    title: const Text('Reativar Assinatura'),
                    onTap: () {
                      controller.toggleStatus(sub.id, SubscriptionStatus.active);
                      Navigator.pop(context);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.error),
                  title: const Text('Excluir Assinatura', style: TextStyle(color: AppColors.error)),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDelete(context, controller, sub.id);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, SubscriptionController controller, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Assinatura?'),
        content: const Text('Esta ação não pode ser desfeita. Deseja realmente remover este registro financeiro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              controller.deleteSubscription(id);
              Navigator.pop(context);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      side: BorderSide(
        color: isSelected
            ? AppColors.primary
            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
    );
  }
}
