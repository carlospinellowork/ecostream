import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Campo de texto com rótulo externo.
///
/// O estilo vem do `inputDecorationTheme`; este widget só compõe rótulo, dica de
/// ajuda e o campo. Antes cada instância redefinia todas as bordas na mão, o que
/// fazia os campos divergirem entre telas.
class CustomTextField extends StatelessWidget {
  const CustomTextField({
    required this.label,
    super.key,
    this.hint,
    this.helperText,
    this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.inputFormatters,
    this.autofillHints,
    this.enabled = true,
    this.maxLines = 1,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final String? hint;

  /// Texto de apoio abaixo do campo, para explicar a regra antes do erro aparecer.
  final String? helperText;

  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final List<TextInputFormatter>? inputFormatters;

  /// Dicas de autofill. Preencher isso é o que faz o gerenciador de senhas do
  /// sistema oferecer e salvar credenciais — sem elas, o login fica hostil.
  final List<String>? autofillHints;

  final bool enabled;
  final int maxLines;
  final bool autofocus;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontSize: 14,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          inputFormatters: inputFormatters,
          autofillHints: autofillHints,
          enabled: enabled,
          maxLines: obscureText ? 1 : maxLines,
          autofocus: autofocus,
          textCapitalization: textCapitalization,
          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            helperText: helperText,
            helperMaxLines: 2,
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, size: 20, color: theme.colorScheme.onSurfaceVariant),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}
