import '../../../core/error/app_exception.dart';
import '../../../core/error/result.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/storage/key_value_store.dart';
import '../../../core/storage/storage_keys.dart';
import '../domain/entitlements.dart';
import '../domain/plan.dart';

/// Contrato de cobrança.
///
/// Implementação atual: [LocalBillingRepository], que persiste localmente e **simula**
/// a compra. Serve para desenvolvimento, demo e para validar toda a UI do paywall.
///
/// Para produção, implemente esta interface sobre `in_app_purchase` (ou RevenueCat) e
/// troque `billingRepositoryProvider`. Nenhuma outra camada muda — é justamente para
/// isso que a interface existe (CLAUDE.md §8). O que a implementação real precisa
/// adicionar: validação do recibo no servidor, tratamento de compra pendente e
/// escuta do stream de atualizações da loja.
abstract interface class BillingRepository {
  Future<Result<Entitlements>> load(String userId);

  /// Inicia o teste gratuito. Falha se já foi usado.
  Future<Result<Entitlements>> startTrial(String userId);

  Future<Result<Entitlements>> purchase({
    required String userId,
    required PlanOffer offer,
  });

  Future<Result<Entitlements>> restore(String userId);

  /// Cancela a renovação. A vigência atual é mantida até [Entitlements.expiresAt].
  Future<Result<Entitlements>> cancel(String userId);
}

/// Cobrança local simulada.
///
/// **Não processa pagamento real.** Grava o direito de acesso no aparelho como se a
/// compra tivesse sido aprovada. Em release isso significa que o Pro é liberado sem
/// cobrança — aceitável enquanto o app não está publicado, e o único ponto a trocar
/// antes de ir para as lojas.
class LocalBillingRepository implements BillingRepository {
  LocalBillingRepository({
    required KeyValueStore store,
    DateTime Function()? clock,
  })  : _store = store,
        _clock = clock ?? DateTime.now;

  final KeyValueStore _store;
  final DateTime Function() _clock;

  @override
  Future<Result<Entitlements>> load(String userId) {
    return Result.guard<Entitlements>(
      () async {
        final json = _store.getJson(StorageKeys.entitlement(userId));
        if (json == null) return Entitlements.free;
        return Entitlements.fromJson(json);
      },
      onError: (e) {
        AppLogger.warning('Direitos de acesso ilegíveis.', scope: 'billing', error: e);
        return StorageException.read(e);
      },
    );
  }

  @override
  Future<Result<Entitlements>> startTrial(String userId) {
    return Result.guard<Entitlements>(
      () async {
        final current = await _read(userId);
        if (current.hasUsedTrial) {
          throw const BillingException(
            'Você já utilizou o teste gratuito nesta conta.',
          );
        }

        final now = _clock();
        return _persist(
          userId,
          Entitlements(
            plan: Plan.pro,
            trialStartedAt: now,
            expiresAt: now.add(PricingCatalog.trialDuration),
          ),
        );
      },
      onError: (e) => BillingException.purchaseFailed(e),
    );
  }

  @override
  Future<Result<Entitlements>> purchase({
    required String userId,
    required PlanOffer offer,
  }) {
    return Result.guard<Entitlements>(
      () async {
        final current = await _read(userId);
        final now = _clock();

        // Vigência soma a partir do maior entre agora e o vencimento atual, para que
        // renovar antes do fim não descarte os dias restantes.
        final base = current.isProActive(now: now) && current.expiresAt != null
            ? current.expiresAt!
            : now;

        AppLogger.info(
          'Compra simulada registrada: ${offer.id}',
          scope: 'billing',
        );

        return _persist(
          userId,
          current.copyWith(
            plan: Plan.pro,
            expiresAt: DateTime(base.year, base.month + offer.months, base.day),
            activeOfferId: offer.id,
          ),
        );
      },
      onError: (e) => BillingException.purchaseFailed(e),
    );
  }

  @override
  Future<Result<Entitlements>> restore(String userId) {
    return Result.guard<Entitlements>(
      () async {
        final current = await _read(userId);
        if (!current.isProActive(now: _clock())) {
          throw BillingException.nothingToRestore();
        }
        return current;
      },
      onError: (e) => BillingException.purchaseFailed(e),
    );
  }

  @override
  Future<Result<Entitlements>> cancel(String userId) {
    return Result.guard<Entitlements>(
      () async {
        final current = await _read(userId);
        // Cancelar não revoga na hora: o usuário pagou pelo período corrente.
        // Construído na mão porque `copyWith` não limpa campo anulável.
        return _persist(
          userId,
          Entitlements(
            plan: current.plan,
            trialStartedAt: current.trialStartedAt,
            expiresAt: current.expiresAt,
          ),
        );
      },
      onError: (e) => StorageException.write(e),
    );
  }

  Future<Entitlements> _read(String userId) async {
    final json = _store.getJson(StorageKeys.entitlement(userId));
    return json == null ? Entitlements.free : Entitlements.fromJson(json);
  }

  Future<Entitlements> _persist(String userId, Entitlements entitlements) async {
    await _store.setJson(StorageKeys.entitlement(userId), entitlements.toJson());
    return entitlements;
  }
}
