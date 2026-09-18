import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_message_banner.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Fecha o teclado antes de validar: o erro aparece acima do formulário e
    // ficaria escondido atrás do teclado.
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await ref.read(authControllerProvider.notifier).signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
    // Navegação é responsabilidade do guarda de rota: quando o estado vira
    // `authenticated`, o `redirect` leva ao dashboard. Chamar `context.go` aqui
    // duplicaria a decisão e criaria corrida com o redirect.
  }

  Future<void> _enterAsDemo() async {
    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).signInAsDemo();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              // Trava a largura para o formulário não esticar em tablet.
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _Header(theme: theme),
                      const SizedBox(height: 32),

                      if (auth.errorMessage != null) ...<Widget>[
                        AuthMessageBanner(message: auth.errorMessage!),
                        const SizedBox(height: 18),
                      ] else if (auth.infoMessage != null) ...<Widget>[
                        AuthMessageBanner(
                          message: auth.infoMessage!,
                          isError: false,
                        ),
                        const SizedBox(height: 18),
                      ],

                      CustomTextField(
                        label: 'E-mail',
                        hint: 'seu.email@exemplo.com',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        prefixIcon: Icons.email_outlined,
                        autofillHints: const <String>[AutofillHints.username],
                        validator: Validators.email,
                        onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                      ),
                      const SizedBox(height: 18),

                      CustomTextField(
                        label: 'Senha',
                        hint: '••••••••',
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        prefixIcon: Icons.lock_outline,
                        autofillHints: const <String>[AutofillHints.password],
                        validator: Validators.currentPassword,
                        onFieldSubmitted: (_) => _submit(),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push(AppRoutes.forgotPassword),
                          child: const Text('Esqueci minha senha'),
                        ),
                      ),
                      const SizedBox(height: 8),

                      CustomButton(
                        text: 'Entrar',
                        isLoading: auth.isBusyWith(AuthAction.signIn),
                        onPressed: auth.isBusy ? null : _submit,
                      ),
                      const SizedBox(height: 12),

                      CustomButton(
                        text: 'Explorar sem criar conta',
                        variant: ButtonVariant.outlined,
                        icon: Icons.play_circle_outline,
                        isLoading: auth.isBusyWith(AuthAction.signUpAndSignIn),
                        onPressed: auth.isBusy ? null : _enterAsDemo,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'A conta de demonstração vem com uma carteira de exemplo. '
                        'Você pode criar sua conta real depois.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                      ),
                      const SizedBox(height: 28),

                      // Wrap, e não Row: com fonte ampliada por acessibilidade o
                      // texto mais o botão não cabem em uma linha e estouravam a
                      // largura. Aqui o botão desce para a linha seguinte.
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text('Ainda não tem conta?', style: theme.textTheme.bodyMedium),
                          TextButton(
                            onPressed: () => context.push(AppRoutes.register),
                            child: const Text('Cadastre-se'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.account_balance_wallet_outlined,
            size: 38,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          AppConstants.appName,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          AppConstants.appTagline,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}
