import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../error/app_exception.dart';
import '../logging/app_logger.dart';

/// Armazenamento local simples para dados **não sensíveis** (tema, perfil, assinaturas).
///
/// É uma interface, e não o `SharedPreferences` direto, por dois motivos: testes
/// unitários não têm plataforma disponível, e um dia isso pode virar Hive/Drift sem
/// que nenhuma feature precise mudar.
abstract interface class KeyValueStore {
  String? getString(String key);

  Future<void> setString(String key, String value);

  bool? getBool(String key);

  Future<void> setBool(String key, {required bool value});

  Future<void> remove(String key);

  /// Lê e decodifica um objeto JSON. Devolve `null` se ausente ou corrompido.
  Map<String, dynamic>? getJson(String key);

  Future<void> setJson(String key, Map<String, dynamic> value);

  /// Lê e decodifica uma lista JSON. Devolve lista vazia se ausente ou corrompida.
  List<Map<String, dynamic>> getJsonList(String key);

  Future<void> setJsonList(String key, List<Map<String, dynamic>> value);
}

/// Implementação sobre `SharedPreferences`.
class SharedPreferencesStore implements KeyValueStore {
  SharedPreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  /// Deve ser chamado uma vez no boot, antes de montar a árvore de widgets.
  static Future<SharedPreferencesStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SharedPreferencesStore(prefs);
  }

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  @override
  bool? getBool(String key) => _prefs.getBool(key);

  @override
  Future<void> setBool(String key, {required bool value}) async {
    await _prefs.setBool(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  @override
  Map<String, dynamic>? getJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      AppLogger.warning('Valor em "$key" não é um objeto JSON.', scope: 'storage');
      return null;
    } on FormatException catch (e) {
      // Dado corrompido não deve derrubar o app: descartamos e seguimos com o padrão.
      AppLogger.warning('JSON inválido em "$key".', scope: 'storage', error: e);
      return null;
    }
  }

  @override
  Future<void> setJson(String key, Map<String, dynamic> value) async {
    try {
      await _prefs.setString(key, jsonEncode(value));
    } catch (e) {
      throw StorageException.write(e);
    }
  }

  @override
  List<Map<String, dynamic>> getJsonList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        AppLogger.warning('Valor em "$key" não é uma lista JSON.', scope: 'storage');
        return const [];
      }
      return decoded.whereType<Map<String, dynamic>>().toList(growable: false);
    } on FormatException catch (e) {
      AppLogger.warning('Lista JSON inválida em "$key".', scope: 'storage', error: e);
      return const [];
    }
  }

  @override
  Future<void> setJsonList(String key, List<Map<String, dynamic>> value) async {
    try {
      await _prefs.setString(key, jsonEncode(value));
    } catch (e) {
      throw StorageException.write(e);
    }
  }
}

/// Implementação em memória, para testes e para `flutter test` (sem plataforma).
@visibleForTesting
class InMemoryKeyValueStore implements KeyValueStore {
  InMemoryKeyValueStore([Map<String, String>? seed])
      : _data = <String, String>{...?seed};

  final Map<String, String> _data;

  @override
  String? getString(String key) => _data[key];

  @override
  Future<void> setString(String key, String value) async => _data[key] = value;

  @override
  bool? getBool(String key) {
    final raw = _data[key];
    if (raw == null) return null;
    return raw == 'true';
  }

  @override
  Future<void> setBool(String key, {required bool value}) async =>
      _data[key] = value.toString();

  @override
  Future<void> remove(String key) async => _data.remove(key);

  @override
  Map<String, dynamic>? getJson(String key) {
    final raw = _data[key];
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> setJson(String key, Map<String, dynamic> value) async =>
      _data[key] = jsonEncode(value);

  @override
  List<Map<String, dynamic>> getJsonList(String key) {
    final raw = _data[key];
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded.whereType<Map<String, dynamic>>().toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  @override
  Future<void> setJsonList(String key, List<Map<String, dynamic>> value) async =>
      _data[key] = jsonEncode(value);
}
