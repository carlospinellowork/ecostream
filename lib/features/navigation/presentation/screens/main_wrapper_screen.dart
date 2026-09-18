import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';

/// Casca com a barra de navegação inferior.
///
/// Recebe o [child] do `ShellRoute`: cada aba é uma rota real, então deep link,
/// botão "voltar" do Android e restauração de estado funcionam. A versão anterior
/// usava `IndexedStack` com índice em `setState`, invisível para o router — o que
/// também quebrava `context.go('/calendar')` vindo do dashboard.
class MainWrapperScreen extends StatelessWidget {
  const MainWrapperScreen({required this.child, super.key});

  final Widget child;

  static const List<_NavItem> _items = <_NavItem>[
    _NavItem(
      route: AppRoutes.dashboard,
      label: 'Início',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _NavItem(
      route: AppRoutes.subscriptions,
      label: 'Assinaturas',
      icon: Icons.subscriptions_outlined,
      selectedIcon: Icons.subscriptions_rounded,
    ),
    _NavItem(
      route: AppRoutes.calendar,
      label: 'Calendário',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month_rounded,
    ),
    _NavItem(
      route: AppRoutes.insights,
      label: 'Insights',
      icon: Icons.lightbulb_outline,
      selectedIcon: Icons.lightbulb_rounded,
    ),
    _NavItem(
      route: AppRoutes.profile,
      label: 'Perfil',
      icon: Icons.person_outline,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  /// Índice da aba correspondente à rota atual.
  ///
  /// Usa `startsWith` para que sub-rotas futuras (ex.: `/assinaturas/detalhe`)
  /// mantenham a aba certa destacada.
  static int _indexForLocation(String location) {
    for (var i = 0; i < _items.length; i++) {
      if (location.startsWith(_items[i].route)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final currentIndex = _indexForLocation(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          if (index == currentIndex) return;
          context.go(_items[index].route);
        },
        destinations: _items
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
                tooltip: item.label,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.route,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
