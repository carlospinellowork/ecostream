import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_card.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final themeModeNotifier = ref.read(themeModeProvider.notifier);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Perfil'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Cartão de Perfil do Usuário
            CustomCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    child: Text(
                      user?.name.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Usuário EcoStream',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? 'usuario@ecostream.app',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Plano MVP Free',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Seção de Aparência e Tema
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Aparência',
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 16),
              ),
            ),
            const SizedBox(height: 10),

            CustomCard(
              child: Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: const Text('Seguir o Sistema'),
                    subtitle: const Text('Ajusta o tema de acordo com seu celular'),
                    value: ThemeMode.system,
                    groupValue: themeMode,
                    activeColor: AppColors.primary,
                    onChanged: (mode) {
                      if (mode != null) themeModeNotifier.setThemeMode(mode);
                    },
                  ),
                  const Divider(height: 1),
                  RadioListTile<ThemeMode>(
                    title: const Text('Modo Claro (Light Mode)'),
                    value: ThemeMode.light,
                    groupValue: themeMode,
                    activeColor: AppColors.primary,
                    onChanged: (mode) {
                      if (mode != null) themeModeNotifier.setThemeMode(mode);
                    },
                  ),
                  const Divider(height: 1),
                  RadioListTile<ThemeMode>(
                    title: const Text('Modo Escuro (Dark Mode)'),
                    value: ThemeMode.dark,
                    groupValue: themeMode,
                    activeColor: AppColors.primary,
                    onChanged: (mode) {
                      if (mode != null) themeModeNotifier.setThemeMode(mode);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Configurações Adicionais
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Preferências',
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 16),
              ),
            ),
            const SizedBox(height: 10),

            CustomCard(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Notificações de Cobrança'),
                    subtitle: const Text('Receber alertas de vencimento com 1 dia de antecedência'),
                    value: true,
                    activeColor: AppColors.primary,
                    onChanged: (val) {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.security_outlined, color: AppColors.primary),
                    title: const Text('Segurança e Dados'),
                    subtitle: const Text('Criptografia e políticas de privacidade'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.star_outline, color: AppColors.warning),
                    title: const Text('Conheça o EcoStream Pro'),
                    subtitle: const Text('Assinaturas ilimitadas, relatórios avançados'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Botão de Sair
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.error, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.logout, color: AppColors.error),
                label: const Text(
                  'Sair da Conta',
                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                onPressed: () {
                  ref.read(authControllerProvider.notifier).logout();
                  context.go('/login');
                },
              ),
            ),
            const SizedBox(height: 20),

            Text(
              '${AppConstants.appName} v1.0.0 • MVP Release',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
