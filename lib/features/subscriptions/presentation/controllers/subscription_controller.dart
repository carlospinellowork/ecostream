import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/storage/storage_keys.dart';
import '../../../../core/utils/recurrence.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../billing/domain/entitlements.dart';
import '../../../billing/domain/plan.dart';
import '../../data/demo_subscriptions.dart';
import '../../data/subscription_repository.dart';
import '../../domain/subscription_model.dart';

/// Estágio de carregamento. Ver CLAUDE.md §4.
enum LoadStatus { initial, loading, ready, error }

enum SubscriptionSort { nextBilling, priceDesc, priceAsc, name }

enum StatusFilter { all, active, paused, cancelled }

@immutable
class SubscriptionState {
  const SubscriptionState({
    this.subscriptions = const <SubscriptionModel>[],
    this.status = LoadStatus.initial,
    this.searchQuery = '',
    this.categoryFilter,
    this.statusFilter = StatusFilter.all,
    this.sortBy = SubscriptionSort.nextBilling,
    this.errorMessage,
  });

  final List<SubscriptionModel> subscriptions;
  final LoadStatus status;
  final String searchQuery;
  final String? categoryFilter;
  final StatusFilter statusFilter;
  final SubscriptionSort sortBy;
  final String? errorMessage;

  bool get isLoading => status == LoadStatus.loading;

  bool get isEmpty => status == LoadStatus.ready && subscriptions.isEmpty;

  bool get hasActiveFilters =>
      searchQuery.isNotEmpty ||
      categoryFilter != null ||
      statusFilter != StatusFilter.all;

  /// Lista filtrada e ordenada conforme os critérios atuais.
  List<SubscriptionModel> get filteredSubscriptions {
    final query = searchQuery.trim().toLowerCase();

    final result = subscriptions.where((sub) {
      if (query.isNotEmpty && !sub.name.toLowerCase().contains(query)) return false;
      if (categoryFilter != null && sub.categoryId != categoryFilter) return false;
      return switch (statusFilter) {
        StatusFilter.all => true,
        StatusFilter.active => sub.status == SubscriptionStatus.active,
        StatusFilter.paused => sub.status == SubscriptionStatus.paused,
        StatusFilter.cancelled => sub.status == SubscriptionStatus.cancelled,
      };
    }).toList();

    switch (sortBy) {
      case SubscriptionSort.priceDesc:
        result.sort((a, b) => b.monthlyEquivalent.compareTo(a.monthlyEquivalent));
      case SubscriptionSort.priceAsc:
        result.sort((a, b) => a.monthlyEquivalent.compareTo(b.monthlyEquivalent));
      case SubscriptionSort.name:
        result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case SubscriptionSort.nextBilling:
        result.sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));
    }

    return result;
  }

  List<SubscriptionModel> get activeSubscriptions =>
      subscriptions.where((s) => s.isActive).toList(growable: false);

  double get totalMonthlySpend =>
      activeSubscriptions.fold<double>(0, (sum, s) => sum + s.monthlyEquivalent);

  double get totalAnnualSpend => totalMonthlySpend * 12.0;

  int get activeCount => activeSubscriptions.length;

  /// Gasto mensal agrupado por categoria, só de assinaturas ativas.
  Map<String, double> get spendByCategory {
    final map = <String, double>{};
    for (final sub in activeSubscriptions) {
      map[sub.categoryId] = (map[sub.categoryId] ?? 0) + sub.monthlyEquivalent;
    }
    return map;
  }

  /// Cobranças dos próximos [days] dias, da mais próxima para a mais distante.
  List<SubscriptionModel> upcomingBilling({int days = 7, DateTime? now}) {
    final today = Recurrence.dateOnly(now ?? DateTime.now());
    final limit = today.add(Duration(days: days));

    return activeSubscriptions.where((sub) {
      final date = Recurrence.dateOnly(sub.nextBillingDate);
      return !date.isBefore(today) && !date.isAfter(limit);
    }).toList()
      ..sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));
  }

  SubscriptionState copyWith({
    List<SubscriptionModel>? subscriptions,
    LoadStatus? status,
    String? searchQuery,
    Object? categoryFilter = _unset,
    StatusFilter? statusFilter,
    SubscriptionSort? sortBy,
    Object? errorMessage = _unset,
  }) {
    return SubscriptionState(
      subscriptions: subscriptions ?? this.subscriptions,
      status: status ?? this.status,
      searchQuery: searchQuery ?? this.searchQuery,
      categoryFilter: identical(categoryFilter, _unset)
          ? this.categoryFilter
          : categoryFilter as String?,
      statusFilter: statusFilter ?? this.statusFilter,
      sortBy: sortBy ?? this.sortBy,
      errorMessage:
          identical(errorMessage, _unset) ? this.errorMessage : errorMessage as String?,
    );
  }

  static const Object _unset = Object();
}

