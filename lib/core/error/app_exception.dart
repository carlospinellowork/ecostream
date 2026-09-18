/// Falhas de domínio do EcoStream.
///
/// Toda camada `data` converte exceções de plataforma (I/O, plugin, parsing) em uma
/// destas antes de devolver para `presentation`. A UI nunca vê `PlatformException`
/// nem `FormatException` — ela consome [AppException.message], que já está em pt-BR
/// e é seguro mostrar ao usuário.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});

  /// Mensagem pronta para exibição ao usuário final, em português.
  final String message;

  /// Erro original, preservado para log. Nunca exibido na UI.
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message${cause == null ? '' : ' (causa: $cause)'}';
}

/// Credenciais inválidas, conta inexistente ou sessão expirada.
class AuthException extends AppException {
  const AuthException(super.message, {super.cause});

  factory AuthException.invalidCredentials() =>
      const AuthException('E-mail ou senha incorretos.');

  factory AuthException.emailAlreadyInUse() =>
      const AuthException('Já existe uma conta cadastrada com este e-mail.');

  factory AuthException.accountNotFound() =>
      const AuthException('Não encontramos nenhuma conta com este e-mail.');

  factory AuthException.sessionExpired() =>
      const AuthException('Sua sessão expirou. Entre novamente para continuar.');

  factory AuthException.weakPassword() => const AuthException(
        'Senha muito fraca. Use ao menos 8 caracteres, com letras e números.',
      );
}

/// Falha ao ler ou gravar dados locais (SharedPreferences, secure storage).
class StorageException extends AppException {
  const StorageException(super.message, {super.cause});

  factory StorageException.read(Object? cause) => StorageException(
        'Não conseguimos carregar seus dados salvos.',
        cause: cause,
      );

  factory StorageException.write(Object? cause) => StorageException(
        'Não conseguimos salvar suas alterações. Tente novamente.',
        cause: cause,
      );

  factory StorageException.corrupted(Object? cause) => StorageException(
        'Alguns dados locais estavam corrompidos e foram ignorados.',
        cause: cause,
      );
}

/// Entrada do usuário rejeitada por regra de negócio.
class ValidationException extends AppException {
  const ValidationException(super.message, {super.cause});
}

/// Ação bloqueada pelo plano atual do usuário (ver features/billing).
class EntitlementException extends AppException {
  const EntitlementException(super.message, {super.cause});

  factory EntitlementException.subscriptionLimit(int limit) => EntitlementException(
        'O plano gratuito permite até $limit assinaturas. '
        'Assine o Pro para cadastrar quantas quiser.',
      );

  factory EntitlementException.proOnly(String feature) => EntitlementException(
        '$feature está disponível apenas no EcoStream Pro.',
      );
}

/// Falha de compra/restauração de assinatura.
class BillingException extends AppException {
  const BillingException(super.message, {super.cause});

  factory BillingException.purchaseFailed(Object? cause) => BillingException(
        'Não foi possível concluir a compra. Nenhuma cobrança foi feita.',
        cause: cause,
      );

  factory BillingException.nothingToRestore() => const BillingException(
        'Não encontramos nenhuma compra anterior para restaurar.',
      );
}

/// Erro não previsto. Último recurso — se está aparecendo, falta mapear um caso.
class UnexpectedException extends AppException {
  const UnexpectedException({super.cause})
      : super('Algo deu errado. Tente novamente em instantes.');
}
