import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/key_value_store.dart';
import '../storage/secure_store.dart';

/// Providers de infraestrutura, resolvidos no boot e injetados no `ProviderScope`.
///
/// [keyValueStoreProvider] lança se usado sem override: `SharedPreferences` exige
/// `await`, e resolver isso dentro da árvore de widgets significaria toda tela
/// lidar com estado de carregamento de algo que já está pronto antes do `runApp`.
/// O override acontece em `bootstrap.dart`; nos testes, injete um
/// `InMemoryKeyValueStore`.
final keyValueStoreProvider = Provider<KeyValueStore>((ref) {
  throw UnimplementedError(
    'keyValueStoreProvider precisa de override. '
    'Use bootstrap() no app ou InMemoryKeyValueStore nos testes.',
  );
});

/// Armazenamento seguro. Também exige override em teste: `flutter_secure_storage`
/// depende de canal de plataforma e falha em `flutter test`.
final secureStoreProvider = Provider<SecureStore>((ref) => FlutterSecureStore());

/// Relógio injetável.
///
/// Toda regra que depende de "agora" (vencimentos, trial, lembretes) lê daqui em vez
/// de chamar `DateTime.now()` direto. Sem isso, testar "faltam 3 dias para a cobrança"
/// exigiria esperar o calendário virar.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
