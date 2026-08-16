import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/custom_card.dart';
import 'package:ecostream/features/categories/domain/category_model.dart';
import 'package:ecostream/features/subscriptions/domain/subscription_model.dart';
import 'package:ecostream/features/subscriptions/presentation/controllers/subscription_controller.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final subState = ref.watch(subscriptionControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Assinaturas ativas no mês visualizado
    final activeSubs = subState.subscriptions.where((s) => s.status == SubscriptionStatus.active).toList();

    // Mapeamento de eventos por dia
    Map<DateTime, List<SubscriptionModel>> events = {};
    for (var sub in activeSubs) {
      final dateKey = DateTime(sub.nextBillingDate.year, sub.nextBillingDate.month, sub.nextBillingDate.day);
      if (events[dateKey] == null) {
        events[dateKey] = [];
      }
      events[dateKey]!.add(sub);
    }

    List<SubscriptionModel> getEventsForDay(DateTime day) {
      final key = DateTime(day.year, day.month, day.day);
      return events[key] ?? [];
    }

    final selectedDayEvents = _selectedDay != null ? getEventsForDay(_selectedDay!) : [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendário de Cobranças'),
      ),
      body: Column(
        children: [
          // Banner de Total Previsto no Mês
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: CustomCard(
              backgroundColor: isDark ? const Color(0xFF1E293B) : AppColors.primary.withOpacity(0.1),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Previsto Este Mês',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.formatBRL(subState.totalMonthlySpend),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.calendar_month_outlined, color: AppColors.primary, size: 32),
                ],
              ),
            ),
          ),

          // Tabela Calendário
          TableCalendar<SubscriptionModel>(
            locale: 'pt_BR',
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 365 * 2)),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: getEventsForDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarStyle: CalendarStyle(
              todayDecoration: const BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              markersMaxCount: 3,
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
          ),

          const Divider(height: 1),

          // Lista de Cobranças do Dia Selecionado ou Próximas do Mês
          Expanded(
            child: Container(
              color: isDark ? AppColors.bgDark : Colors.grey.shade50,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedDay != null
                        ? 'Cobranças em ${DateFormat('dd/MM/yyyy').format(_selectedDay!)}'
                        : 'Selecione um dia',
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: selectedDayEvents.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.event_available, size: 48, color: AppColors.success),
                                const SizedBox(height: 8),
                                Text(
                                  'Nenhuma cobrança nesta data.',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: selectedDayEvents.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final sub = selectedDayEvents[index];
                              final cat = CategoryModel.defaultCategories.firstWhere(
                                (c) => c.id == sub.categoryId,
                                orElse: () => CategoryModel.defaultCategories.last,
                              );

                              return CustomCard(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: cat.color.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(cat.icon, color: cat.color, size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            sub.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${cat.name} • ${sub.paymentMethod}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      CurrencyFormatter.formatBRL(sub.price),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: AppColors.primary,
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
            ),
          ),
        ],
      ),
    );
  }
}
