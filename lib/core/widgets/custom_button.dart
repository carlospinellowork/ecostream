import 'package:flutter/material.dart';

/// Variantes de botão do app.
enum ButtonVariant {
  /// Ação principal da tela. No máximo uma por tela.
  primary,

  /// Ação secundária, com contorno.
  outlined,

  /// Ação terciária, sem fundo.
  text,

  /// Ação destrutiva (cancelar assinatura, excluir conta).
  destructive,
}

/// Botão padrão do app.
///
/// Encapsula o estado de carregamento para que nenhuma tela precise trocar o
/// `child` manualmente — e, mais importante, garante que o botão fique desabilitado
/// enquanto carrega. Toque duplo em "Entrar" disparava duas autenticações antes.
class CustomButton extends StatelessWidget {
  const CustomButton({
    required this.text,
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.variant = ButtonVariant.primary,
    this.icon,
    this.expanded = true,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final ButtonVariant variant;
  final IconData? icon;

  /// Ocupa toda a largura disponível. Desligue em botões dentro de linhas.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final effectiveOnPressed = isLoading ? null : onPressed;

    final button = switch (variant) {
      ButtonVariant.primary => FilledButton(
          onPressed: effectiveOnPressed,
          child: _label(colors.onPrimary),
        ),
      ButtonVariant.outlined => OutlinedButton(
          onPressed: effectiveOnPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.primary,
            side: BorderSide(color: colors.primary.withValues(alpha: 0.6), width: 1.5),
          ),
          child: _label(colors.primary),
        ),
      ButtonVariant.text => TextButton(
          onPressed: effectiveOnPressed,
          child: _label(colors.primary),
        ),
      ButtonVariant.destructive => OutlinedButton(
          onPressed: effectiveOnPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.error,
            side: BorderSide(color: colors.error.withValues(alpha: 0.6), width: 1.5),
          ),
          child: _label(colors.error),
        ),
    };

    if (!expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }

  Widget _label(Color foreground) {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: foreground),
      );
    }

    if (icon == null) return Text(text);

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }
}
