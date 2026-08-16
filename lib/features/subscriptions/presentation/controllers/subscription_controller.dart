import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/subscription_model.dart';

class SubscriptionState {
  final List<SubscriptionModel> subscriptions;
  final bool isLoading;
  final String searchQuery;
  final String? selectedCategoryFilter;
  final String statusFilter; // 'all', 'active', 'paused', 'cancelled'
  final String sortBy; // 'next_billing', 'price_desc', 'price_asc', 'name'

  const SubscriptionState({
    this.subscriptions = const [],
    this.isLoading = false,
    this.searchQuery = '',
    this.selectedCategoryFilter,
    this.statusFilter = 'all',
    this.sortBy = 'next_billing',
  });

  SubscriptionState copyWith({
    List<SubscriptionModel>? subscriptions,
    bool? isLoading,
    String? searchQuery,
    String? selectedCategoryFilter,
    String? statusFilter,
    String? sortBy,
  }) {
    return SubscriptionState(
      subscriptions: subscriptions ?? this.subscriptions,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategoryFilter: selectedCategoryFilter,
      statusFilter: statusFilter ?? this.statusFilter,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  /// Lista filtrada e ordenada com base nos critérios atuais
  List<SubscriptionModel> get filteredSubscriptions {
    var result = subscriptions.where((sub) {
      // Filtro de busca por nome
      if (searchQuery.isNotEmpty &&
          !sub.name.toLowerCase().contains(searchQuery.toLowerCase())) {
        return false;
      }
      // Filtro por categoria
      if (selectedCategoryFilter != null &&
          sub.categoryId != selectedCategoryFilter) {
        return false;
      }
      // Filtro por status
      if (statusFilter == 'active' && sub.status != SubscriptionStatus.active) {
        return false;
      }
      if (statusFilter == 'paused' && sub.status != SubscriptionStatus.paused) {
        return false;
      }
      if (statusFilter == 'cancelled' &&
          sub.status != SubscriptionStatus.cancelled) {
        return false;
      }
      return true;
    }).toList();

    // Ordenação
    switch (sortBy) {
      case 'price_desc':
        result.sort(
          (a, b) => b.monthlyEquivalent.compareTo(a.monthlyEquivalent),
        );
        break;
      case 'price_asc':
        result.sort(
          (a, b) => a.monthlyEquivalent.compareTo(b.monthlyEquivalent),
        );
        break;
      case 'name':
        result.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'next_billing':
      default:
        result.sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));
        break;
    }

    return result;
  }

  /// Totais consolidados
  double get totalMonthlySpend {
    return subscriptions
        .where((sub) => sub.status == SubscriptionStatus.active)
        .fold(0.0, (sum, sub) => sum + sub.monthlyEquivalent);
  }

  double get totalAnnualSpend {
    return totalMonthlySpend * 12.0;
  }

  int get activeCount {
    return subscriptions
        .where((sub) => sub.status == SubscriptionStatus.active)
        .length;
  }

  List<SubscriptionModel> get upcomingBillingIn7Days {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final limit = today.add(const Duration(days: 7));

    return subscriptions
        .where((sub) => sub.status == SubscriptionStatus.active)
        .where(
          (sub) =>
              sub.nextBillingDate.isAfter(
                today.subtract(const Duration(days: 1)),
              ) &&
              sub.nextBillingDate.isBefore(limit.add(const Duration(days: 1))),
        )
        .toList()
      ..sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));
  }
}

class SubscriptionController extends StateNotifier<SubscriptionState> {
  SubscriptionController() : super(const SubscriptionState()) {
    _loadInitialSubscriptions();
  }

