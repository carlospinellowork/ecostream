import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Cartão base do app.
///
/// Lê cor e borda do `ColorScheme` em vez de decidir por `isDark`, que era o padrão
/// anterior: cada widget reimplementava a decisão de cor e elas divergiam entre
/// telas. Sombra só no tema claro — no escuro, sombra preta sobre fundo escuro não
/// cria profundidade, só suja a borda.
class CustomCard extends StatelessWidget {
  const CustomCard({
    required this.child,
    super.key,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;

  /// Aplica sombra mais forte, para elementos que precisam saltar (banners).
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final radius = BorderRadius.circular(AppTheme.radius);

    return Material(
      color: backgroundColor ?? theme.colorScheme.surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: borderColor ?? theme.colorScheme.outlineVariant),
            boxShadow: isLight
                ? <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: elevated ? 0.08 : 0.03),
                      blurRadius: elevated ? 20 : 10,
                      offset: Offset(0, elevated ? 8 : 4),
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}
