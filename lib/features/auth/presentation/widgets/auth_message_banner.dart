import 'package:flutter/material.dart';

/// Faixa de mensagem usada nas telas de autenticação.
///
/// Erro de login precisa ficar visível junto ao formulário, e não num SnackBar que
/// desaparece em três segundos — o usuário digitou errado e vai corrigir ali mesmo.
class AuthMessageBanner extends StatelessWidget {
  const AuthMessageBanner({
    required this.message,
    super.key,
    this.isError = true,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = isError ? colors.error : const Color(0xFF0D9488);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
