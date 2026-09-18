import '../domain/billing_cycle.dart';

/// Cálculo de datas de cobrança recorrente.
///
/// Toda aritmética de data do app passa por aqui. O motivo é o dia 31: uma assinatura
/// cobrada todo dia 31 não pode virar "3 de março" em fevereiro, que é o que
/// `DateTime(2026, 2, 31)` produz por causa do overflow silencioso do Dart.
/// Ver CLAUDE.md §6.
class Recurrence {
  Recurrence._();

  /// Normaliza para meia-noite. Comparar datas com hora embutida gera erro de um dia.
  static DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  /// Último dia do mês [month] de [year] (28, 29, 30 ou 31).
  ///
  /// `DateTime(year, month + 1, 0)` recua um dia a partir do primeiro dia do mês
  /// seguinte, o que já trata ano bissexto e virada de ano.
  static int lastDayOfMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  /// Constrói uma data no mês indicado usando [day], limitado ao último dia do mês.
  ///
  /// Ex.: dia 31 em fevereiro de 2026 vira 28/02/2026, não 03/03/2026.
  static DateTime clampToMonth({
    required int year,
    required int month,
    required int day,
  }) {
    // Normaliza mês fora do intervalo 1..12 (ex.: mês 13 vira janeiro do ano seguinte).
    final normalizedYear = year + ((month - 1) ~/ 12);
    final normalizedMonth = ((month - 1) % 12) + 1;
    final maxDay = lastDayOfMonth(normalizedYear, normalizedMonth);
    return DateTime(normalizedYear, normalizedMonth, day.clamp(1, maxDay));
  }

  /// Avança [from] em exatamente um ciclo [cycle], preservando o dia de cobrança.
  ///
  /// [anchorDay] é o dia original contratado. Ele é necessário porque, uma vez que a
  /// data tenha sido reduzida (31 → 28 em fevereiro), somar meses a partir dela
  /// "gruda" a assinatura no dia 28 para sempre.
  static DateTime advance(
    DateTime from,
    BillingCycle cycle, {
    int? anchorDay,
  }) {
    final base = dateOnly(from);
    final months = cycle.intervalInMonths;
    if (months == null) {
      // Semanal: soma simples de dias, sem o problema de fim de mês.
      return base.add(Duration(days: cycle.approximateDays));
    }
    return clampToMonth(
      year: base.year,
      month: base.month + months,
      day: anchorDay ?? base.day,
    );
  }

  /// Próxima ocorrência de cobrança igual ou posterior a [reference].
  ///
  /// Assinaturas cadastradas há meses têm `nextBillingDate` no passado. Em vez de
  /// mostrar "vencida há 74 dias", avançamos ciclo a ciclo até alcançar o presente —
  /// é assim que o usuário enxerga a cobrança dele.
  static DateTime nextOccurrence({
    required DateTime lastBillingDate,
    required BillingCycle cycle,
    required DateTime reference,
    int? anchorDay,
  }) {
    final target = dateOnly(reference);
    var current = dateOnly(lastBillingDate);
    final anchor = anchorDay ?? current.day;

    // Limite de segurança: evita laço infinito caso um ciclo degenerado chegue aqui.
    var guard = 0;
    while (current.isBefore(target) && guard < _maxIterations) {
      current = advance(current, cycle, anchorDay: anchor);
      guard++;
    }
    return current;
  }

  /// Todas as cobranças de [cycle] que caem entre [start] e [end], inclusive.
  ///
  /// Usado pelo calendário e pela projeção de fluxo de caixa mensal.
  static List<DateTime> occurrencesBetween({
    required DateTime firstBillingDate,
    required BillingCycle cycle,
    required DateTime start,
    required DateTime end,
    int? anchorDay,
  }) {
    final from = dateOnly(start);
    final to = dateOnly(end);
    if (to.isBefore(from)) return const [];

    final anchor = anchorDay ?? dateOnly(firstBillingDate).day;
    var current = nextOccurrence(
      lastBillingDate: firstBillingDate,
      cycle: cycle,
      reference: from,
      anchorDay: anchor,
    );

    final result = <DateTime>[];
    var guard = 0;
    while (!current.isAfter(to) && guard < _maxIterations) {
      result.add(current);
      current = advance(current, cycle, anchorDay: anchor);
      guard++;
    }
    return result;
  }

  /// Dias inteiros entre hoje e [date]. Negativo se já passou.
  static int daysUntil(DateTime date, {DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    return dateOnly(date).difference(today).inDays;
  }

  /// Texto curto de vencimento para listas: "Hoje", "Amanhã", "Em 5 dias".
  static String humanizeDueDate(DateTime date, {DateTime? now}) {
    final days = daysUntil(date, now: now);
    return switch (days) {
      < -1 => 'Atrasada há ${-days} dias',
      -1 => 'Atrasada desde ontem',
      0 => 'Hoje',
      1 => 'Amanhã',
      _ => 'Em $days dias',
    };
  }

  /// Teto de iterações dos laços de recorrência. 600 cobre mais de 11 anos de
  /// cobranças semanais, muito além de qualquer caso real.
  static const int _maxIterations = 600;
}
