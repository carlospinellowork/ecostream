import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Selo que marca conteúdo ou recurso do plano Pro.
class ProBadge extends StatelessWidget {
  const ProBadge({super.key, this.label = 'PRO', this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.pro.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.pro.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.workspace_premium_rounded, size: compact ? 11 : 13, color: AppColors.pro),
          SizedBox(width: compact ? 3 : 4),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppColors.pro,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cobre o conteúdo bloqueado com um desfoque e um convite de upgrade.
///
/// A escolha de **desfocar em vez de esconder** é deliberada: o usuário vê que
/// existe uma conclusão sobre o dinheiro dele ali, e o valor economizado aparece por
/// cima, legível. Esconder o insight inteiro remove o motivo de assinar
/// (CLAUDE.md §8).
class ProLockedOverlay extends StatelessWidget {
  const ProLockedOverlay({
    required this.child,
    required this.onUnlock,
    super.key,
    this.headline,
  });

  final Widget child;
  final VoidCallback onUnlock;

  /// Chamada de valor exibida sobre o conteúdo, ex.: "R$ 412 por ano identificados".
  final String? headline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: <Widget>[
        // `IgnorePointer` + opacidade baixa simulam o bloqueio sem precisar de
        // BackdropFilter, que custa caro em lista com rolagem.
        IgnorePointer(
          child: Opacity(opacity: 0.35, child: child),
        ),
        Positioned.fill(
          child: Material(
            color: theme.colorScheme.surface.withValues(alpha: 0.25),
            child: InkWell(
              onTap: onUnlock,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      if (headline != null) ...<Widget>[
                        Text(
                          headline!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.pro,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      FilledButton.icon(
                        onPressed: onUnlock,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.pro,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        icon: const Icon(Icons.lock_open_rounded, size: 18),
                        label: const Text('Desbloquear'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
