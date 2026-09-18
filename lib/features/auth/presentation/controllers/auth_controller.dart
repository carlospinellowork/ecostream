import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/auth_local_data_source.dart';
import '../../data/auth_repository.dart';
import '../../domain/user_model.dart';

/// Situação da sessão.
///
/// `unknown` é o estado inicial e existe por um motivo específico: no boot ainda não
/// sabemos se há sessão salva. Sem ele, o guarda de rota trataria "ainda não sei"
/// como "não autenticado" e o app piscaria a tela de login antes do dashboard.
enum AuthStatus { unknown, authenticated, unauthenticated }

/// Ação de autenticação em curso, para a UI saber qual botão mostrar em carregamento.
enum AuthAction { none, signIn, signUp, signUpAndSignIn, resetPassword }

@immutable
class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.pendingAction = AuthAction.none,
    this.errorMessage,
    this.infoMessage,
  });

  final AuthStatus status;
  final UserModel? user;
  final AuthAction pendingAction;

  /// Erro da última ação. Sempre uma mensagem pronta para o usuário.
  final String? errorMessage;

  /// Confirmação da última ação (ex.: "senha redefinida").
  final String? infoMessage;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  bool get isResolving => status == AuthStatus.unknown;

  bool get isBusy => pendingAction != AuthAction.none;

  bool isBusyWith(AuthAction action) => pendingAction == action;

  /// `copyWith` com sentinelas para os campos anuláveis.
  ///
  /// O `copyWith` anterior usava `errorMessage: errorMessage`, o que apagava a
  /// mensagem em toda cópia, e `user: user ?? this.user`, que tornava impossível
  /// limpar o usuário no logout. Os sentinelas resolvem os dois casos: omitir o
  /// parâmetro preserva, passar `null` explicitamente limpa.
  AuthState copyWith({
    AuthStatus? status,
    Object? user = _unset,
    AuthAction? pendingAction,
    Object? errorMessage = _unset,
    Object? infoMessage = _unset,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: identical(user, _unset) ? this.user : user as UserModel?,
      pendingAction: pendingAction ?? this.pendingAction,
      errorMessage:
          identical(errorMessage, _unset) ? this.errorMessage : errorMessage as String?,
      infoMessage:
          identical(infoMessage, _unset) ? this.infoMessage : infoMessage as String?,
    );
  }

  static const Object _unset = Object();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState &&
          other.status == status &&
          other.user == user &&
          other.pendingAction == pendingAction &&
          other.errorMessage == errorMessage &&
          other.infoMessage == infoMessage;

  @override
  int get hashCode => Object.hash(status, user, pendingAction, errorMessage, infoMessage);
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthState()) {
    // A restauração dispara no construtor: o app precisa saber se há sessão antes
    // de decidir a primeira rota.
    unawaited(restoreSession());
  }

  final AuthRepository _repository;

  Future<void> restoreSession() async {
    final result = await _repository.restoreSession();
    if (!mounted) return;

    state = result.fold(
      onOk: (user) => state.copyWith(
        status: user == null ? AuthStatus.unauthenticated : AuthStatus.authenticated,
        user: user,
        pendingAction: AuthAction.none,
        errorMessage: null,
      ),
      onErr: (error) {
        AppLogger.warning('Sessão não restaurada.', scope: 'auth', error: error);
        // Falha ao ler o storage não deve prender o usuário numa tela de erro:
        // tratamos como "não logado" e ele entra normalmente.
        return state.copyWith(
          status: AuthStatus.unauthenticated,
          user: null,
          pendingAction: AuthAction.none,
        );
      },
    );
  }

  Future<bool> signIn({required String email, required String password}) async {
    return _run(
      action: AuthAction.signIn,
      operation: () => _repository.signIn(email: email, password: password),
    );
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    return _run(
      action: AuthAction.signUp,
      operation: () => _repository.signUp(name: name, email: email, password: password),
    );
  }

  /// Entrada de demonstração, para avaliar o app sem criar conta.
  ///
  /// Substitui o antigo `isAuthenticated: true` fixo no construtor, que deixava
  /// qualquer pessoa dentro do app já autenticada como um usuário real.
  /// Aqui a conta demo é criada de verdade, com senha, e o usuário pode sair dela.
  Future<bool> signInAsDemo() async {
    const email = AppConstants.demoEmail;
    const password = AppConstants.demoPassword;

    state = state.copyWith(
      pendingAction: AuthAction.signUpAndSignIn,
      errorMessage: null,
      infoMessage: null,
    );

    var result = await _repository.signIn(email: email, password: password);
    if (result.isErr) {
      // Primeira execução neste aparelho: a conta demo ainda não existe.
      result = await _repository.signUp(
        name: AppConstants.demoName,
        email: email,
        password: password,
      );
    }
    return _apply(result);
  }

  Future<bool> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    state = state.copyWith(
      pendingAction: AuthAction.resetPassword,
      errorMessage: null,
      infoMessage: null,
    );

    final result = await _repository.resetPassword(email: email, newPassword: newPassword);
    if (!mounted) return false;

    return result.fold(
      onOk: (_) {
        state = state.copyWith(
          pendingAction: AuthAction.none,
          infoMessage: 'Senha redefinida. Entre com a nova senha.',
        );
        return true;
      },
      onErr: (error) {
        state = state.copyWith(
          pendingAction: AuthAction.none,
          errorMessage: error.message,
        );
        return false;
      },
    );
  }

  Future<void> updateProfile({String? name, String? avatarUrl}) async {
    final userId = state.user?.id;
    if (userId == null) return;

    final result = await _repository.updateProfile(
      userId: userId,
      name: name,
      avatarUrl: avatarUrl,
    );
    if (!mounted) return;

    state = result.fold(
      onOk: (user) => state.copyWith(user: user, infoMessage: 'Perfil atualizado.'),
      onErr: (error) => state.copyWith(errorMessage: error.message),
    );
  }

  Future<void> signOut() async {
    await _repository.signOut();
    if (!mounted) return;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> deleteAccount() async {
    final userId = state.user?.id;
    if (userId == null) return;
    await _repository.deleteAccount(userId);
    if (!mounted) return;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Limpa mensagens já exibidas, para não reaparecerem ao voltar para a tela.
  void clearMessages() {
    if (state.errorMessage == null && state.infoMessage == null) return;
    state = state.copyWith(errorMessage: null, infoMessage: null);
  }

  Future<bool> _run({
    required AuthAction action,
    required Future<Result<UserModel>> Function() operation,
  }) async {
    state = state.copyWith(
      pendingAction: action,
      errorMessage: null,
      infoMessage: null,
    );
    return _apply(await operation());
  }

  bool _apply(Result<UserModel> result) {
    if (!mounted) return false;

    return result.fold(
      onOk: (user) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          pendingAction: AuthAction.none,
          errorMessage: null,
        );
        return true;
      },
      onErr: (error) {
        state = state.copyWith(
          pendingAction: AuthAction.none,
          errorMessage: error.message,
        );
        return false;
      },
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return LocalAuthRepository(
    dataSource: AuthLocalDataSource(
      store: ref.watch(keyValueStoreProvider),
      secureStore: ref.watch(secureStoreProvider),
    ),
  );
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});

/// Usuário autenticado, ou `null`. Atalho para telas que só precisam do perfil.
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authControllerProvider).user;
});
