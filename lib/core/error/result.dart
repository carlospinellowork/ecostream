import 'app_exception.dart';

/// Resultado de uma operação que pode falhar, sem usar `throw` para controle de fluxo.
///
/// Repositórios devolvem `Result<T>`; controllers fazem `switch` sobre o resultado e
/// traduzem para estado de UI. Isso torna impossível esquecer de tratar o erro — o
/// analisador reclama se o `switch` não for exaustivo.
///
/// ```dart
/// final result = await repository.signIn(email, password);
/// switch (result) {
///   case Ok(:final value):
///     state = state.authenticated(value);
///   case Err(:final error):
///     state = state.failed(error.message);
/// }
/// ```
sealed class Result<T> {
  const Result();

  /// Executa [action] e captura qualquer exceção, convertendo para [Err].
  ///
  /// [onError] mapeia a exceção crua para uma [AppException] com mensagem de usuário.
  static Future<Result<T>> guard<T>(
    Future<T> Function() action, {
    required AppException Function(Object error) onError,
  }) async {
    try {
      return Ok<T>(await action());
    } on AppException catch (e) {
      // Já é uma falha de domínio com mensagem pronta; não reembrulha.
      return Err<T>(e);
    } catch (e) {
      return Err<T>(onError(e));
    }
  }

  bool get isOk => this is Ok<T>;

  bool get isErr => this is Err<T>;

  /// Valor em caso de sucesso, ou `null` em caso de falha.
  T? get valueOrNull => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>() => null,
      };

  /// Falha em caso de erro, ou `null` em caso de sucesso.
  AppException? get errorOrNull => switch (this) {
        Ok<T>() => null,
        Err<T>(:final error) => error,
      };

  /// Valor em caso de sucesso, ou [fallback] em caso de falha.
  T getOrElse(T fallback) => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>() => fallback,
      };

  /// Transforma o valor de sucesso, preservando a falha.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        Ok<T>(:final value) => Ok<R>(transform(value)),
        Err<T>(:final error) => Err<R>(error),
      };

  /// Reduz os dois casos a um único valor.
  R fold<R>({
    required R Function(T value) onOk,
    required R Function(AppException error) onErr,
  }) =>
      switch (this) {
        Ok<T>(:final value) => onOk(value),
        Err<T>(:final error) => onErr(error),
      };
}

/// Caso de sucesso.
final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  String toString() => 'Ok($value)';
}

/// Caso de falha.
final class Err<T> extends Result<T> {
  const Err(this.error);

  final AppException error;

  @override
  String toString() => 'Err($error)';
}
