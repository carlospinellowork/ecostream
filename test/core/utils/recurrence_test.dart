import 'package:ecostream/core/domain/billing_cycle.dart';
import 'package:ecostream/core/utils/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Recurrence.lastDayOfMonth', () {
    test('reconhece meses de 30 e 31 dias', () {
      expect(Recurrence.lastDayOfMonth(2026, 1), 31);
      expect(Recurrence.lastDayOfMonth(2026, 4), 30);
    });

    test('trata fevereiro em ano comum e bissexto', () {
      expect(Recurrence.lastDayOfMonth(2026, 2), 28);
      expect(Recurrence.lastDayOfMonth(2028, 2), 29);
      // 2000 é bissexto (divisível por 400), 1900 não é (divisível por 100).
      expect(Recurrence.lastDayOfMonth(2000, 2), 29);
      expect(Recurrence.lastDayOfMonth(1900, 2), 28);
    });
  });

  group('Recurrence.clampToMonth', () {
    test('limita o dia 31 ao último dia de fevereiro', () {
      // Regressão: `DateTime(2026, 2, 31)` transborda para 03/03/2026, o que faria
      // a cobrança aparecer no mês errado.
      final date = Recurrence.clampToMonth(year: 2026, month: 2, day: 31);
      expect(date, DateTime(2026, 2, 28));
    });

    test('preserva o dia quando ele existe no mês', () {
      expect(
        Recurrence.clampToMonth(year: 2026, month: 3, day: 31),
        DateTime(2026, 3, 31),
      );
    });

    test('normaliza mês acima de 12 para o ano seguinte', () {
      expect(
        Recurrence.clampToMonth(year: 2026, month: 13, day: 10),
        DateTime(2027, 1, 10),
      );
    });
  });

  group('Recurrence.advance', () {
    test('avança um mês mantendo o dia', () {
      expect(
        Recurrence.advance(DateTime(2026, 1, 15), BillingCycle.monthly),
        DateTime(2026, 2, 15),
      );
    });

    test('usa a âncora para recuperar o dia 31 depois de fevereiro', () {
      // Sem a âncora, 28/02 + 1 mês = 28/03 e a assinatura ficaria presa no dia 28.
      final afterFebruary = Recurrence.advance(
        DateTime(2026, 2, 28),
        BillingCycle.monthly,
        anchorDay: 31,
      );
      expect(afterFebruary, DateTime(2026, 3, 31));
    });

    test('avança sete dias no ciclo semanal', () {
      expect(
        Recurrence.advance(DateTime(2026, 1, 29), BillingCycle.weekly),
        DateTime(2026, 2, 5),
      );
    });

    test('avança doze meses no ciclo anual', () {
      expect(
        Recurrence.advance(DateTime(2026, 5, 10), BillingCycle.annual),
        DateTime(2027, 5, 10),
      );
    });
  });

  group('Recurrence.nextOccurrence', () {
    test('rola uma data antiga até a próxima ocorrência futura', () {
      final next = Recurrence.nextOccurrence(
        lastBillingDate: DateTime(2025, 3, 10),
        cycle: BillingCycle.monthly,
        reference: DateTime(2026, 9, 17),
      );
      expect(next, DateTime(2026, 10, 10));
    });

    test('mantém a data quando ela já é futura', () {
      final next = Recurrence.nextOccurrence(
        lastBillingDate: DateTime(2026, 12, 1),
        cycle: BillingCycle.monthly,
        reference: DateTime(2026, 9, 17),
      );
      expect(next, DateTime(2026, 12, 1));
    });

    test('mantém a data quando ela é exatamente hoje', () {
      final next = Recurrence.nextOccurrence(
        lastBillingDate: DateTime(2026, 9, 17),
        cycle: BillingCycle.monthly,
        reference: DateTime(2026, 9, 17),
      );
      expect(next, DateTime(2026, 9, 17));
    });
  });

  group('Recurrence.occurrencesBetween', () {
    test('lista as quatro ou cinco cobranças semanais de um mês', () {
      final occurrences = Recurrence.occurrencesBetween(
        firstBillingDate: DateTime(2026, 9, 1),
        cycle: BillingCycle.weekly,
        start: DateTime(2026, 9),
        end: DateTime(2026, 9, 30),
      );
      expect(occurrences, <DateTime>[
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 8),
        DateTime(2026, 9, 15),
        DateTime(2026, 9, 22),
        DateTime(2026, 9, 29),
      ]);
    });

    test('projeta a cobrança mensal em um mês futuro', () {
      // O calendário depende disto: sem projeção, meses seguintes apareciam vazios.
      final occurrences = Recurrence.occurrencesBetween(
        firstBillingDate: DateTime(2026, 9, 12),
        cycle: BillingCycle.monthly,
        start: DateTime(2026, 12),
        end: DateTime(2026, 12, 31),
      );
      expect(occurrences, <DateTime>[DateTime(2026, 12, 12)]);
    });

    test('assinatura anual não aparece em mês sem cobrança', () {
      final occurrences = Recurrence.occurrencesBetween(
        firstBillingDate: DateTime(2027, 2, 15),
        cycle: BillingCycle.annual,
        start: DateTime(2026, 10),
        end: DateTime(2026, 10, 31),
      );
      expect(occurrences, isEmpty);
    });

    test('intervalo invertido devolve lista vazia', () {
      final occurrences = Recurrence.occurrencesBetween(
        firstBillingDate: DateTime(2026, 9, 1),
        cycle: BillingCycle.monthly,
        start: DateTime(2026, 9, 30),
        end: DateTime(2026, 9),
      );
      expect(occurrences, isEmpty);
    });
  });

  group('Recurrence.daysUntil', () {
    test('ignora a hora ao comparar datas', () {
      // Regressão: sem normalizar para meia-noite, 23h de hoje contra 1h de amanhã
      // resultava em 0 dias.
      final days = Recurrence.daysUntil(
        DateTime(2026, 9, 18, 1),
        now: DateTime(2026, 9, 17, 23),
      );
      expect(days, 1);
    });

    test('devolve negativo para data passada', () {
      expect(
        Recurrence.daysUntil(DateTime(2026, 9, 10), now: DateTime(2026, 9, 17)),
        -7,
      );
    });
  });

  group('Recurrence.humanizeDueDate', () {
    final now = DateTime(2026, 9, 17);

    test('descreve hoje, amanhã e dias futuros', () {
      expect(Recurrence.humanizeDueDate(DateTime(2026, 9, 17), now: now), 'Hoje');
      expect(Recurrence.humanizeDueDate(DateTime(2026, 9, 18), now: now), 'Amanhã');
      expect(Recurrence.humanizeDueDate(DateTime(2026, 9, 22), now: now), 'Em 5 dias');
    });

    test('descreve atraso', () {
      expect(
        Recurrence.humanizeDueDate(DateTime(2026, 9, 16), now: now),
        'Atrasada desde ontem',
      );
      expect(
        Recurrence.humanizeDueDate(DateTime(2026, 9, 14), now: now),
        'Atrasada há 3 dias',
      );
    });
  });
}
