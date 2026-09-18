import 'package:ecostream/core/domain/billing_cycle.dart';
import 'package:ecostream/features/reminders/domain/reminder.dart';
import 'package:ecostream/features/reminders/domain/reminder_engine.dart';
import 'package:ecostream/features/subscriptions/domain/subscription_model.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _now = DateTime(2026, 9, 17, 8);

SubscriptionModel _sub({
  required String id,
  required String name,
  required DateTime nextBilling,
  double price = 59.90,
  UsageLevel usage = UsageLevel.high,
  SubscriptionStatus status = SubscriptionStatus.active,
}) {
  return SubscriptionModel(
    id: id,
    userId: 'usr_1',
    name: name,
    categoryId: 'cat_streaming',
    price: price,
    cycle: BillingCycle.monthly,
    billingDay: nextBilling.day,
    nextBillingDate: nextBilling,
    paymentMethod: 'Cartão de Crédito',
    createdAt: DateTime(2025),
    usageLevel: usage,
    status: status,
  );
}

void main() {
  const engine = ReminderEngine();

  group('buildSchedule', () {
    test('agenda um lembrete por antecedência configurada', () {
      final reminders = engine.buildSchedule(
        subscriptions: <SubscriptionModel>[
          _sub(id: '1', name: 'Netflix', nextBilling: DateTime(2026, 9, 25)),
        ],
        settings: const ReminderSettings(leadDays: <int>[7, 3, 1]),
        now: _now,
      );

      expect(reminders, hasLength(3));
      expect(
        reminders.map((r) => r.scheduledFor).toList(),
        <DateTime>[
          DateTime(2026, 9, 18, 9),
          DateTime(2026, 9, 22, 9),
          DateTime(2026, 9, 24, 9),
        ],
      );
    });

    test('respeita o horário configurado', () {
      final reminders = engine.buildSchedule(
        subscriptions: <SubscriptionModel>[
          _sub(id: '1', name: 'Netflix', nextBilling: DateTime(2026, 9, 25)),
        ],
        settings: const ReminderSettings(leadDays: <int>[1], hourOfDay: 20),
        now: _now,
      );
      expect(reminders.single.scheduledFor, DateTime(2026, 9, 24, 20));
    });

    test('descarta lembretes cujo horário já passou', () {
      // A cobrança é amanhã, então o aviso de 7 dias antes caiu há 6 dias.
      // Agendar no passado dispararia na hora e assustaria o usuário.
      final reminders = engine.buildSchedule(
        subscriptions: <SubscriptionModel>[
          _sub(id: '1', name: 'Netflix', nextBilling: DateTime(2026, 9, 18)),
        ],
        settings: const ReminderSettings(leadDays: <int>[7, 3, 1]),
        now: _now,
      );

      expect(reminders, hasLength(1));
      expect(reminders.single.scheduledFor, DateTime(2026, 9, 17, 9));
    });

    test('interruptor geral desligado não agenda nada', () {
      final reminders = engine.buildSchedule(
        subscriptions: <SubscriptionModel>[
          _sub(id: '1', name: 'Netflix', nextBilling: DateTime(2026, 9, 25)),
        ],
        settings: const ReminderSettings(enabled: false),
        now: _now,
      );
      expect(reminders, isEmpty);
    });

    test('assinaturas pausadas e canceladas não geram lembrete', () {
      final reminders = engine.buildSchedule(
        subscriptions: <SubscriptionModel>[
          _sub(
            id: '1',
            name: 'Pausada',
            nextBilling: DateTime(2026, 9, 25),
            status: SubscriptionStatus.paused,
          ),
          _sub(
            id: '2',
            name: 'Cancelada',
            nextBilling: DateTime(2026, 9, 25),
            status: SubscriptionStatus.cancelled,
          ),
        ],
        settings: const ReminderSettings(),
        now: _now,
      );
      expect(reminders, isEmpty);
    });

    test('devolve os lembretes ordenados por data', () {
      final reminders = engine.buildSchedule(
        subscriptions: <SubscriptionModel>[
          _sub(id: '1', name: 'Tarde', nextBilling: DateTime(2026, 10, 20)),
          _sub(id: '2', name: 'Cedo', nextBilling: DateTime(2026, 9, 25)),
        ],
        settings: const ReminderSettings(),
        now: _now,
      );

      expect(reminders.first.subscriptionId, '2');
      expect(reminders.last.subscriptionId, '1');
    });

    test('a lista devolvida é imutável', () {
      final reminders = engine.buildSchedule(
        subscriptions: <SubscriptionModel>[
          _sub(id: '1', name: 'Netflix', nextBilling: DateTime(2026, 9, 25)),
        ],
        settings: const ReminderSettings(),
        now: _now,
      );

      expect(
        () => reminders.add(
          ScheduledReminder(
            id: 'x',
            subscriptionId: 'x',
            scheduledFor: _now,
            title: 't',
            body: 'b',
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('conteúdo da mensagem', () {
    test('o título muda conforme a antecedência', () {
      final reminders = engine.buildSchedule(
        subscriptions: <SubscriptionModel>[
          _sub(id: '1', name: 'Netflix', nextBilling: DateTime(2026, 9, 30)),
        ],
        settings: const ReminderSettings(leadDays: <int>[0, 1, 5]),
        now: _now,
      );

      final titles = reminders.map((r) => r.title).toList();
      expect(titles, contains('Netflix é cobrado hoje'));
      expect(titles, contains('Netflix é cobrado amanhã'));
      expect(titles, contains('Netflix é cobrado em 5 dias'));
    });

    test('o corpo traz o valor formatado em reais', () {
      final reminders = engine.buildSchedule(
        subscriptions: <SubscriptionModel>[
          _sub(id: '1', name: 'Netflix', nextBilling: DateTime(2026, 9, 25), price: 59.90),
        ],
        settings: const ReminderSettings(leadDays: <int>[1]),
        now: _now,
      );
      expect(reminders.single.body, contains('59,90'));
    });

    test('serviço pouco usado recebe convite para cancelar', () {
      final reminders = engine.buildSchedule(
        subscriptions: <SubscriptionModel>[
          _sub(
            id: '1',
            name: 'Disney+',
            nextBilling: DateTime(2026, 9, 25),
            usage: UsageLevel.never,
          ),
        ],
        settings: const ReminderSettings(leadDays: <int>[1]),
        now: _now,
      );
      expect(reminders.single.body, contains('cancelar'));
    });
  });

  group('ScheduledReminder.platformId', () {
    test('é estável para o mesmo id', () {
      ScheduledReminder build() => ScheduledReminder(
            id: 'sub_1_d3',
            subscriptionId: 'sub_1',
            scheduledFor: _now,
            title: 't',
            body: 'b',
          );

      expect(build().platformId, build().platformId);
    });

    test('difere entre ids diferentes', () {
      final a = ScheduledReminder(
        id: 'sub_1_d3',
        subscriptionId: 'sub_1',
        scheduledFor: _now,
        title: 't',
        body: 'b',
      );
      final b = ScheduledReminder(
        id: 'sub_1_d1',
        subscriptionId: 'sub_1',
        scheduledFor: _now,
        title: 't',
        body: 'b',
      );
      expect(a.platformId, isNot(b.platformId));
    });

    test('cabe no inteiro de 32 bits exigido pelo Android', () {
      final reminder = ScheduledReminder(
        id: 'um_identificador_bastante_longo_para_forcar_overflow_de_hash',
        subscriptionId: 'sub_1',
        scheduledFor: _now,
        title: 't',
        body: 'b',
      );
      expect(reminder.platformId, greaterThanOrEqualTo(0));
      expect(reminder.platformId, lessThanOrEqualTo(0x7fffffff));
    });
  });

  group('ReminderSettings', () {
    test('ida e volta de serialização preserva os campos', () {
      const original = ReminderSettings(
        leadDays: <int>[3, 1],
        hourOfDay: 20,
        notifyWeeklyDigest: true,
      );
      expect(ReminderSettings.fromJson(original.toJson()), original);
    });

    test('JSON vazio usa os padrões', () {
      final settings = ReminderSettings.fromJson(const <String, dynamic>{});
      expect(settings.enabled, isTrue);
      expect(settings.leadDays, <int>[1]);
      expect(settings.hourOfDay, 9);
    });
  });
}
