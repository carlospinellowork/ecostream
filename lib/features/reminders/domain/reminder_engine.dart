import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/recurrence.dart';
import '../../subscriptions/domain/subscription_model.dart';
import 'reminder.dart';

/// Decide **o que** avisar e **quando**.
///
/// Puro e determinístico: não toca em plugin, plataforma nem I/O. Quem efetivamente
/// agenda é o `NotificationService`. Essa separação é o que permite testar a regra
/// inteira — incluindo casos como "a cobrança é amanhã, o aviso de 3 dias já passou"
/// — sem emulador (CLAUDE.md §9).
class ReminderEngine {
  const ReminderEngine();

  /// Monta todos os lembretes que devem existir para [subscriptions].
  ///
  /// Lembretes cujo horário já passou são descartados: agendar no passado ou dispara
  /// imediatamente (assustando o usuário) ou é silenciosamente ignorado pelo sistema.
  List<ScheduledReminder> buildSchedule({
    required List<SubscriptionModel> subscriptions,
    required ReminderSettings settings,
    required DateTime now,
  }) {
    if (!settings.enabled) return const <ScheduledReminder>[];

    final reminders = <ScheduledReminder>[];

    for (final sub in subscriptions) {
      if (!sub.isActive) continue;

      for (final lead in settings.leadDays) {
        final fireDate = _fireDateTime(
          billingDate: sub.nextBillingDate,
          leadDays: lead,
          hourOfDay: settings.hourOfDay,
        );
        if (!fireDate.isAfter(now)) continue;

        reminders.add(
          ScheduledReminder(
            id: '${sub.id}_d$lead',
            subscriptionId: sub.id,
            scheduledFor: fireDate,
            title: _title(sub, lead),
            body: _body(sub, lead),
          ),
        );
      }
    }

    reminders.sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
    return List<ScheduledReminder>.unmodifiable(reminders);
  }

  /// Momento exato do disparo: [leadDays] antes da cobrança, às [hourOfDay].
  static DateTime _fireDateTime({
    required DateTime billingDate,
    required int leadDays,
    required int hourOfDay,
  }) {
    final date = Recurrence.dateOnly(billingDate).subtract(Duration(days: leadDays));
    return DateTime(date.year, date.month, date.day, hourOfDay.clamp(0, 23));
  }

  static String _title(SubscriptionModel sub, int leadDays) {
    return switch (leadDays) {
      0 => '${sub.name} é cobrado hoje',
      1 => '${sub.name} é cobrado amanhã',
      _ => '${sub.name} é cobrado em $leadDays dias',
    };
  }

  static String _body(SubscriptionModel sub, int leadDays) {
    final amount = CurrencyFormatter.format(sub.price);
    final when = switch (leadDays) {
      0 => 'hoje',
      1 => 'amanhã',
      _ => 'em $leadDays dias',
    };

    // Para serviço sem uso, o aviso vira oportunidade de corte em vez de só informar.
    if (sub.usageLevel == UsageLevel.never || sub.usageLevel == UsageLevel.low) {
      return '$amount serão debitados $when. Você marcou este serviço como pouco '
          'usado — ainda dá tempo de cancelar.';
    }
    return '$amount serão debitados $when no ${sub.paymentMethod.toLowerCase()}.';
  }
}
