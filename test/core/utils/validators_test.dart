import 'package:ecostream/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.email', () {
    test('aceita endereços válidos', () {
      for (final email in <String>[
        'carlos@ecostream.app',
        'carlos.pinello@gruporzk.com.br',
        'a+tag@dominio.co',
        'nome_sobrenome@sub.dominio.com',
      ]) {
        expect(Validators.email(email), isNull, reason: 'deveria aceitar $email');
      }
    });

    test('rejeita endereços inválidos', () {
      for (final email in <String>[
        '',
        'sem-arroba',
        'sem@dominio',
        'sem@.com',
        'com espaco@dominio.com',
        '@dominio.com',
        'duplo@@dominio.com',
      ]) {
        expect(Validators.email(email), isNotNull, reason: 'deveria rejeitar "$email"');
      }
    });

    test('ignora espaços em volta', () {
      expect(Validators.email('  carlos@ecostream.app  '), isNull);
    });
  });

  group('Validators.newPassword', () {
    test('exige o comprimento mínimo', () {
      expect(Validators.newPassword('abc1'), isNotNull);
      expect(Validators.newPassword('senha12'), isNotNull);
      expect(Validators.newPassword('senha123'), isNull);
    });

    test('exige letras e números', () {
      expect(Validators.newPassword('12345678'), isNotNull);
      expect(Validators.newPassword('senhasenha'), isNotNull);
      expect(Validators.newPassword('senha2026'), isNull);
    });

    test('rejeita vazio', () {
      expect(Validators.newPassword(''), isNotNull);
      expect(Validators.newPassword(null), isNotNull);
    });
  });

  group('Validators.currentPassword', () {
    test('só checa presença, sem revelar a regra de formato', () {
      // No login, dizer "sua senha precisa de números" ajudaria quem está
      // tentando adivinhar credenciais.
      expect(Validators.currentPassword('123'), isNull);
      expect(Validators.currentPassword(''), isNotNull);
    });
  });

  group('Validators.passwordConfirmation', () {
    test('rejeita quando difere da original', () {
      expect(Validators.passwordConfirmation('abc', 'abd'), isNotNull);
      expect(Validators.passwordConfirmation('abc', 'abc'), isNull);
    });
  });

  group('Validators.parsePrice', () {
    test('aceita vírgula como separador decimal (teclado brasileiro)', () {
      expect(Validators.parsePrice('59,90'), closeTo(59.90, 0.001));
    });

    test('aceita ponto como separador decimal (teclado iOS)', () {
      expect(Validators.parsePrice('59.90'), closeTo(59.90, 0.001));
    });

    test('aceita separador de milhar', () {
      expect(Validators.parsePrice('1.234,56'), closeTo(1234.56, 0.001));
    });

    test('ignora símbolo de moeda e espaços', () {
      expect(Validators.parsePrice(r'R$ 119,90'), closeTo(119.90, 0.001));
    });

    test('devolve null para texto não numérico', () {
      expect(Validators.parsePrice('abc'), isNull);
      expect(Validators.parsePrice(''), isNull);
    });
  });

  group('Validators.price', () {
    test('rejeita zero e negativos', () {
      expect(Validators.price('0'), isNotNull);
      expect(Validators.price('-10'), isNotNull);
    });

    test('rejeita valor acima do limite', () {
      expect(Validators.price('9999999'), isNotNull);
    });

    test('aceita valor comum', () {
      expect(Validators.price('59,90'), isNull);
    });
  });

  group('PasswordStrength', () {
    test('senha vazia não exibe medidor', () {
      expect(PasswordStrength.of(''), PasswordStrength.none);
    });

    test('senha curta é sempre fraca, mesmo com variedade', () {
      expect(PasswordStrength.of(r'aA1!'), PasswordStrength.weak);
    });

    test('senha longa e variada é forte', () {
      expect(PasswordStrength.of(r'EcoStream2026!x'), PasswordStrength.strong);
    });

    test('força cresce com a variedade de caracteres', () {
      final onlyLower = PasswordStrength.of('senhasenha');
      final withDigits = PasswordStrength.of('senhasenha1');
      final withUpperAndSymbol = PasswordStrength.of(r'SenhaSenha1!');

      expect(onlyLower.index, lessThan(withDigits.index));
      expect(withDigits.index, lessThanOrEqualTo(withUpperAndSymbol.index));
    });
  });
}