class SubscriptionController extends StateNotifier<SubscriptionState> {
  SubscriptionController({
    required SubscriptionRepository repository,
    required String? userId,
    required DateTime Function() clock,
    required bool Function() shouldSeedDemo,
    required Future<void> Function() markSeeded,
  })  : _repository = repository,
        _userId = userId,
        _clock = clock,
        _shouldSeedDemo = shouldSeedDemo,
        _markSeeded = markSeeded,
        super(const SubscriptionState()) {
    if (_userId != null) {
      load();
    }
  }

  final SubscriptionRepository _repository;
  final String? _userId;
  final DateTime Function() _clock;
  final bool Function() _shouldSeedDemo;
  final Future<void> Function() _markSeeded;

  Future<void> load() async {
    final userId = _userId;
    if (userId == null) return;

    state = state.copyWith(status: LoadStatus.loading, errorMessage: null);
    final result = await _repository.loadAll(userId);
    if (!mounted) return;

    await result.fold(
      onOk: (loaded) async {
        var subscriptions = loaded;

        // Semeia a carteira de exemplo **apenas** na conta de demonstração, e uma
        // vez só. Uma conta criada de verdade pelo usuário começa vazia.
        if (subscriptions.isEmpty && _shouldSeedDemo()) {
          subscriptions = DemoSubscriptions.build(userId: userId, now: _clock());
          await _repository.saveAll(userId, subscriptions);
          await _markSeeded();
        }

        // Datas no passado são roladas para a próxima ocorrência real.
        final now = _clock();
        final rolled = subscriptions
            .map((s) => s.rolledForward(now: now))
            .toList(growable: false);

        final changed = _hasDateChanges(subscriptions, rolled);
        if (changed) await _repository.saveAll(userId, rolled);

        if (!mounted) return;
        state = state.copyWith(subscriptions: rolled, status: LoadStatus.ready);
      },
      onErr: (error) async {
        if (!mounted) return;
        state = state.copyWith(status: LoadStatus.error, errorMessage: error.message);
      },
    );
  }

  // --- Filtros (apenas estado de UI, não persistem) ---

  void setSearchQuery(String query) => state = state.copyWith(searchQuery: query);

  void setCategoryFilter(String? categoryId) =>
      state = state.copyWith(categoryFilter: categoryId);

  void setStatusFilter(StatusFilter filter) =>
      state = state.copyWith(statusFilter: filter);

  void setSortBy(SubscriptionSort sort) => state = state.copyWith(sortBy: sort);

  void clearFilters() => state = state.copyWith(
        searchQuery: '',
        categoryFilter: null,
        statusFilter: StatusFilter.all,
      );

  // --- Mutações ---

  /// Adiciona uma assinatura, respeitando o limite do plano.
  ///
  /// A checagem fica aqui, e não na tela, para que nenhum caminho de UI consiga
  /// furar o limite (o modal de cadastro não é a única porta — há a ação rápida do
  /// dashboard e, no futuro, importação).
  Future<AppException?> addSubscription(
    SubscriptionModel subscription, {
    required Entitlements entitlements,
  }) async {
    final activeCount = state.activeCount;
    if (!entitlements.canAddSubscription(activeCount, now: _clock())) {
      return EntitlementException.subscriptionLimit(FreePlanLimits.maxSubscriptions);
    }
    return _persist(<SubscriptionModel>[...state.subscriptions, subscription]);
  }

