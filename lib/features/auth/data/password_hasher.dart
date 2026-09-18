import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Hash de senha com PBKDF2-HMAC-SHA256.
///
/// Senha em texto plano nunca é persistida. Guardamos `salt` + `hash` + `iterations`,
/// e a verificação recalcula o hash a partir da senha digitada.
///
/// Por que PBKDF2 e não SHA-256 puro: SHA-256 é rápido de propósito, o que também
/// torna rápido testar bilhões de senhas caso o armazenamento vaze. PBKDF2 aplica a
/// função repetidas vezes para tornar cada tentativa cara.
///
/// Por que não Argon2/bcrypt: exigem dependência nativa, e este projeto evita
/// plugin nativo novo sem necessidade (CLAUDE.md §12). PBKDF2 com 120k iterações é
/// adequado para autenticação local, sem servidor no meio.
class PasswordHasher {
  PasswordHasher._();

  /// Custo por tentativa. Valor escolhido para ficar em ~100–250 ms em aparelho
  /// de entrada: incômodo para ataque em lote, imperceptível no login.
  static const int defaultIterations = 120000;

  static const int _saltBytes = 16;
  static const int _keyBytes = 32;

  static final Random _random = Random.secure();

  /// Gera um salt aleatório em base64. Um salt por usuário impede que duas contas
  /// com a mesma senha produzam o mesmo hash.
  static String generateSalt() {
    final bytes = Uint8List(_saltBytes);
    for (var i = 0; i < _saltBytes; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return base64Url.encode(bytes);
  }

  /// Deriva o hash de [password] com [salt], em base64.
  static String hash({
    required String password,
    required String salt,
    int iterations = defaultIterations,
  }) {
    final derived = _pbkdf2(
      password: utf8.encode(password),
      salt: base64Url.decode(salt),
      iterations: iterations,
      keyLength: _keyBytes,
    );
    return base64Url.encode(derived);
  }

  /// Confere [password] contra um hash conhecido.
  static bool verify({
    required String password,
    required String salt,
    required String expectedHash,
    int iterations = defaultIterations,
  }) {
    final actual = hash(password: password, salt: salt, iterations: iterations);
    return _constantTimeEquals(actual, expectedHash);
  }

  /// Token opaco de sessão, em base64. 32 bytes de entropia.
  static String generateSessionToken() {
    final bytes = Uint8List(32);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return base64Url.encode(bytes);
  }

  /// PBKDF2 conforme RFC 8018, com HMAC-SHA256 como PRF.
  static Uint8List _pbkdf2({
    required List<int> password,
    required List<int> salt,
    required int iterations,
    required int keyLength,
  }) {
    final hmac = Hmac(sha256, password);
    const hashLength = 32; // saída do SHA-256 em bytes
    final blockCount = (keyLength / hashLength).ceil();
    final output = Uint8List(blockCount * hashLength);

    for (var block = 1; block <= blockCount; block++) {
      // U1 = PRF(senha, salt || INT_32_BE(i))
      final blockInput = Uint8List(salt.length + 4)
        ..setRange(0, salt.length, salt)
        ..[salt.length] = (block >> 24) & 0xff
        ..[salt.length + 1] = (block >> 16) & 0xff
        ..[salt.length + 2] = (block >> 8) & 0xff
        ..[salt.length + 3] = block & 0xff;

      var u = Uint8List.fromList(hmac.convert(blockInput).bytes);
      final accumulator = Uint8List.fromList(u);

      // U2..Uc, acumulando por XOR.
      for (var i = 1; i < iterations; i++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (var j = 0; j < hashLength; j++) {
          accumulator[j] ^= u[j];
        }
      }

      output.setRange((block - 1) * hashLength, block * hashLength, accumulator);
    }

    return Uint8List.sublistView(output, 0, keyLength);
  }

  /// Comparação em tempo constante.
  ///
  /// `==` em String faz curto-circuito no primeiro byte diferente, o que vaza
  /// informação por tempo. O custo aqui é irrelevante e remove a classe inteira
  /// de ataque.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
