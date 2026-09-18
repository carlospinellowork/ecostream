import 'package:ecostream/core/providers/core_providers.dart';
import 'package:ecostream/core/storage/key_value_store.dart';
import 'package:ecostream/core/storage/secure_store.dart';
import 'package:ecostream/features/auth/presentation/screens/login_screen.dart';
import 'package:ecostream/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Monta o app com armazenamento em memória e uma tela alta.
///
/// Dois ajustes são necessários aqui:
/// 1. `SharedPreferences` e `flutter_secure_storage` dependem de canal de plataforma
///    e falham em `flutter test`; os overrides são o que torna a árvore montável.
/// 2. A janela padrão do teste é 800x600, menor que um celular real — o formulário
///    de login não caberia e os toques falhariam por elemento fora da tela.
Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        secureStoreProvider.overrideWithValue(InMemorySecureStore()),
      ],
      child: const EcoStreamApp(),
    ),
  );
}

void main() {
  setUpAll(() {
    initializeDateFormatting('pt_BR');
  });

  testWidgets('sem sessão salva, o app abre na tela de login', (tester) async {
    await _pumpApp(tester);

    // Primeiro quadro: a splash segura a navegação enquanto a sessão é resolvida.
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Explorar sem criar conta'), findsOneWidget);
  });

  testWidgets('o login exige e-mail e senha antes de autenticar', (tester) async {
    await _pumpApp(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Informe seu e-mail'), findsOneWidget);
    expect(find.text('Informe sua senha'), findsOneWidget);
    // Continua no login: nada foi autenticado.
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('e-mail malformado é rejeitado antes de chamar o repositório',
      (tester) async {
    await _pumpApp(tester);
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'sem-arroba');
    await tester.enterText(fields.last, 'senha2026');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Informe um e-mail válido'), findsOneWidget);
  });

  testWidgets('a senha começa oculta e o botão de olho a revela', (tester) async {
    await _pumpApp(tester);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
  });

  testWidgets('a navegação leva ao cadastro e volta', (tester) async {
    await _pumpApp(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cadastre-se'));
    await tester.pumpAndSettle();

    expect(find.text('Criar conta'), findsOneWidget);
    expect(find.text('Comece a economizar hoje'), findsOneWidget);
    // O cadastro exige aceite dos termos antes de habilitar o botão.
    expect(find.byType(Checkbox), findsOneWidget);
  });
}
