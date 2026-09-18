import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';

/// Medidor visual de força de senha.
///
/// Fica oculto enquanto o campo está vazio: mostrar "Fraca" em vermelho antes de o
/// usuário digitar qualquer coisa é hostil sem motivo.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({required this.password, super.key});

  final String password;

  @override
  Widget build(BuildContext context) {
    final strength = PasswordStrength.of(password);
    if (strength == PasswordStrength.none) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final color = switch (strength) {
      PasswordStrength.none => theme.colorScheme.outline,
      PasswordStrength.weak => AppColors.error,
      PasswordStrength.fair => AppColors.warning,
      PasswordStrength.good => AppColors.info,
      PasswordStrength.strong => AppColors.success,
    };

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: strength.progress,
              minHeight: 5,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Text(
                'Força: ${strength.label}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              if (strength.index < PasswordStrength.good.index)
                Text(
                  'Use 12+ caracteres e símbolos',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
