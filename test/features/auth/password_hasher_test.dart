import 'package:ecostream/features/auth/data/password_hasher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Iterações reduzidas: o valor de produção (120k) custa centenas de milissegundos
  // por chamada e deixaria a suíte lenta sem testar nada a mais.
  const iterations = 1000;

  group('PasswordHasher.generateSalt', () {
    test('gera salts diferentes a cada chamada', () {
      final salts = <String>{
        for (var i = 0; i < 50; i++) PasswordHasher.generateSalt(),
      };
      expect(salts, hasLength(50));
    });
  });

  group('PasswordHasher.hash', () {
    test('é determinístico para a mesma senha e salt', () {
      final salt = PasswordHasher.generateSalt();
      final first = PasswordHasher.hash(
        password: 'senha2026',
        salt: salt,
        iterations: iterations,
      );
      final second = PasswordHasher.hash(
        password: 'senha2026',
        salt: salt,
        iterations: iterations,
      );
      expect(first, second);
    });

    test('salts diferentes produzem hashes diferentes para a mesma senha', () {
      // É o que impede descobrir que duas contas usam a mesma senha.
      final hashA = PasswordHasher.hash(
        password: 'senha2026',
        salt: PasswordHasher.generateSalt(),
        iterations: iterations,
      );
      final hashB = PasswordHasher.hash(
        password: 'senha2026',
        salt: PasswordHasher.generateSalt(),
        iterations: iterations,
      );
      expect(hashA, isNot(hashB));
    });

    test('nunca contém a senha em texto puro', () {
      final hash = PasswordHasher.hash(
        password: 'senhaMuitoSecreta',
        salt: PasswordHasher.generateSalt(),
        iterations: iterations,
      );
      expect(hash.contains('senhaMuitoSecreta'), isFalse);
    });

    test('contagem de iterações diferente produz hash diferente', () {
      final salt = PasswordHasher.generateSalt();
      expect(
        PasswordHasher.hash(password: 'x', salt: salt, iterations: 1000),
        isNot(PasswordHasher.hash(password: 'x', salt: salt, iterations: 2000)),
      );
    });
  });

  group('PasswordHasher.verify', () {
    test('aceita a senha correta', () {
      final salt = PasswordHasher.generateSalt();
      final hash = PasswordHasher.hash(
        password: 'senha2026',
        salt: salt,
        iterations: iterations,
      );

      expect(
        PasswordHasher.verify(
          password: 'senha2026',
          salt: salt,
          expectedHash: hash,
          iterations: iterations,
        ),
        isTrue,
      );
    });

    test('rejeita senha errada, inclusive por diferença de caixa', () {
      final salt = PasswordHasher.generateSalt();
      final hash = PasswordHasher.hash(
        password: 'senha2026',
        salt: salt,
        iterations: iterations,
      );

      for (final wrong in <String>['senha2027', 'Senha2026', 'senha202', '']) {
        expect(
          PasswordHasher.verify(
            password: wrong,
            salt: salt,
            expectedHash: hash,
            iterations: iterations,
          ),
          isFalse,
          reason: 'não deveria aceitar "$wrong"',
        );
      }
    });

    test('rejeita hash de tamanho diferente sem lançar', () {
      expect(
        PasswordHasher.verify(
          password: 'senha2026',
          salt: PasswordHasher.generateSalt(),
          expectedHash: 'curto',
          iterations: iterations,
        ),
        isFalse,
      );
    });
  });

  group('PasswordHasher.generateSessionToken', () {
    test('gera tokens únicos e de tamanho razoável', () {
      final tokens = <String>{
        for (var i = 0; i < 20; i++) PasswordHasher.generateSessionToken(),
      };
      expect(tokens, hasLength(20));
      expect(tokens.first.length, greaterThanOrEqualTo(40));
    });
  });
}
