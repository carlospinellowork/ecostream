import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/billing/presentation/screens/paywall_screen.dart';
import '../../features/calendar/presentation/screens/calendar_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/insights/presentation/screens/insights_screen.dart';
import '../../features/navigation/presentation/screens/main_wrapper_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/reminders/presentation/screens/notification_settings_screen.dart';
import '../../features/subscriptions/presentation/screens/add_subscription_screen.dart';
import '../../features/subscriptions/presentation/screens/subscriptions_screen.dart';
import 'app_routes.dart';

/// Notifica o GoRouter quando a autenticação muda.
///
/// Esta classe existe para corrigir um defeito da versão anterior: o provider do
/// router fazia `ref.watch(authControllerProvider)`, então **todo** mudança de estado
/// de auth reconstruía o `GoRouter` inteiro — e com ele a pilha de navegação, o que
/// jogava o usuário de volta ao início a cada carregamento. Aqui o router é criado
/// uma única vez e apenas reavalia o `redirect` quando algo relevante muda.
class _AuthRouterNotifier extends ChangeNotifier {
  _AuthRouterNotifier(this._ref) {
    _subscription = _ref.listen<AuthState>(
      authControllerProvider,
      (previous, next) {
        // Só o que o guarda de rota consulta deve disparar reavaliação. Mensagem de
        // erro e ação em curso mudam muito e não afetam permissão.
        if (previous?.status != next.status) notifyListeners();
      },
      fireImmediately: false,
    );
  }

  final Ref _ref;
  late final ProviderSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');
final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthRouterNotifier(ref);
  ref.onDispose(authNotifier.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: authNotifier,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      // `ref.read` e não `watch`: o gatilho de reavaliação é o refreshListenable.
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      // Enquanto a sessão salva não terminou de carregar, ninguém sai da splash.
      // Sem isso o app decide a rota com informação incompleta e pisca a tela de
      // login para quem já estava logado.
      if (auth.isResolving) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final isPublic = AppRoutes.publicRoutes.contains(location);

      if (!auth.isAuthenticated) {
        return isPublic && location != AppRoutes.splash ? null : AppRoutes.login;
      }

      // Autenticado em rota pública (inclusive a splash já resolvida) vai ao início.
      if (isPublic) return AppRoutes.dashboard;

      return null;
    },
    errorBuilder: (context, state) => _RouteErrorScreen(location: state.uri.toString()),
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Shell com a barra de navegação. Cada aba é uma rota de verdade, então
      // deep link e botão "voltar" do Android funcionam — antes a navegação era um
      // `IndexedStack` com índice local, invisível para o router.
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainWrapperScreen(child: child),
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.dashboard,
            pageBuilder: (context, state) => const NoTransitionPage<void>(
              child: DashboardScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.subscriptions,
            pageBuilder: (context, state) => const NoTransitionPage<void>(
              child: SubscriptionsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.calendar,
            pageBuilder: (context, state) => const NoTransitionPage<void>(
              child: CalendarScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.insights,
            pageBuilder: (context, state) => const NoTransitionPage<void>(
              child: InsightsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (context, state) => const NoTransitionPage<void>(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),

      // Telas cheias, sobre o shell: usam o navigator raiz para cobrir a barra.
      GoRoute(
        path: AppRoutes.addSubscription,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddSubscriptionScreen(),
      ),
      GoRoute(
        path: AppRoutes.editSubscription,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => AddSubscriptionScreen(
          subscriptionId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: AppRoutes.paywall,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => PaywallScreen(
          source: state.uri.queryParameters['origem'],
        ),
      ),
      GoRoute(
        path: AppRoutes.notificationSettings,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
    ],
  );
});

/// Tela de rota inexistente. Um app publicado recebe links quebrados de
/// notificação, e-mail e histórico do navegador; melhor uma saída do que tela cinza.
class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.explore_off_outlined,
                  size: 56,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'Página não encontrada',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  location,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go(AppRoutes.dashboard),
                  child: const Text('Voltar ao início'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
