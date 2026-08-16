import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/user_model.dart';

class AuthState {
  final UserModel? user;
  final bool isAuthenticated;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.user,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isAuthenticated,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      user: user ?? this.user,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController() : super(AuthState(
    user: UserModel(
      id: 'usr_demo_1',
      name: 'Carlos Eduardo',
      email: 'carlos@ecostream.app',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
      createdAt: DateTime(2026, 1, 1),
    ),
    isAuthenticated: true, // Pré-autenticado para facilidade no desenvolvimento do MVP
  ));

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    await Future.delayed(const Duration(milliseconds: 800)); // Simulando API

    if (email.contains('@') && password.length >= 6) {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: UserModel(
          id: 'usr_demo_1',
          name: email.split('@').first,
          email: email,
          createdAt: DateTime.now(),
        ),
      );
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'E-mail ou senha inválidos. (Mínimo 6 caracteres)',
      );
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    await Future.delayed(const Duration(milliseconds: 800));

    state = state.copyWith(
      isLoading: false,
      isAuthenticated: true,
      user: UserModel(
        id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        email: email,
        createdAt: DateTime.now(),
      ),
    );
    return true;
  }

  Future<bool> loginWithGoogle() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    await Future.delayed(const Duration(milliseconds: 1000));
    state = state.copyWith(
      isLoading: false,
      isAuthenticated: true,
      user: UserModel(
        id: 'usr_google_123',
        name: 'Carlos Eduardo (Google)',
        email: 'carlos.google@ecostream.app',
        createdAt: DateTime.now(),
      ),
    );
    return true;
  }

  void logout() {
    state = const AuthState(isAuthenticated: false, user: null);
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController();
});
