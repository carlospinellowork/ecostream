import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_message_banner.dart';
import '../widgets/password_strength_meter.dart';

/// Redefinição de senha.
///
/// Sem backend não há envio de e-mail, então o fluxo é uma **redefinição local**:
/// só funciona para contas criadas neste aparelho. A tela diz isso abertamente em
/// vez de simular um "enviamos um link" que nunca chega — prometer um e-mail que não
/// existe é pior do que assumir a limitação.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  String _password = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final success = await ref.read(authControllerProvider.notifier).resetPassword(
          email: _emailController.text,
          newPassword: _passwordController.text,
        );

    if (!success || !mounted) return;
    // A mensagem de sucesso fica no estado de auth e aparece na tela de login.
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Redefinir senha')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Defina uma nova senha',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Como o EcoStream guarda seus dados apenas neste aparelho, a '
                      'redefinição acontece aqui mesmo — sem e-mail de confirmação. '
                      'Informe o e-mail da conta criada neste celular.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 28),

                    if (auth.errorMessage != null) ...<Widget>[
                      AuthMessageBanner(message: auth.errorMessage!),
                      const SizedBox(height: 18),
                    ],

                    CustomTextField(
                      label: 'E-mail da conta',
                      hint: 'seu.email@exemplo.com',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.email_outlined,
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 18),

                    CustomTextField(
                      label: 'Nova senha',
                      hint: 'Mínimo ${Validators.minPasswordLength} caracteres',
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.lock_outline,
                      validator: Validators.newPassword,
                      onChanged: (value) => setState(() => _password = value),
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
                    PasswordStrengthMeter(password: _password),
                    const SizedBox(height: 18),

                    CustomTextField(
                      label: 'Confirmar nova senha',
                      controller: _confirmController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      prefixIcon: Icons.lock_reset_outlined,
                      validator: (value) => Validators.passwordConfirmation(
                        value,
                        _passwordController.text,
                      ),
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 28),

                    CustomButton(
                      text: 'Redefinir senha',
                      isLoading: auth.isBusyWith(AuthAction.resetPassword),
                      onPressed: auth.isBusy ? null : _submit,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
