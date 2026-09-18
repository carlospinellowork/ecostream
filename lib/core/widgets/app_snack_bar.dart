import 'package:flutter/material.dart';

/// Mensagens temporárias com o estilo do app.
///
/// Concentrado aqui porque cada tela montava o `SnackBar` na mão, com paddings e
/// cores diferentes. Também usa `maybeOf`, que devolve `null` em vez de lançar
/// quando não há `ScaffoldMessenger` na árvore — situação comum ao chamar depois de
/// um `pop`.
class AppSnackBar {
  AppSnackBar._();

  static void showSuccess(BuildContext context, String message) =>
      _show(context, message, Icons.check_circle_outline, isError: false);

  static void showError(BuildContext context, String message) =>
      _show(context, message, Icons.error_outline, isError: true);

  static void _show(
    BuildContext context,
    String message,
    IconData icon, {
    required bool isError,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final colors = Theme.of(context).colorScheme;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: <Widget>[
              Icon(icon, size: 20, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message, style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
          // Erro fica mais tempo: o usuário precisa ler o que deu errado.
          backgroundColor: isError ? colors.error : const Color(0xFF0F766E),
          duration: Duration(seconds: isError ? 5 : 3),
        ),
      );
  }
}
