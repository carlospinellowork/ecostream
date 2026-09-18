import 'package:uuid/uuid.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/result.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/utils/validators.dart';
import '../domain/user_model.dart';
import 'auth_local_data_source.dart';
import 'password_hasher.dart';

/// Contrato de autenticação.
///
/// Trocar o MVP local por um backend significa implementar esta interface e
/// substituir o provider. Nada em `presentation/` deve precisar mudar — se precisar,
/// é vazamento de camada (CLAUDE.md §7).
abstract interface class AuthRepository {
  /// Restaura a sessão salva no aparelho. `Ok(null)` significa "ninguém logado",
  /// que é diferente de erro.
  Future<Result<UserModel?>> restoreSession();

  Future<Result<UserModel>> signIn({required String email, required String password});

  Future<Result<UserModel>> signUp({
    required String name,
    required String email,
    required String password,
  });

  Future<Result<void>> signOut();

  /// Redefine a senha de uma conta existente neste aparelho.
  Future<Result<void>> resetPassword({
    required String email,
    required String newPassword,
  });

  Future<Result<UserModel>> updateProfile({
    required String userId,
    String? name,
    String? avatarUrl,
  });

  Future<Result<void>> deleteAccount(String userId);
}

/// Autenticação local, sem servidor.
///
/// É a implementação de produção do MVP: contas ficam no aparelho, senha é guardada
/// como hash PBKDF2 e a sessão sobrevive ao fechamento do app.
///
/// Limitação conhecida e aceita: sem backend não há recuperação de senha por e-mail
/// nem sincronização entre aparelhos. [resetPassword] funciona porque a conta está
/// no próprio aparelho — é uma redefinição local, e a UI deixa isso explícito.
class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository({
    required AuthLocalDataSource dataSource,
    Uuid? uuid,
    int? iterations,
  })  : _dataSource = dataSource,
        _uuid = uuid ?? const Uuid(),
        _iterations = iterations ?? PasswordHasher.defaultIterations;

  final AuthLocalDataSource _dataSource;
  final Uuid _uuid;

  /// Custo do PBKDF2 para senhas **novas**.
  ///
  /// Injetável porque a suíte de testes faz dezenas de derivações; com o valor de
  /// produção ela levaria minutos sem cobrir nada a mais. A verificação de senha
  /// existente sempre usa o valor gravado na credencial, não este.
  final int _iterations;

  @override
  Future<Result<UserModel?>> restoreSession() {
    return Result.guard<UserModel?>(
      () async {
        final userId = _dataSource.readActiveUserId();
        if (userId == null) return null;

        final token = await _dataSource.readSessionToken();
        if (token == null || token.isEmpty) {
          // Id de usuário sem token: estado inconsistente (ex.: Keystore limpo após
          // restore de backup). Limpamos e pedimos login de novo.
          await _dataSource.clearSession();
          return null;
        }

        final user = _dataSource.findById(userId);
        if (user == null) {
          await _dataSource.clearSession();
          return null;
        }
        return user;
      },
      onError: (e) {
        AppLogger.warning('Falha ao restaurar sessão.', scope: 'auth', error: e);
        return StorageException.read(e);
      },
    );
  }

  @override
  Future<Result<UserModel>> signIn({
    required String email,
    required String password,
  }) {
    return Result.guard<UserModel>(
      () async {
        final user = _dataSource.findByEmail(email);
        if (user == null) {
          // Mensagem genérica de propósito: dizer "conta não existe" permite
          // enumerar quais e-mails estão cadastrados.
          throw AuthException.invalidCredentials();
        }

        final credential = await _dataSource.readCredential(user.id);
        if (credential == null) throw AuthException.invalidCredentials();

        final matches = PasswordHasher.verify(
          password: password,
          salt: credential.salt,
          expectedHash: credential.hash,
          iterations: credential.iterations,
        );
        if (!matches) throw AuthException.invalidCredentials();

        await _startSession(user.id);
        return user;
      },
      onError: (e) => UnexpectedException(cause: e),
    );
  }

  @override
  Future<Result<UserModel>> signUp({
    required String name,
    required String email,
    required String password,
  }) {
    return Result.guard<UserModel>(
      () async {
        final normalized = UserModel.normalizeEmail(email);
        if (!Validators.isValidEmail(normalized)) {
          throw const ValidationException('Informe um e-mail válido.');
        }
        if (Validators.newPassword(password) != null) {
          throw AuthException.weakPassword();
        }
        if (_dataSource.findByEmail(normalized) != null) {
          throw AuthException.emailAlreadyInUse();
        }

        final user = UserModel(
          id: 'usr_${_uuid.v4()}',
          name: name.trim(),
          email: normalized,
          createdAt: DateTime.now(),
        );

        final salt = PasswordHasher.generateSalt();
        await _dataSource.writeCredential(
          user.id,
          AuthCredential(
            salt: salt,
            hash: PasswordHasher.hash(
              password: password,
              salt: salt,
              iterations: _iterations,
            ),
            iterations: _iterations,
          ),
        );
        await _dataSource.upsertAccount(user);
        await _startSession(user.id);
        return user;
      },
      onError: (e) => UnexpectedException(cause: e),
    );
  }

  @override
  Future<Result<void>> signOut() {
    return Result.guard<void>(
      _dataSource.clearSession,
      onError: (e) => StorageException.write(e),
    );
  }

  @override
  Future<Result<void>> resetPassword({
    required String email,
    required String newPassword,
  }) {
    return Result.guard<void>(
      () async {
        final user = _dataSource.findByEmail(email);
        if (user == null) throw AuthException.accountNotFound();
        if (Validators.newPassword(newPassword) != null) {
          throw AuthException.weakPassword();
        }

        final salt = PasswordHasher.generateSalt();
        await _dataSource.writeCredential(
          user.id,
          AuthCredential(
            salt: salt,
            hash: PasswordHasher.hash(
              password: newPassword,
              salt: salt,
              iterations: _iterations,
            ),
            iterations: _iterations,
          ),
        );
        // Troca de senha invalida a sessão: é o comportamento esperado caso alguém
        // tenha ficado logado em outro contexto.
        await _dataSource.clearSession();
      },
      onError: (e) => UnexpectedException(cause: e),
    );
  }

  @override
  Future<Result<UserModel>> updateProfile({
    required String userId,
    String? name,
    String? avatarUrl,
  }) {
    return Result.guard<UserModel>(
      () async {
        final current = _dataSource.findById(userId);
        if (current == null) throw AuthException.accountNotFound();

        final trimmedName = name?.trim();
        final updated = current.copyWith(
          // Nome em branco mantém o atual em vez de apagar o perfil.
          name: (trimmedName == null || trimmedName.isEmpty) ? null : trimmedName,
          avatarUrl: avatarUrl,
        );
        await _dataSource.upsertAccount(updated);
        return updated;
      },
      onError: (e) => StorageException.write(e),
    );
  }

  @override
  Future<Result<void>> deleteAccount(String userId) {
    return Result.guard<void>(
      () => _dataSource.deleteAccount(userId),
      onError: (e) => StorageException.write(e),
    );
  }

  Future<void> _startSession(String userId) async {
    await _dataSource.writeSession(
      userId: userId,
      token: PasswordHasher.generateSessionToken(),
    );
  }
}