  Future<AppException?> updateSubscription(SubscriptionModel updated) {
    final next = state.subscriptions.map((s) {
      if (s.id != updated.id) return s;
      // Mudança de preço entra no histórico, que alimenta o alerta de reajuste.
      return s.price == updated.price
          ? updated
          : updated.copyWith(
              priceHistory: <PricePoint>[
                ...s.priceHistory,
                PricePoint(price: s.price, changedAt: _clock()),
              ],
            );
    }).toList(growable: false);

    return _persist(next);
  }

  Future<AppException?> setStatus(String id, SubscriptionStatus status) {
    final next = state.subscriptions
        .map((s) => s.id == id ? s.copyWith(status: status) : s)
        .toList(growable: false);
    return _persist(next);
  }

  Future<AppException?> deleteSubscription(String id) {
    final next = state.subscriptions.where((s) => s.id != id).toList(growable: false);
    return _persist(next);
  }

  Future<AppException?> setUsageLevel(String id, UsageLevel level) {
    final next = state.subscriptions
        .map((s) => s.id == id ? s.copyWith(usageLevel: level) : s)
        .toList(growable: false);
    return _persist(next);
  }

  /// Cancela em lote — usado pela ação "revisar agora" dos insights.
  Future<AppException?> cancelMany(List<String> ids) {
    final target = ids.toSet();
    final next = state.subscriptions
        .map(
          (s) => target.contains(s.id)
              ? s.copyWith(status: SubscriptionStatus.cancelled)
              : s,
        )
        .toList(growable: false);
    return _persist(next);
  }

  /// Grava e só então atualiza o estado.
  ///
  /// A ordem importa: atualizar o estado antes de gravar produziria uma UI que
  /// mostra a assinatura cadastrada e a perde no próximo boot, caso o disco falhe.
  Future<AppException?> _persist(List<SubscriptionModel> subscriptions) async {
    final userId = _userId;
    if (userId == null) return const UnexpectedException();

    final result = await _repository.saveAll(userId, subscriptions);
    if (!mounted) return null;

    return result.fold(
      onOk: (_) {
        state = state.copyWith(subscriptions: subscriptions, status: LoadStatus.ready);
        return null;
      },
      onErr: (error) {
        state = state.copyWith(errorMessage: error.message);
        return error;
      },
    );
  }

  static bool _hasDateChanges(
    List<SubscriptionModel> before,
    List<SubscriptionModel> after,
  ) {
    if (before.length != after.length) return true;
    for (var i = 0; i < before.length; i++) {
      if (before[i].nextBillingDate != after[i].nextBillingDate) return true;
    }
    return false;
  }
}

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return LocalSubscriptionRepository(store: ref.watch(keyValueStoreProvider));
});

final subscriptionControllerProvider =
    StateNotifierProvider<SubscriptionController, SubscriptionState>((ref) {
  final store = ref.watch(keyValueStoreProvider);
  final user = ref.watch(currentUserProvider);
  final userId = user?.id;
  final isDemoAccount = user?.normalizedEmail == AppConstants.demoEmail;

  return SubscriptionController(
    repository: ref.watch(subscriptionRepositoryProvider),
    userId: userId,
    clock: ref.watch(clockProvider),
    shouldSeedDemo: () =>
        userId != null &&
        isDemoAccount &&
        store.getBool(StorageKeys.demoSeeded(userId)) != true,
    markSeeded: () => userId == null
        ? Future<void>.value()
        : store.setBool(StorageKeys.demoSeeded(userId), value: true),
  );
});

/// Assinaturas ativas. Atalho para o motor de insights e para o calendário.
final activeSubscriptionsProvider = Provider<List<SubscriptionModel>>((ref) {
  return ref.watch(subscriptionControllerProvider).activeSubscriptions;
});
