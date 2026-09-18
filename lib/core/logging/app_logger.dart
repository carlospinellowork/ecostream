import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Níveis de log, em ordem crescente de severidade.
enum LogLevel { debug, info, warning, error }

/// Logger central do app.
///
/// Existe por dois motivos: `print()` não sobrevive a build de release e não dá para
/// filtrar, e um ponto único facilita plugar Crashlytics/Sentry depois — basta
/// implementar [LogSink] e registrar em [AppLogger.addSink].
///
/// Em release, apenas `warning` e `error` são emitidos, e nunca contêm dados pessoais:
/// não logue e-mail, senha, token ou valores financeiros do usuário.
class AppLogger {
  AppLogger._();

  static final List<LogSink> _sinks = <LogSink>[];

  /// Em release só interessam problemas; debug/info viram ruído e custo.
  static LogLevel minimumLevel = kReleaseMode ? LogLevel.warning : LogLevel.debug;

  static void addSink(LogSink sink) => _sinks.add(sink);

  @visibleForTesting
  static void clearSinks() => _sinks.clear();

  static void debug(String message, {String? scope}) =>
      _log(LogLevel.debug, message, scope: scope);

  static void info(String message, {String? scope}) =>
      _log(LogLevel.info, message, scope: scope);

  static void warning(String message, {String? scope, Object? error}) =>
      _log(LogLevel.warning, message, scope: scope, error: error);

  static void error(
    String message, {
    String? scope,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(LogLevel.error, message, scope: scope, error: error, stackTrace: stackTrace);

  static void _log(
    LogLevel level,
    String message, {
    String? scope,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minimumLevel.index) return;

    final label = scope == null ? 'EcoStream' : 'EcoStream/$scope';
    developer.log(
      message,
      name: label,
      level: _severity(level),
      error: error,
      stackTrace: stackTrace,
    );

    for (final sink in _sinks) {
      sink.write(level, label, message, error, stackTrace);
    }
  }

  /// Mapeia para os níveis do `dart:developer`, que segue a convenção do `logging`.
  static int _severity(LogLevel level) => switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warning => 900,
        LogLevel.error => 1000,
      };
}

/// Destino adicional de log. Implemente para enviar a Crashlytics, Sentry etc.
abstract interface class LogSink {
  void write(
    LogLevel level,
    String scope,
    String message,
    Object? error,
    StackTrace? stackTrace,
  );
}
