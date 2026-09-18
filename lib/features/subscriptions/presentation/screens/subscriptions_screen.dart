import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/recurrence.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/custom_card.dart';
import '../../../categories/domain/category_model.dart';
import '../../domain/subscription_model.dart';
import '../controllers/subscription_controller.dart';

class SubscriptionsScreen extends ConsumerStatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  ConsumerState<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends ConsumerState<SubscriptionsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(SubscriptionModel sub) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Excluir ${sub.name}?'),
        content: const Text(
          'A assinatura e o histórico de preços dela serão apagados deste aparelho. '
          'Isso não cancela o serviço junto do fornecedor.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final error =
        await ref.read(subscriptionControllerProvider.notifier).deleteSubscription(sub.id);
    if (!mounted) return;

    if (error != null) {
      AppSnackBar.showError(context, error.message);
      return;
    }
    AppSnackBar.showSuccess(context, '${sub.name} foi excluída.');
  }

  Future<void> _toggleStatus(SubscriptionModel sub) async {
    final next = sub.status == SubscriptionStatus.active
        ? SubscriptionStatus.paused
        : SubscriptionStatus.active;

    final error =
        await ref.read(subscriptionControllerProvider.notifier).setStatus(sub.id, next);
    if (!mounted) return;

    if (error != null) {
      AppSnackBar.showError(context, error.message);
      return;
    }
    AppSnackBar.showSuccess(
      context,
      next == SubscriptionStatus.paused
          ? '${sub.name} foi pausada e saiu do seu total mensal.'
          : '${sub.name} voltou a contar no seu total.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(subscriptionControllerProvider);
    final controller = ref.read(subscriptionControllerProvider.notifier);
    final filtered = state.filteredSubscriptions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas assinaturas'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary, size: 28),
            tooltip: 'Nova assinatura',
            onPressed: () => context.push(AppRoutes.addSubscription),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: controller.setSearchQuery,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar assinatura',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: state.searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Limpar busca',
                        onPressed: () {
                          _searchController.clear();
                          controller.setSearchQuery('');
                        },
                      ),
              ),
            ),
          ),

          _FilterBar(
            statusFilter: state.statusFilter,
            sortBy: state.sortBy,
            categoryFilter: state.categoryFilter,
            onStatusChanged: controller.setStatusFilter,
            onSortChanged: controller.setSortBy,
            onCategoryChanged: controller.setCategoryFilter,
          ),

          // Total do que está visível. Ao filtrar por "Streaming", o usuário quer
          // saber quanto gasta em streaming — não o total geral.
          if (filtered.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: <Widget>[
                  Text(
                    '${filtered.length} '
                    '${filtered.length == 1 ? 'assinatura' : 'assinaturas'}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    '${CurrencyFormatter.format(_visibleMonthlyTotal(filtered))} / mês',
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),

          Expanded(
            child: switch (state.status) {
              LoadStatus.initial || LoadStatus.loading => const Center(
                  child: CircularProgressIndicator(),
                ),
              LoadStatus.error => AppEmptyState(
                  icon: Icons.cloud_off_outlined,
                  iconColor: AppColors.error,
                  title: 'Não foi possível carregar',
                  message: state.errorMessage ?? 'Tente novamente.',
                  actionLabel: 'Tentar de novo',
                  onAction: controller.load,
                ),
              LoadStatus.ready when filtered.isEmpty && state.hasActiveFilters =>
                AppEmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  title: 'Nada encontrado',
                  message: 'Nenhuma assinatura corresponde aos filtros atuais.',
                  actionLabel: 'Limpar filtros',
                  onAction: () {
                    _searchController.clear();
                    controller.clearFilters();
                  },
                ),
              LoadStatus.ready when filtered.isEmpty => AppEmptyState(
                  icon: Icons.subscriptions_outlined,
                  title: 'Nenhuma assinatura',
                  message: 'Cadastre a primeira para começar a acompanhar seus gastos '
                      'recorrentes.',
                  actionLabel: 'Cadastrar assinatura',
                  onAction: () => context.push(AppRoutes.addSubscription),
                ),
              LoadStatus.ready => ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final sub = filtered[index];
                    return _SubscriptionTile(
                      subscription: sub,
                      onTap: () =>
                          context.push(AppRoutes.editSubscriptionPath(sub.id)),
                      onToggleStatus: () => _toggleStatus(sub),
                      onDelete: () => _confirmDelete(sub),
                    );
                  },
                ),
            },
          ),
        ],
      ),
    );
  }

  static double _visibleMonthlyTotal(List<SubscriptionModel> subs) {
    return subs
        .where((s) => s.isActive)
        .fold<double>(0, (sum, s) => sum + s.monthlyEquivalent);
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.statusFilter,
    required this.sortBy,
    required this.categoryFilter,
    required this.onStatusChanged,
    required this.onSortChanged,
    required this.onCategoryChanged,
  });

  final StatusFilter statusFilter;
  final SubscriptionSort sortBy;
  final String? categoryFilter;
  final ValueChanged<StatusFilter> onStatusChanged;
  final ValueChanged<SubscriptionSort> onSortChanged;
  final ValueChanged<String?> onCategoryChanged;

  static String _statusLabel(StatusFilter filter) => switch (filter) {
        StatusFilter.all => 'Todas',
        StatusFilter.active => 'Ativas',
        StatusFilter.paused => 'Pausadas',
        StatusFilter.cancelled => 'Canceladas',
      };

  static String _sortLabel(SubscriptionSort sort) => switch (sort) {
        SubscriptionSort.nextBilling => 'Próximo vencimento',
        SubscriptionSort.priceDesc => 'Maior valor',
        SubscriptionSort.priceAsc => 'Menor valor',
        SubscriptionSort.name => 'Nome (A–Z)',
      };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: <Widget>[
          ...StatusFilter.values.map(
            (filter) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_statusLabel(filter)),
                selected: statusFilter == filter,
                onSelected: (_) => onStatusChanged(filter),
              ),
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String?>(
            tooltip: 'Filtrar por categoria',
            onSelected: onCategoryChanged,
            itemBuilder: (context) => <PopupMenuEntry<String?>>[
              const PopupMenuItem<String?>(child: Text('Todas as categorias')),
              ...CategoryModel.defaultCategories.map(
                (category) => PopupMenuItem<String?>(
                  value: category.id,
                  child: Row(
                    children: <Widget>[
                      Icon(category.icon, size: 18, color: category.color),
                      const SizedBox(width: 10),
                      Text(category.name),
                    ],
                  ),
                ),
              ),
            ],
            child: Center(
              child: Chip(
                avatar: const Icon(Icons.category_outlined, size: 16),
                label: Text(
                  categoryFilter == null
                      ? 'Categoria'
                      : CategoryModel.byId(categoryFilter).name,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<SubscriptionSort>(
            tooltip: 'Ordenar',
            onSelected: onSortChanged,
            itemBuilder: (context) => SubscriptionSort.values
                .map(
                  (sort) => PopupMenuItem<SubscriptionSort>(
                    value: sort,
                    child: Text(_sortLabel(sort)),
                  ),
                )
                .toList(growable: false),
            child: Center(
              child: Chip(
                avatar: const Icon(Icons.sort, size: 16),
                label: Text(_sortLabel(sortBy)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionTile extends StatelessWidget {
  const _SubscriptionTile({
    required this.subscription,
    required this.onTap,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final SubscriptionModel subscription;
  final VoidCallback onTap;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = CategoryModel.byId(subscription.categoryId);
    final isActive = subscription.status == SubscriptionStatus.active;

    return CustomCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: category.color.withValues(alpha: isActive ? 0.12 : 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              category.icon,
              color: isActive
                  ? category.color
                  : category.color.withValues(alpha: 0.45),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        subscription.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 15,
                          decoration: subscription.status == SubscriptionStatus.cancelled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    if (!isActive) ...<Widget>[
                      const SizedBox(width: 8),
                      _StatusChip(status: subscription.status),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  isActive
                      ? '${category.name} • '
                          '${Recurrence.humanizeDueDate(subscription.nextBillingDate)}'
                      : '${category.name} • '
                          '${DateFormatter.short(subscription.nextBillingDate)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                CurrencyFormatter.format(subscription.price),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'por ${subscription.cycle.unitLabel}',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
            ],
          ),
          PopupMenuButton<_TileAction>(
            tooltip: 'Opções',
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (action) {
              switch (action) {
                case _TileAction.edit:
                  onTap();
                case _TileAction.toggleStatus:
                  onToggleStatus();
                case _TileAction.delete:
                  onDelete();
              }
            },
            itemBuilder: (context) => <PopupMenuEntry<_TileAction>>[
              const PopupMenuItem<_TileAction>(
                value: _TileAction.edit,
                child: Text('Editar'),
              ),
              PopupMenuItem<_TileAction>(
                value: _TileAction.toggleStatus,
                child: Text(isActive ? 'Pausar' : 'Reativar'),
              ),
              const PopupMenuItem<_TileAction>(
                value: _TileAction.delete,
                child: Text('Excluir', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _TileAction { edit, toggleStatus, delete }

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final SubscriptionStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      SubscriptionStatus.active => AppColors.success,
      SubscriptionStatus.paused => AppColors.warning,
      SubscriptionStatus.cancelled => AppColors.catOutros,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}
