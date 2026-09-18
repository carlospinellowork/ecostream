import '../../../core/logging/app_logger.dart';
import '../../../core/storage/key_value_store.dart';
import '../../../core/storage/secure_store.dart';
import '../../../core/storage/storage_keys.dart';
import '../domain/user_model.dart';
import 'password_hasher.dart';

/// Credencial armazenada de um usuário. Nunca sai da camada `data`.
class AuthCredential {
  const AuthCredential({
    required this.salt,
    required this.hash,
    required this.iterations,
  });

  factory AuthCredential.fromJson(Map<String, dynamic> json) => AuthCredential(
        salt: json['salt'] as String,
        hash: json['hash'] as String,
        iterations: json['iterations'] as int? ?? PasswordHasher.defaultIterations,
      );

  final String salt;
  final String hash;
  final int iterations;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'salt': salt,
        'hash': hash,
        'iterations': iterations,
      };
}

/// Persistência de contas e sessão neste aparelho.
///
/// Divisão deliberada: perfil (nome, e-mail) vai para [KeyValueStore], que é rápido e
/// legível; credencial e token de sessão vão para [SecureStore], respaldado por
/// Keystore/Keychain. Um dump de SharedPreferences não revela nada útil.
class AuthLocalDataSource {
  AuthLocalDataSource({
    required KeyValueStore store,
    required SecureStore secureStore,
  })  : _store = store,
        _secureStore = secureStore;

  final KeyValueStore _store;
  final SecureStore _secureStore;

  // --- Contas ---

  /// Todas as contas cadastradas neste aparelho.
  List<UserModel> readAccounts() {
    final raw = _store.getJsonList(StorageKeys.authAccounts);
    final accounts = <UserModel>[];
    for (final json in raw) {
      try {
        accounts.add(UserModel.fromJson(json));
      } catch (e) {
        // Uma conta corrompida não pode impedir o login das outras.
        AppLogger.warning('Conta local ignorada por dado inválido.', scope: 'auth', error: e);
      }
    }
    return accounts;
  }

  UserModel? findByEmail(String email) {
    final normalized = UserModel.normalizeEmail(email);
    for (final account in readAccounts()) {
      if (account.normalizedEmail == normalized) return account;
    }
    return null;
  }

  UserModel? findById(String id) {
    for (final account in readAccounts()) {
      if (account.id == id) return account;
    }
    return null;
  }

  /// Insere ou atualiza a conta, mantendo a lista sem duplicatas de id.
  Future<void> upsertAccount(UserModel user) async {
    final accounts = readAccounts().where((a) => a.id != user.id).toList()..add(user);
    await _store.setJsonList(
      StorageKeys.authAccounts,
      accounts.map((a) => a.toJson()).toList(growable: false),
    );
  }

  // --- Credenciais ---

  Future<AuthCredential?> readCredential(String userId) async {
    final raw = await _secureStore.read(StorageKeys.authCredential(userId));
    if (raw == null || raw.isEmpty) return null;
    try {
      return AuthCredential.fromJson(_decodeCredential(raw));
    } catch (e) {
      AppLogger.warning('Credencial local ilegível.', scope: 'auth', error: e);
      return null;
    }
  }

  Future<void> writeCredential(String userId, AuthCredential credential) async {
    await _secureStore.write(
      StorageKeys.authCredential(userId),
      _encodeCredential(credential.toJson()),
    );
  }

  // --- Sessão ---

  String? readActiveUserId() => _store.getString(StorageKeys.authActiveUserId);

  Future<String?> readSessionToken() =>
      _secureStore.read(StorageKeys.authSessionToken);

  Future<void> writeSession({required String userId, required String token}) async {
    await _store.setString(StorageKeys.authActiveUserId, userId);
    await _secureStore.write(StorageKeys.authSessionToken, token);
  }

  Future<void> clearSession() async {
    await _store.remove(StorageKeys.authActiveUserId);
    await _secureStore.delete(StorageKeys.authSessionToken);
  }

  /// Apaga a conta e tudo que pertence a ela. Usado no "excluir minha conta" —
  /// exigência de LGPD e das lojas de aplicativo.
  Future<void> deleteAccount(String userId) async {
    final remaining = readAccounts().where((a) => a.id != userId).toList();
    await _store.setJsonList(
      StorageKeys.authAccounts,
      remaining.map((a) => a.toJson()).toList(growable: false),
    );
    await _secureStore.delete(StorageKeys.authCredential(userId));
    await _store.remove(StorageKeys.subscriptions(userId));
    await _store.remove(StorageKeys.reminderSettings(userId));
    await _store.remove(StorageKeys.entitlement(userId));
    await _store.remove(StorageKeys.dismissedInsights(userId));
    await _store.remove(StorageKeys.demoSeeded(userId));
    await clearSession();
  }

  // O secure storage guarda strings; a credencial é um objeto. Serializamos aqui
  // em vez de expor jsonEncode para o resto da classe.
  Map<String, dynamic> _decodeCredential(String raw) {
    final parts = raw.split('|');
    if (parts.length != 3) {
      throw const FormatException('Formato de credencial inesperado.');
    }
    return <String, dynamic>{
      'salt': parts[0],
      'hash': parts[1],
      'iterations': int.tryParse(parts[2]) ?? PasswordHasher.defaultIterations,
    };
  }

  String _encodeCredential(Map<String, dynamic> json) =>
      '${json['salt']}|${json['hash']}|${json['iterations']}';
}
