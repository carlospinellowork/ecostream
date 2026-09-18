import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/logging/app_logger.dart';
import 'core/providers/core_providers.dart';
import 'core/storage/key_value_store.dart';

/// Inicializa tudo que precisa existir antes da primeira tela e sobe o app.
///
/// Concentrar isso aqui, e não no `main`, deixa `main.dart` como composition root
/// enxuto e permite que testes de integração reusem a mesma sequência de boot.
Future<void> bootstrap(Widget Function() appBuilder) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Erros de widget que escapariam para o console viram log estruturado.
  FlutterError.onError = (details) {
    AppLogger.error(
      details.exceptionAsString(),
      scope: 'flutter',
      error: details.exception,
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };

  await runZonedGuarded(
    () async {
      // O `intl` não traz dados de locale carregados: sem isto, o primeiro
      // DateFormat com 'pt_BR' lança LocaleDataException em runtime.
      await initializeDateFormatting('pt_BR');

      final store = await SharedPreferencesStore.create();

      runApp(
        ProviderScope(
          overrides: [
            keyValueStoreProvider.overrideWithValue(store),
          ],
          child: appBuilder(),
        ),
      );
    },
    // Relançar aqui cairia de novo neste mesmo handler; só registramos.
    (error, stackTrace) => AppLogger.error(
      'Erro não tratado fora da árvore de widgets.',
      scope: 'zone',
      error: error,
      stackTrace: stackTrace,
    ),
  );
}
