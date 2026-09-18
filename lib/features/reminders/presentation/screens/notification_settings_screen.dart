import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/custom_card.dart';
import '../../../../core/widgets/pro_badge.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../billing/domain/plan.dart';
import '../../../billing/presentation/controllers/entitlement_controller.dart';
import '../../../subscriptions/presentation/controllers/subscription_controller.dart';
import '../../domain/reminder.dart';
import '../controllers/reminder_controller.dart';

/// Preferências de lembrete de cobrança.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  /// Antecedências oferecidas. Só a véspera está liberada no plano gratuito.
  static const List<int> _leadOptions = <int>[7, 3, 1, 0];

  static String _leadLabel(int days) => switch (days) {
        0 => 'No dia da cobrança',
        1 => 'Um dia antes',
        _ => '$days dias antes',
      };

  Future<void> _apply(
    WidgetRef ref,
    ReminderSettings settings,
  ) async {
    final controller = ref.read(reminderControllerProvider.notifier);
    final entitlements = ref.read(entitlementsProvider);
    final subscriptions = ref.read(activeSubscriptionsProvider);

    await controller.updateSettings(
      controller.normalizeForPlan(settings, entitlements),
      subscriptions: subscriptions,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(reminderControllerProvider);
    final settings = state.settings;
    final canCustomize = ref.watch(entitlementsProvider).can(Feature.customReminders);

    return Scaffold(
      appBar: AppBar(title: const Text('Lembretes de cobrança')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: <Widget>[
          CustomCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Receber lembretes'),
              subtitle: const Text(
                'Avisamos antes de cada cobrança para você ter tempo de cancelar.',
              ),
              value: settings.enabled,
              onChanged: (value) => _apply(ref, settings.copyWith(enabled: value)),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: <Widget>[
              const Expanded(child: SectionHeader(title: 'Quando avisar')),
              if (!canCustomize) const ProBadge(compact: true),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            canCustomize
                ? 'Escolha quantos avisos quer receber para cada cobrança.'
                : 'O plano gratuito avisa um dia antes. O Pro permite combinar vários '
                    'avisos — por exemplo, uma semana antes e de novo na véspera.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),

          CustomCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              children: _leadOptions.map((days) {
                final selected = settings.leadDays.contains(days);
                final locked = !canCustomize && days != FreePlanLimits.fixedReminderLeadDays;

                return CheckboxListTile(
                  title: Text(_leadLabel(days)),
                  value: selected,
                  secondary: locked ? const ProBadge(compact: true) : null,
                  onChanged: !settings.enabled || locked
                      ? null
                      : (value) {
                          final next = settings.leadDays.toSet();
                          if (value ?? false) {
                            next.add(days);
                          } else {
                            next.remove(days);
                          }
                          // Desmarcar tudo silenciaria os avisos sem o usuário
                          // perceber; o interruptor geral é o lugar para isso.
                          if (next.isEmpty) return;
                          _apply(
                            ref,
                            settings.copyWith(
                              leadDays: next.toList(growable: false)..sort(),
                            ),
                          );
                        },
                );
              }).toList(growable: false),
            ),
          ),

          if (!canCustomize) ...<Widget>[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('${AppRoutes.paywall}?origem=lembretes'),
              icon: const Icon(Icons.workspace_premium_outlined, size: 18),
              label: const Text('Desbloquear múltiplos avisos'),
            ),
          ],
          const SizedBox(height: 24),

          const SectionHeader(title: 'Horário'),
          const SizedBox(height: 12),
          CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${settings.hourOfDay.toString().padLeft(2, '0')}:00',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Horário em que os avisos são enviados.',
                  style: theme.textTheme.bodySmall,
                ),
                Slider(
                  value: settings.hourOfDay.toDouble(),
                  max: 23,
                  divisions: 23,
                  label: '${settings.hourOfDay}h',
                  onChanged: settings.enabled
                      ? (value) =>
                          _apply(ref, settings.copyWith(hourOfDay: value.round()))
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const SectionHeader(title: 'Outros avisos'),
          const SizedBox(height: 12),
          CustomCard(
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aumento de preço'),
                  subtitle: const Text(
                    'Avisar quando uma assinatura ficar mais cara.',
                  ),
                  value: settings.notifyPriceIncrease,
                  onChanged: settings.enabled
                      ? (value) => _apply(
                            ref,
                            settings.copyWith(notifyPriceIncrease: value),
                          )
                      : null,
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Resumo semanal'),
                  subtitle: const Text(
                    'Um resumo dos gastos e cobranças da semana, toda segunda.',
                  ),
                  value: settings.notifyWeeklyDigest,
                  onChanged: settings.enabled
                      ? (value) => _apply(
                            ref,
                            settings.copyWith(notifyWeeklyDigest: value),
                          )
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _ScheduledPreview(reminders: state.scheduled),
        ],
      ),
    );
  }
}

/// Mostra os próximos lembretes já calculados.
///
/// Serve de prova para o usuário de que a configuração surtiu efeito — e de
/// diagnóstico para quem desenvolve, enquanto o disparo real não está plugado.
class _ScheduledPreview extends StatelessWidget {
  const _ScheduledPreview({required this.reminders});

  final List<ScheduledReminder> reminders;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = reminders.take(5).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(title: 'Próximos avisos'),
        const SizedBox(height: 4),
        Text(
          'Prévia do que está agendado a partir das suas assinaturas ativas.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        CustomCard(
          child: next.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Nenhum aviso agendado no momento.',
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              : Column(
                  children: next.map((reminder) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.notifications_none_rounded,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              reminder.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          Text(
                            DateFormatter.dayMonth(reminder.scheduledFor),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    );
                  }).toList(growable: false),
                ),
        ),
      ],
    );
  }
}
