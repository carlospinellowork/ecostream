import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_message_banner.dart';
import '../widgets/password_strength_meter.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _acceptedTerms = false;
  String _password = '';

  /// Só sinalizamos o aceite de termos em vermelho depois de uma tentativa de
  /// envio. Marcar o campo como errado antes de o usuário tentar é hostil.
  bool _submitAttempted = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitAttempted = true);

    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_acceptedTerms) return;

    await ref.read(authControllerProvider.notifier).signUp(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
    // O guarda de rota leva ao dashboard quando o cadastro conclui.
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'Comece a economizar hoje',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Centralize suas assinaturas, receba avisos antes da cobrança '
                        'e descubra onde está sobrando dinheiro.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 28),

                      if (auth.errorMessage != null) ...<Widget>[
                        AuthMessageBanner(message: auth.errorMessage!),
                        const SizedBox(height: 18),
                      ],

                      CustomTextField(
                        label: 'Nome',
                        hint: 'Como podemos te chamar',
                        controller: _nameController,
                        prefixIcon: Icons.person_outline,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const <String>[AutofillHints.name],
                        validator: Validators.fullName,
                      ),
                      const SizedBox(height: 18),

                      CustomTextField(
                        label: 'E-mail',
                        hint: 'seu.email@exemplo.com',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        prefixIcon: Icons.email_outlined,
                        autofillHints: const <String>[AutofillHints.email],
                        validator: Validators.email,
                      ),
                      const SizedBox(height: 18),

                      CustomTextField(
                        label: 'Senha',
                        hint: 'Mínimo ${Validators.minPasswordLength} caracteres',
                        helperText: 'Combine letras e números.',
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        prefixIcon: Icons.lock_outline,
                        autofillHints: const <String>[AutofillHints.newPassword],
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
                        label: 'Confirmar senha',
                        hint: 'Repita a senha',
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
                      const SizedBox(height: 20),

                      _TermsCheckbox(
                        value: _acceptedTerms,
                        showError: _submitAttempted && !_acceptedTerms,
                        onChanged: (value) =>
                            setState(() => _acceptedTerms = value ?? false),
                      ),
                      const SizedBox(height: 20),

                      // O botão segue habilitado mesmo sem o aceite: desabilitar
                      // sem explicar deixa o usuário travado sem saber por quê.
                      // Ao tocar, o texto dos termos fica em vermelho.
                      CustomButton(
                        text: 'Criar minha conta',
                        isLoading: auth.isBusyWith(AuthAction.signUp),
                        onPressed: auth.isBusy ? null : _submit,
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Seus dados ficam apenas neste aparelho. A senha é guardada '
                        'com criptografia e nunca em texto puro.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                      ),
                      const SizedBox(height: 24),
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

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({
    required this.value,
    required this.showError,
    required this.onChanged,
  });

  final bool value;
  final bool showError;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Li e aceito os Termos de Uso e a Política de Privacidade.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    color: showError
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (showError) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    'É necessário aceitar para criar a conta.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
