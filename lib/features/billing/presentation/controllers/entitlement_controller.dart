import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/billing_repository.dart';
import '../../domain/entitlements.dart';
import '../../domain/plan.dart';

@immutable
class EntitlementState {
  const EntitlementState({
    this.entitlements = Entitlements.free,
    this.isLoading = false,
    this.isPurchasing = false,
    this.errorMessage,
    this.justUpgraded = false,
  });

  final Entitlements entitlements;
  final bool isLoading;
  final bool isPurchasing;
  final String? errorMessage;

  /// Marca a transição para Pro, para a UI celebrar uma única vez.
  final bool justUpgraded;

  EntitlementState copyWith({
    Entitlements? entitlements,
    bool? isLoading,
    bool? isPurchasing,
    Object? errorMessage = _unset,
    bool? justUpgraded,
  }) {
    return EntitlementState(
      entitlements: entitlements ?? this.entitlements,
      isLoading: isLoading ?? this.isLoading,
      isPurchasing: isPurchasing ?? this.isPurchasing,
      errorMessage:
          identical(errorMessage, _unset) ? this.errorMessage : errorMessage as String?,
      justUpgraded: justUpgraded ?? this.justUpgraded,
    );
  }

  static const Object _unset = Object();
}

class EntitlementController extends StateNotifier<EntitlementState> {
  EntitlementController({
    required BillingRepository repository,
    required String? userId,
    required DateTime Function() clock,
  })  : _repository = repository,
        _userId = userId,
        _clock = clock,
        super(const EntitlementState()) {
    if (_userId != null) {
      load();
    }
  }

  final BillingRepository _repository;
  final String? _userId;
  final DateTime Function() _clock;

  Future<void> load() async {
    final userId = _userId;
    if (userId == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await _repository.load(userId);
    if (!mounted) return;

    state = result.fold(
      onOk: (value) => state.copyWith(entitlements: value, isLoading: false),
      onErr: (error) => state.copyWith(isLoading: false, errorMessage: error.message),
    );
  }

  Future<bool> startTrial() => _mutate((userId) => _repository.startTrial(userId));

  Future<bool> purchase(PlanOffer offer) =>
      _mutate((userId) => _repository.purchase(userId: userId, offer: offer));

  Future<bool> restore() => _mutate((userId) => _repository.restore(userId));

  Future<bool> cancel() => _mutate((userId) => _repository.cancel(userId));

  void acknowledgeUpgrade() {
    if (!state.justUpgraded) return;
    state = state.copyWith(justUpgraded: false);
  }

  void clearError() {
    if (state.errorMessage == null) return;
    state = state.copyWith(errorMessage: null);
  }

  Future<bool> _mutate(
    Future<Result<Entitlements>> Function(String userId) operation,
  ) async {
    final userId = _userId;
    if (userId == null) return false;

    final wasPro = state.entitlements.isProActive(now: _clock());
    state = state.copyWith(isPurchasing: true, errorMessage: null);

    final result = await operation(userId);
    if (!mounted) return false;

    return result.fold(
      onOk: (value) {
        state = state.copyWith(
          entitlements: value,
          isPurchasing: false,
          // Só comemora quando de fato houve transição para Pro.
          justUpgraded: !wasPro && value.isProActive(now: _clock()),
        );
        return true;
      },
      onErr: (error) {
        state = state.copyWith(isPurchasing: false, errorMessage: error.message);
        return false;
      },
    );
  }
}

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  return LocalBillingRepository(
    store: ref.watch(keyValueStoreProvider),
    clock: ref.watch(clockProvider),
  );
});

final entitlementControllerProvider =
    StateNotifierProvider<EntitlementController, EntitlementState>((ref) {
  return EntitlementController(
    repository: ref.watch(billingRepositoryProvider),
    // Trocar de conta recria o controller e recarrega os direitos da conta certa.
    userId: ref.watch(currentUserProvider)?.id,
    clock: ref.watch(clockProvider),
  );
});

/// Direitos do usuário atual. É este provider que a UI observa para decidir o que
/// liberar — nunca o plano diretamente.
final entitlementsProvider = Provider<Entitlements>((ref) {
  return ref.watch(entitlementControllerProvider).entitlements;
});

/// Se o Pro está ativo agora. Atalho para cabeçalhos e selos.
final isProProvider = Provider<bool>((ref) {
  final clock = ref.watch(clockProvider);
  return ref.watch(entitlementsProvider).isProActive(now: clock());
});
