import '../../../core/error/app_exception.dart';
import '../../../core/error/result.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/storage/key_value_store.dart';
import '../../../core/storage/storage_keys.dart';
import '../domain/subscription_model.dart';

/// Persistência das assinaturas.
///
/// A implementação atual grava JSON em [KeyValueStore], particionado por `userId`.
/// Trocar por Drift/SQLite ou por uma API significa implementar esta interface.
abstract interface class SubscriptionRepository {
  Future<Result<List<SubscriptionModel>>> loadAll(String userId);

  Future<Result<void>> saveAll(String userId, List<SubscriptionModel> subscriptions);
}

class LocalSubscriptionRepository implements SubscriptionRepository {
  LocalSubscriptionRepository({required KeyValueStore store}) : _store = store;

  final KeyValueStore _store;

  @override
  Future<Result<List<SubscriptionModel>>> loadAll(String userId) {
    return Result.guard<List<SubscriptionModel>>(
      () async {
        final raw = _store.getJsonList(StorageKeys.subscriptions(userId));
        final result = <SubscriptionModel>[];
        for (final json in raw) {
          try {
            result.add(SubscriptionModel.fromJson(json));
          } catch (e) {
            // Um registro inválido não pode impedir o usuário de ver os outros 14.
            AppLogger.warning(
              'Assinatura descartada por dado inválido.',
              scope: 'subscriptions',
              error: e,
            );
          }
        }
        return result;
      },
      onError: (e) => StorageException.read(e),
    );
  }

  @override
  Future<Result<void>> saveAll(String userId, List<SubscriptionModel> subscriptions) {
    return Result.guard<void>(
      () => _store.setJsonList(
        StorageKeys.subscriptions(userId),
        subscriptions.map((s) => s.toJson()).toList(growable: false),
      ),
      onError: (e) => StorageException.write(e),
    );
  }
}
