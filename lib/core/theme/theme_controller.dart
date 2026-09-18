import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../storage/key_value_store.dart';
import '../storage/storage_keys.dart';

/// Preferência de tema do usuário, persistida.
///
/// Lê de forma **síncrona** no construtor. A versão anterior carregava com `await`
/// dentro do construtor, então o app abria no tema do sistema e trocava alguns
/// quadros depois — visível como um flash branco em quem usa modo escuro.
/// Como `SharedPreferences` já está resolvido no boot, a leitura é imediata.
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._store) : super(_read(_store));

  final KeyValueStore _store;

  static ThemeMode _read(KeyValueStore store) {
    final saved = store.getString(StorageKeys.themeMode);
    for (final mode in ThemeMode.values) {
      if (mode.name == saved) return mode;
    }
    return ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    await _store.setString(StorageKeys.themeMode, mode.name);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController(ref.watch(keyValueStoreProvider));
});
