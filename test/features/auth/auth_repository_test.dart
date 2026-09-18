import 'package:ecostream/core/error/app_exception.dart';
import 'package:ecostream/core/error/result.dart';
import 'package:ecostream/core/storage/key_value_store.dart';
import 'package:ecostream/core/storage/secure_store.dart';
import 'package:ecostream/features/auth/data/auth_local_data_source.dart';
import 'package:ecostream/features/auth/data/auth_repository.dart';
import 'package:ecostream/features/auth/domain/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryKeyValueStore store;
  late InMemorySecureStore secureStore;
  late LocalAuthRepository repository;

  setUp(() {
    store = InMemoryKeyValueStore();
    secureStore = InMemorySecureStore();
    repository = LocalAuthRepository(
      dataSource: AuthLocalDataSource(store: store, secureStore: secureStore),
      // O custo de produção (120k iterações) faria esta suíte levar minutos.
      iterations: 1000,
    );
  });

  Future<UserModel> createAccount({
    String email = 'carlos@ecostream.app',
    String password = 'senha2026',
    String name = 'Carlos Eduardo',
  }) async {
    final result = await repository.signUp(
      name: name,
      email: email,
      password: password,
    );
    return (result as Ok<UserModel>).value;
  }

  group('signUp', () {
    test('cria a conta e inicia a sessão', () async {
      final result = await repository.signUp(
        name: 'Carlos Eduardo',
        email: 'carlos@ecostream.app',
        password: 'senha2026',
      );

      expect(result.isOk, isTrue);
      final user = result.valueOrNull!;
      expect(user.email, 'carlos@ecostream.app');
      expect(user.name, 'Carlos Eduardo');

      final restored = await repository.restoreSession();
      expect(restored.valueOrNull?.id, user.id);
    });

    test('normaliza o e-mail para minúsculas', () async {
      final user = await createAccount(email: 'Carlos@EcoStream.App');
      expect(user.email, 'carlos@ecostream.app');
    });

    test('rejeita e-mail já cadastrado, inclusive com outra caixa', () async {
      await createAccount(email: 'carlos@ecostream.app');
      final result = await repository.signUp(
        name: 'Outro',
        email: 'CARLOS@ECOSTREAM.APP',
        password: 'outrasenha1',
      );

      expect(result.isErr, isTrue);
      expect(result.errorOrNull, isA<AuthException>());
    });

    test('rejeita senha fraca', () async {
      final result = await repository.signUp(
        name: 'Carlos',
        email: 'novo@ecostream.app',
        password: '123',
      );
      expect(result.isErr, isTrue);
    });

    test('rejeita e-mail inválido', () async {
      final result = await repository.signUp(
        name: 'Carlos',
        email: 'sem-arroba',
        password: 'senha2026',
      );
      expect(result.isErr, isTrue);
      expect(result.errorOrNull, isA<ValidationException>());
    });

    test('nunca grava a senha em texto puro', () async {
      final user = await createAccount(password: 'senhaSuperSecreta1');

      // Nem no armazenamento comum...
      for (final entry in <String?>[
        store.getString('auth.accounts'),
        store.getString('auth.active_user_id'),
      ]) {
        expect(entry?.contains('senhaSuperSecreta1') ?? false, isFalse);
      }

      // ...nem no seguro.
      final credential = await secureStore.read('auth.credential.${user.id}');
      expect(credential, isNotNull);
      expect(credential!.contains('senhaSuperSecreta1'), isFalse);
    });
  });

  group('signIn', () {
    test('autentica com as credenciais corretas', () async {
      await createAccount();
      await repository.signOut();

      final result = await repository.signIn(
        email: 'carlos@ecostream.app',
        password: 'senha2026',
      );
      expect(result.isOk, isTrue);
    });

    test('aceita e-mail digitado com outra caixa e espaços', () async {
      await createAccount();
      await repository.signOut();

      final result = await repository.signIn(
        email: '  CARLOS@ecostream.APP ',
        password: 'senha2026',
      );
      expect(result.isOk, isTrue);
    });

    test('rejeita senha errada', () async {
      await createAccount();
      final result = await repository.signIn(
        email: 'carlos@ecostream.app',
        password: 'senhaErrada1',
      );
      expect(result.isErr, isTrue);
    });

    test('conta inexistente devolve a mesma mensagem de senha errada', () async {
      // Mensagens distintas permitiriam descobrir quais e-mails têm conta.
      await createAccount();

      final wrongPassword = await repository.signIn(
        email: 'carlos@ecostream.app',
        password: 'errada1',
      );
      final noAccount = await repository.signIn(
        email: 'ninguem@ecostream.app',
        password: 'errada1',
      );

      expect(wrongPassword.errorOrNull?.message, noAccount.errorOrNull?.message);
    });
  });

  group('restoreSession', () {
    test('devolve null quando ninguém está logado', () async {
      final result = await repository.restoreSession();
      expect(result.isOk, isTrue);
      expect(result.valueOrNull, isNull);
    });

    test('devolve null e limpa a sessão se o token seguro desapareceu', () async {
      // Cenário real: restore de backup do aparelho preserva SharedPreferences
      // mas invalida o Keystore.
      await createAccount();
      await secureStore.delete('auth.session_token');

      final result = await repository.restoreSession();
      expect(result.valueOrNull, isNull);
      expect(store.getString('auth.active_user_id'), isNull);
    });

    test('devolve null se a conta referenciada não existe mais', () async {
      await createAccount();
      await store.remove('auth.accounts');

      final result = await repository.restoreSession();
      expect(result.valueOrNull, isNull);
    });
  });

  group('signOut', () {
    test('encerra a sessão sem apagar a conta', () async {
      await createAccount();
      await repository.signOut();

      expect((await repository.restoreSession()).valueOrNull, isNull);

      final again = await repository.signIn(
        email: 'carlos@ecostream.app',
        password: 'senha2026',
      );
      expect(again.isOk, isTrue);
    });
  });

  group('resetPassword', () {
    test('troca a senha e invalida a sessão', () async {
      await createAccount();

      final reset = await repository.resetPassword(
        email: 'carlos@ecostream.app',
        newPassword: 'novaSenha2026',
      );
      expect(reset.isOk, isTrue);
      expect((await repository.restoreSession()).valueOrNull, isNull);

      expect(
        (await repository.signIn(
          email: 'carlos@ecostream.app',
          password: 'senha2026',
        ))
            .isErr,
        isTrue,
      );
      expect(
        (await repository.signIn(
          email: 'carlos@ecostream.app',
          password: 'novaSenha2026',
        ))
            .isOk,
        isTrue,
      );
    });

    test('rejeita conta inexistente', () async {
      final result = await repository.resetPassword(
        email: 'ninguem@ecostream.app',
        newPassword: 'novaSenha2026',
      );
      expect(result.isErr, isTrue);
    });

    test('rejeita senha nova fraca', () async {
      await createAccount();
      final result = await repository.resetPassword(
        email: 'carlos@ecostream.app',
        newPassword: '123',
      );
      expect(result.isErr, isTrue);
    });
  });

  group('updateProfile', () {
    test('atualiza o nome', () async {
      final user = await createAccount();
      final result = await repository.updateProfile(
        userId: user.id,
        name: 'Carlos Pinello',
      );
      expect(result.valueOrNull?.name, 'Carlos Pinello');
    });

    test('nome em branco preserva o valor atual', () async {
      final user = await createAccount(name: 'Carlos Eduardo');
      final result = await repository.updateProfile(userId: user.id, name: '   ');
      expect(result.valueOrNull?.name, 'Carlos Eduardo');
    });
  });

  group('deleteAccount', () {
    test('apaga a conta, a credencial e os dados do usuário', () async {
      final user = await createAccount();
      await store.setJsonList('data.subscriptions.${user.id}', <Map<String, dynamic>>[
        <String, dynamic>{'id': 'sub_1'},
      ]);

      final result = await repository.deleteAccount(user.id);
      expect(result.isOk, isTrue);

      expect(await secureStore.read('auth.credential.${user.id}'), isNull);
      expect(store.getJsonList('data.subscriptions.${user.id}'), isEmpty);
      expect((await repository.restoreSession()).valueOrNull, isNull);

      final signIn = await repository.signIn(
        email: 'carlos@ecostream.app',
        password: 'senha2026',
      );
      expect(signIn.isErr, isTrue);
    });
  });

  group('múltiplas contas no mesmo aparelho', () {
    test('cada conta entra com a própria senha', () async {
      await createAccount(email: 'a@ecostream.app', password: 'senhaA2026');
      await repository.signOut();
      await createAccount(email: 'b@ecostream.app', password: 'senhaB2026');
      await repository.signOut();

      expect(
        (await repository.signIn(email: 'a@ecostream.app', password: 'senhaA2026')).isOk,
        isTrue,
      );
      expect(
        (await repository.signIn(email: 'b@ecostream.app', password: 'senhaA2026')).isErr,
        isTrue,
      );
    });
  });
}