  void _loadInitialSubscriptions() {
    final now = DateTime.now();
    final demoSubscriptions = [
      SubscriptionModel(
        id: 'sub_1',
        userId: 'usr_demo_1',
        name: 'Netflix',
        categoryId: 'cat_streaming',
        price: 59.90,
        billingCycle: 'mensal',
        billingDay: 18,
        nextBillingDate: DateTime(now.year, now.month, now.day + 1),
        status: SubscriptionStatus.active,
        paymentMethod: 'Cartão de Crédito',
        notes: 'Plano Premium 4K',
        usageLevel: UsageLevel.high,
        createdAt: DateTime(2025, 1, 15),
      ),
      SubscriptionModel(
        id: 'sub_2',
        userId: 'usr_demo_1',
        name: 'Spotify',
        categoryId: 'cat_streaming',
        price: 21.90,
        billingCycle: 'mensal',
        billingDay: 20,
        nextBillingDate: DateTime(now.year, now.month, now.day + 3),
        status: SubscriptionStatus.active,
        paymentMethod: 'Cartão de Crédito',
        notes: 'Plano Individual',
        usageLevel: UsageLevel.high,
        createdAt: DateTime(2024, 6, 10),
      ),
      SubscriptionModel(
        id: 'sub_3',
        userId: 'usr_demo_1',
        name: 'Game Pass Ultimate',
        categoryId: 'cat_games',
        price: 119.90,
        billingCycle: 'mensal',
        billingDay: 23,
        nextBillingDate: DateTime(now.year, now.month, now.day + 6),
        status: SubscriptionStatus.active,
        paymentMethod: 'Pix',
        usageLevel: UsageLevel.medium,
        createdAt: DateTime(2025, 3, 1),
      ),
      SubscriptionModel(
        id: 'sub_4',
        userId: 'usr_demo_1',
        name: 'ChatGPT Plus',
        categoryId: 'cat_ai',
        price: 97.70,
        billingCycle: 'mensal',
        billingDay: 25,
        nextBillingDate: DateTime(now.year, now.month, now.day + 8),
        status: SubscriptionStatus.active,
        paymentMethod: 'Cartão de Crédito',
        usageLevel: UsageLevel.high,
        createdAt: DateTime(2025, 2, 20),
      ),
      SubscriptionModel(
        id: 'sub_5',
        userId: 'usr_demo_1',
        name: 'Disney+',
        categoryId: 'cat_streaming',
        price: 43.90,
        billingCycle: 'mensal',
        billingDay: 28,
        nextBillingDate: DateTime(now.year, now.month, now.day + 11),
        status: SubscriptionStatus.active,
        paymentMethod: 'Cartão de Crédito',
        usageLevel: UsageLevel.low, // Pouco utilizado para economia
        createdAt: DateTime(2024, 11, 5),
      ),
      SubscriptionModel(
        id: 'sub_6',
        userId: 'usr_demo_1',
        name: 'iCloud 200GB',
        categoryId: 'cat_cloud',
        price: 39.90,
        billingCycle: 'mensal',
        billingDay: 5,
        nextBillingDate: DateTime(now.year, now.month + 1, 5),
        status: SubscriptionStatus.active,
        paymentMethod: 'Cartão de Crédito',
        usageLevel: UsageLevel.high,
        createdAt: DateTime(2023, 8, 12),
      ),

      // 6 Assinaturas adicionais para somar as 12 ativas
      SubscriptionModel(
        id: 'sub_7',
        userId: 'usr_demo_1',
        name: 'Prime Video',
        categoryId: 'cat_streaming',
        price: 19.90,
        billingCycle: 'mensal',
        billingDay: 12,
        nextBillingDate: DateTime(now.year, now.month + 1, 12),
        status: SubscriptionStatus.active,
        paymentMethod: 'Cartão de Crédito',
        usageLevel: UsageLevel.medium,
        createdAt: DateTime(2024, 2, 10),
      ),
      SubscriptionModel(
        id: 'sub_8',
        userId: 'usr_demo_1',
        name: 'Canva Pro',
        categoryId: 'cat_software',
        price: 34.90,
        billingCycle: 'mensal',
        billingDay: 14,
        nextBillingDate: DateTime(now.year, now.month + 1, 14),
        status: SubscriptionStatus.active,
        paymentMethod: 'Cartão de Crédito',
        usageLevel: UsageLevel.low, // Pouco utilizado
        createdAt: DateTime(2024, 9, 1),
      ),
      SubscriptionModel(
        id: 'sub_9',
        userId: 'usr_demo_1',
        name: 'PlayStation Plus',
        categoryId: 'cat_games',
        price: 40.00, // R$ 480 anual = R$ 40/mês
        billingCycle: 'anual',
        billingDay: 15,
        nextBillingDate: DateTime(now.year + 1, 2, 15),
        status: SubscriptionStatus.active,
        paymentMethod: 'Cartão de Crédito',
        usageLevel: UsageLevel.medium,
        createdAt: DateTime(2025, 2, 15),
      ),
      SubscriptionModel(
        id: 'sub_10',
        userId: 'usr_demo_1',
        name: 'Jornal O Globo',
        categoryId: 'cat_jornais',
        price: 30.90,
        billingCycle: 'mensal',
        billingDay: 10,
        nextBillingDate: DateTime(now.year, now.month + 1, 10),
        status: SubscriptionStatus.active,
        paymentMethod: 'Débito Automático',
        usageLevel: UsageLevel.low, // Pouco utilizado
        createdAt: DateTime(2024, 5, 20),
      ),
      SubscriptionModel(
        id: 'sub_11',
        userId: 'usr_demo_1',
        name: 'GitHub Pro',
        categoryId: 'cat_software',
        price: 24.00,
        billingCycle: 'mensal',
        billingDay: 8,
        nextBillingDate: DateTime(now.year, now.month + 1, 8),
        status: SubscriptionStatus.active,
        paymentMethod: 'Cartão de Crédito',
        usageLevel: UsageLevel.high,
        createdAt: DateTime(2024, 1, 1),
      ),
      SubscriptionModel(
        id: 'sub_12',
        userId: 'usr_demo_1',
        name: 'Smart Fit Academia',
        categoryId: 'cat_academias',
        price: 119.90,
        billingCycle: 'mensal',
        billingDay: 1,
        nextBillingDate: DateTime(now.year, now.month + 1, 1),
        status: SubscriptionStatus.active,
        paymentMethod: 'Cartão de Crédito',
        usageLevel: UsageLevel.high,
        createdAt: DateTime(2025, 1, 5),
      ),
    ];

    state = state.copyWith(subscriptions: demoSubscriptions);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setCategoryFilter(String? categoryId) {
    state = state.copyWith(selectedCategoryFilter: categoryId);
  }

  void setStatusFilter(String status) {
    state = state.copyWith(statusFilter: status);
  }

  void setSortBy(String sort) {
    state = state.copyWith(sortBy: sort);
  }

  void addSubscription(SubscriptionModel subscription) {
    final updated = [...state.subscriptions, subscription];
    state = state.copyWith(subscriptions: updated);
  }

  void updateSubscription(SubscriptionModel updatedSubscription) {
    final updated =
        state.subscriptions.map((s) {
          return s.id == updatedSubscription.id ? updatedSubscription : s;
        }).toList();
    state = state.copyWith(subscriptions: updated);
  }

  void toggleStatus(String id, SubscriptionStatus newStatus) {
    final updated =
        state.subscriptions.map((s) {
          if (s.id == id) {
            return s.copyWith(status: newStatus);
          }
          return s;
        }).toList();
    state = state.copyWith(subscriptions: updated);
  }

  void deleteSubscription(String id) {
    final updated = state.subscriptions.where((s) => s.id != id).toList();
    state = state.copyWith(subscriptions: updated);
  }
}

final subscriptionControllerProvider =
    StateNotifierProvider<SubscriptionController, SubscriptionState>((ref) {
      return SubscriptionController();
    });
