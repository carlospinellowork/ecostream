import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/recurrence.dart';
import '../../../../core/widgets/custom_card.dart';
import '../../../categories/domain/category_model.dart';
import '../../../subscriptions/domain/subscription_model.dart';
import '../../../subscriptions/presentation/controllers/subscription_controller.dart';

/// Calendário de cobranças.
///
/// Projeta as cobranças recorrentes de cada assinatura dentro do mês visualizado,
/// em vez de marcar apenas a `nextBillingDate`. Antes, ao avançar para o mês
/// seguinte, o calendário aparecia vazio — as cobranças existem todo mês, mas só a
/// próxima estava mapeada.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  CalendarFormat _format = CalendarFormat.month;
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final today = Recurrence.dateOnly(DateTime.now());
    _focusedDay = today;
    _selectedDay = today;
  }

  /// Cobranças por dia dentro do mês de [month].
  Map<DateTime, List<SubscriptionModel>> _eventsForMonth(
    List<SubscriptionModel> subscriptions,
    DateTime month,
  ) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1, 0);
    final events = <DateTime, List<SubscriptionModel>>{};

    for (final sub in subscriptions) {
      final occurrences = Recurrence.occurrencesBetween(
        firstBillingDate: sub.nextBillingDate,
        cycle: sub.cycle,
        start: start,
        end: end,
        anchorDay: sub.billingDay,
      );
      for (final date in occurrences) {
        events.putIfAbsent(date, () => <SubscriptionModel>[]).add(sub);
      }
    }

    return events;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subscriptions = ref.watch(activeSubscriptionsProvider);
    final events = _eventsForMonth(subscriptions, _focusedDay);

    List<SubscriptionModel> eventsOf(DateTime day) =>
        events[Recurrence.dateOnly(day)] ?? const <SubscriptionModel>[];

    final selectedEvents = eventsOf(_selectedDay);

    // Total previsto no mês visualizado: soma de todas as ocorrências projetadas,
    // que é diferente do "gasto mensal equivalente" do dashboard.
    final monthTotal = events.values
        .expand((list) => list)
        .fold<double>(0, (sum, sub) => sum + sub.price);

    return Scaffold(
      appBar: AppBar(title: const Text('Calendário de cobranças')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: CustomCard(
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderColor: theme.colorScheme.primary.withValues(alpha: 0.28),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Previsto em ${DateFormatter.monthYearCapitalized(_focusedDay)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.format(monthTotal),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        '${events.values.fold<int>(0, (sum, l) => sum + l.length)}',
                        style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
                      ),
                      Text('cobranças', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
          ),

          TableCalendar<SubscriptionModel>(
            locale: 'pt_BR',
            firstDay: DateTime(DateTime.now().year - 2),
            lastDay: DateTime(DateTime.now().year + 3, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _format,
            startingDayOfWeek: StartingDayOfWeek.sunday,
            availableCalendarFormats: const <CalendarFormat, String>{
              CalendarFormat.month: 'Mês',
              CalendarFormat.twoWeeks: '2 semanas',
              CalendarFormat.week: 'Semana',
            },
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: eventsOf,
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = Recurrence.dateOnly(selected);
                _focusedDay = focused;
              });
            },
            onFormatChanged: (format) => setState(() => _format = format),
            onPageChanged: (focused) => setState(() => _focusedDay = focused),
            headerStyle: HeaderStyle(
              titleCentered: true,
              formatButtonShowsNext: false,
              titleTextStyle: theme.textTheme.titleMedium ?? const TextStyle(),
              formatButtonDecoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              formatButtonTextStyle: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              todayDecoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: AppColors.warning,
                shape: BoxShape.circle,
              ),
              markersMaxCount: 3,
              defaultTextStyle: TextStyle(color: theme.colorScheme.onSurface),
              weekendTextStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const Divider(height: 16),

          Expanded(
            child: selectedEvents.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            Icons.event_available_outlined,
                            size: 40,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Nenhuma cobrança em '
                            '${DateFormatter.longDate(_selectedDay)}.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: selectedEvents.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final sub = selectedEvents[index];
                      final category = CategoryModel.byId(sub.categoryId);

                      return CustomCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: category.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                category.icon,
                                color: category.color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    sub.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    sub.paymentMethod,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(sub.price),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
