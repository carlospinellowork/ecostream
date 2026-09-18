import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/custom_card.dart';
import '../../../../core/widgets/pro_badge.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../billing/domain/plan.dart';
import '../../../billing/presentation/controllers/entitlement_controller.dart';
import '../../../insights/presentation/controllers/insights_controller.dart';
import '../../../subscriptions/presentation/controllers/subscription_controller.dart';
import '../widgets/csv_export_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text(
          'Seus dados continuam salvos neste aparelho. Você precisará entrar '
          'novamente com e-mail e senha.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(authControllerProvider.notifier).signOut();
    // O guarda de rota redireciona para o login ao detectar a sessão encerrada.
  }

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir minha conta'),
        content: const Text(
          'Esta ação apaga permanentemente sua conta, suas assinaturas e seu '
          'histórico deste aparelho. Não há como desfazer.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir tudo'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(authControllerProvider.notifier).deleteAccount();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final entitlements = ref.watch(entitlementsProvider);
    final isPro = ref.watch(isProProvider);
    final themeMode = ref.watch(themeModeProvider);
    final subState = ref.watch(subscriptionControllerProvider);
    final savings = ref.watch(potentialAnnualSavingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Meu perfil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: <Widget>[
          CustomCard(
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    user?.initials ?? 'U',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        user?.name ?? 'Usuário EcoStream',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(fontSize: 17),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      if (isPro)
                        const ProBadge(label: 'PRO ATIVO')
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'PLANO GRATUITO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _PlanCard(
            isPro: isPro,
            daysRemaining: entitlements.daysRemaining(),
            isInTrial: entitlements.isInTrial(),
            annualSavings: savings,
            activeCount: subState.activeCount,
          ),
          const SizedBox(height: 24),

          const SectionHeader(title: 'Avisos'),
          const SizedBox(height: 10),
          CustomCard(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ListTile(
              leading: const Icon(
                Icons.notifications_active_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Lembretes de cobrança'),
              subtitle: const Text('Antecedência, horário e tipos de aviso'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.notificationSettings),
            ),
          ),
          const SizedBox(height: 24),

          const SectionHeader(title: 'Aparência'),
          const SizedBox(height: 10),
          CustomCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              children: ThemeMode.values.map((mode) {
                return RadioListTile<ThemeMode>(
                  title: Text(_themeLabel(mode)),
                  subtitle: mode == ThemeMode.system
                      ? const Text('Acompanha a configuração do aparelho')
                      : null,
                  value: mode,
                  groupValue: themeMode,
                  onChanged: (value) {
                    if (value == null) return;
                    ref.read(themeModeProvider.notifier).setThemeMode(value);
                  },
                );
              }).toList(growable: false),
            ),
          ),
          const SizedBox(height: 24),

          const SectionHeader(title: 'Dados'),
          const SizedBox(height: 10),
          CustomCard(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.download_outlined, color: AppColors.info),
                  title: const Text('Exportar em CSV'),
                  subtitle: Text(
                    isPro
                        ? 'Leve seus dados para a planilha'
                        : 'Disponível no EcoStream Pro',
                  ),
                  trailing: isPro
                      ? const Icon(Icons.chevron_right)
                      : const ProBadge(compact: true),
                  onTap: () {
                    if (!isPro) {
                      context.push('${AppRoutes.paywall}?origem=exportacao');
                      return;
                    }
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const CsvExportSheet(),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.security_outlined,
                    color: AppColors.success,
                  ),
                  title: const Text('Privacidade e segurança'),
                  subtitle: const Text('Onde seus dados ficam guardados'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showPrivacyInfo(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const SectionHeader(title: 'Conta'),
          const SizedBox(height: 10),
          CustomCard(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.warning),
                  title: const Text('Sair da conta'),
                  onTap: () => _confirmSignOut(context, ref),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever_outlined,
                    color: AppColors.error,
                  ),
                  title: const Text(
                    'Excluir minha conta',
                    style: TextStyle(color: AppColors.error),
                  ),
                  subtitle: const Text('Apaga tudo deste aparelho'),
                  onTap: () => _confirmDeleteAccount(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Center(
            child: Column(
              children: <Widget>[
                Text(
                  '${AppConstants.appName} ${AppConstants.appVersion}',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                ),
                if (user != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    'Conta criada em ${DateFormatter.short(user.createdAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'Seguir o sistema',
        ThemeMode.light => 'Modo claro',
        ThemeMode.dark => 'Modo escuro',
      };

  static void _showPrivacyInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Privacidade e segurança'),
        content: const SingleChildScrollView(
          child: Text(
            'O EcoStream não envia seus dados para nenhum servidor. Tudo fica '
            'guardado apenas neste aparelho.\n\n'
            '• Assinaturas e preferências: armazenamento local do app.\n'
            '• Senha: nunca guardada em texto puro. Gravamos apenas um hash '
            'PBKDF2 com salt individual, no Keystore (Android) ou Keychain (iOS).\n'
            '• Token de sessão: também no armazenamento seguro do sistema.\n\n'
            'Como não há sincronização, desinstalar o app apaga seus dados. '
            'Use a exportação em CSV para guardar uma cópia.',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }
}

/// Cartão do plano atual, com o argumento de upgrade quando aplicável.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.isPro,
    required this.daysRemaining,
    required this.isInTrial,
    required this.annualSavings,
    required this.activeCount,
  });

  final bool isPro;
  final int? daysRemaining;
  final bool isInTrial;
  final double annualSavings;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isPro) {
      return CustomCard(
        backgroundColor: AppColors.pro.withValues(alpha: 0.08),
        borderColor: AppColors.pro.withValues(alpha: 0.3),
        child: Row(
          children: <Widget>[
            const Icon(Icons.workspace_premium_rounded, color: AppColors.pro, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    isInTrial ? 'Teste do Pro ativo' : 'EcoStream Pro ativo',
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    daysRemaining == null
                        ? 'Todos os recursos liberados.'
                        : 'Válido por mais $daysRemaining '
                            '${daysRemaining == 1 ? 'dia' : 'dias'}.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final overLimit = activeCount >= FreePlanLimits.maxSubscriptions;

    return CustomCard(
      elevated: true,
      onTap: () => context.push('${AppRoutes.paywall}?origem=perfil'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.workspace_premium_outlined,
                color: AppColors.pro,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Conheça o EcoStream Pro',
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.pro),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            annualSavings > 0
                ? 'Identificamos ${CurrencyFormatter.format(annualSavings)} por ano de '
                    'economia possível. O Pro mostra exatamente onde cortar.'
                : overLimit
                    ? 'Você já usa as ${FreePlanLimits.maxSubscriptions} assinaturas do '
                        'plano gratuito. O Pro libera quantidade ilimitada.'
                    : 'Assinaturas ilimitadas, insights completos, lembretes '
                        'personalizados e exportação em CSV.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
