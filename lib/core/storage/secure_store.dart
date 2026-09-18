import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../error/app_exception.dart';
import '../logging/app_logger.dart';

/// Armazenamento para dados **sensíveis**: hash de senha, salt e token de sessão.
///
/// No Android usa o Keystore (`EncryptedSharedPreferences`), no iOS o Keychain.
/// Nada que passe por aqui deve ser logado.
abstract interface class SecureStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);

  Future<void> deleteAll();
}

/// Implementação sobre `flutter_secure_storage`.
class FlutterSecureStore implements SecureStore {
  FlutterSecureStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      // Keystore corrompido (acontece após restore de backup) não pode travar o login:
      // tratamos como "sem credencial" e o usuário refaz a autenticação.
      AppLogger.warning('Falha ao ler do armazenamento seguro.', scope: 'secure', error: e);
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      throw StorageException.write(e);
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      AppLogger.warning('Falha ao apagar do armazenamento seguro.', scope: 'secure', error: e);
    }
  }

  @override
  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      AppLogger.warning('Falha ao limpar o armazenamento seguro.', scope: 'secure', error: e);
    }
  }
}

/// Implementação em memória, para testes. `flutter_secure_storage` exige plataforma
/// e sempre falha em `flutter test` sem mock.
@visibleForTesting
class InMemorySecureStore implements SecureStore {
  final Map<String, String> _data = <String, String>{};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<void> deleteAll() async => _data.clear();
}
