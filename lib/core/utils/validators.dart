/// Validação de entrada do usuário.
///
/// Retornam `null` quando válido e a mensagem em pt-BR quando inválido — assinatura
/// compatível com `TextFormField.validator`. Regra de negócio fica aqui, e não dentro
/// das telas, para que login, cadastro e edição de perfil não divirjam.
class Validators {
  Validators._();

  /// Mínimo aceito em senha nova. Cadastros antigos com 6 caracteres continuam
  /// funcionando no login — a regra mais rígida vale só para criação e troca.
  static const int minPasswordLength = 8;

  /// RFC 5322 completo é inviável e rejeita endereços válidos. Este padrão cobre o
  /// que importa na prática: algo@algo.tld, sem espaço e com TLD de 2+ letras.
  static final RegExp _emailPattern = RegExp(
    r'^[\w.!#$%&*+/=?^`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?'
    r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$',
  );

  static final RegExp _hasLetter = RegExp('[A-Za-zÀ-ÿ]');
  static final RegExp _hasDigit = RegExp('[0-9]');
  static final RegExp _hasUpper = RegExp('[A-ZÀ-Þ]');
  static final RegExp _hasSymbol = RegExp(r'[^A-Za-z0-9À-ÿ]');

  static bool isValidEmail(String value) => _emailPattern.hasMatch(value.trim());

  static String? email(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Informe seu e-mail';
    if (!isValidEmail(input)) return 'Informe um e-mail válido';
    return null;
  }

  /// Validação de senha **nova** (cadastro e redefinição).
  static String? newPassword(String? value) {
    final input = value ?? '';
    if (input.isEmpty) return 'Crie uma senha';
    if (input.length < minPasswordLength) {
      return 'Use ao menos $minPasswordLength caracteres';
    }
    if (!_hasLetter.hasMatch(input) || !_hasDigit.hasMatch(input)) {
      return 'Combine letras e números';
    }
    return null;
  }

  /// Validação de senha **existente** (login). Só checa presença: mensagens sobre
  /// formato aqui apenas ajudariam alguém tentando adivinhar credenciais.
  static String? currentPassword(String? value) {
    if (value == null || value.isEmpty) return 'Informe sua senha';
    return null;
  }

  static String? passwordConfirmation(String? value, String original) {
    if (value == null || value.isEmpty) return 'Repita a senha';
    if (value != original) return 'As senhas não coincidem';
    return null;
  }

  static String? fullName(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Informe seu nome';
    if (input.length < 2) return 'Nome muito curto';
    if (input.length > 60) return 'Nome muito longo';
    return null;
  }

  static String? subscriptionName(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Informe o nome do serviço';
    if (input.length > 40) return 'Use no máximo 40 caracteres';
    return null;
  }

  /// Valida e normaliza um valor monetário digitado.
  ///
  /// Aceita "59,90" e "59.90": no teclado brasileiro a vírgula é o separador decimal,
  /// mas o teclado numérico do iOS entrega ponto.
  static String? price(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Informe o valor';
    final parsed = parsePrice(input);
    if (parsed == null) return 'Valor inválido';
    if (parsed <= 0) return 'O valor deve ser maior que zero';
    if (parsed > 1000000) return 'Valor acima do limite permitido';
    return null;
  }

  /// Converte texto digitado em `double`, ou `null` se não for um número.
  ///
  /// O ponto é ambíguo no Brasil: em "1.234" é separador de milhar, em "59.90"
  /// (o que o teclado numérico do iOS entrega) é decimal. A versão anterior
  /// removia todo ponto antes de trocar a vírgula, então "59.90" virava **5990,00**
  /// — quem digitasse no iPhone cadastraria uma assinatura cem vezes mais cara.
  ///
  /// Regra adotada:
  /// - se há vírgula, ela é o separador decimal e os pontos são de milhar;
  /// - se só há pontos, o último conta como decimal quando sobram 1 ou 2 dígitos
  ///   depois dele, e como milhar quando sobram 3.
  static double? parsePrice(String value) {
    // Remove símbolo de moeda, espaços e qualquer outro ruído de digitação.
    final cleaned = value.trim().replaceAll(RegExp(r'[^\d.,-]'), '');
    if (cleaned.isEmpty) return null;

    if (cleaned.contains(',')) {
      return double.tryParse(cleaned.replaceAll('.', '').replaceAll(',', '.'));
    }

    final lastDot = cleaned.lastIndexOf('.');
    if (lastDot == -1) return double.tryParse(cleaned);

    final decimalDigits = cleaned.length - lastDot - 1;
    if (decimalDigits == 1 || decimalDigits == 2) {
      final intPart = cleaned.substring(0, lastDot).replaceAll('.', '');
      return double.tryParse('$intPart.${cleaned.substring(lastDot + 1)}');
    }

    return double.tryParse(cleaned.replaceAll('.', ''));
  }
}

/// Força de uma senha, usada no medidor visual do cadastro.
enum PasswordStrength {
  none('', 0.0),
  weak('Fraca', 0.25),
  fair('Razoável', 0.5),
  good('Boa', 0.75),
  strong('Forte', 1.0);

  const PasswordStrength(this.label, this.progress);

  final String label;

  /// Valor de 0 a 1 para a barra de progresso.
  final double progress;

  /// Pontua a senha por comprimento e variedade de caracteres.
  ///
  /// Não é entropia real: é um indicador que empurra o usuário para senhas melhores
  /// sem bloquear. O bloqueio efetivo é [Validators.newPassword].
  static PasswordStrength of(String password) {
    if (password.isEmpty) return PasswordStrength.none;

    var score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (Validators._hasUpper.hasMatch(password)) score++;
    if (Validators._hasDigit.hasMatch(password)) score++;
    if (Validators._hasSymbol.hasMatch(password)) score++;

    // Senhas curtas nunca passam de "fraca", por mais variadas que sejam.
    if (password.length < 8) return PasswordStrength.weak;

    return switch (score) {
      <= 1 => PasswordStrength.weak,
      2 => PasswordStrength.fair,
      3 => PasswordStrength.good,
      _ => PasswordStrength.strong,
    };
  }
}
