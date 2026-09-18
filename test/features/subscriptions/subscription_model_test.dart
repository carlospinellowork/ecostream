import 'package:ecostream/core/domain/billing_cycle.dart';
import 'package:ecostream/features/subscriptions/domain/subscription_model.dart';
import 'package:flutter_test/flutter_test.dart';

SubscriptionModel _sub({
  double price = 59.90,
  BillingCycle cycle = BillingCycle.monthly,
  DateTime? nextBilling,
  int billingDay = 10,
  UsageLevel usage = UsageLevel.high,
  double? annualPlanPrice,
  List<PricePoint> priceHistory = const <PricePoint>[],
}) {
  return SubscriptionModel(
    id: 'sub_1',
    userId: 'usr_1',
    name: 'Netflix',
    categoryId: 'cat_streaming',
    price: price,
    cycle: cycle,
    billingDay: billingDay,
    nextBillingDate: nextBilling ?? DateTime(2026, 10, 10),
    paymentMethod: 'Cartão de Crédito',
    createdAt: DateTime(2025),
    usageLevel: usage,
    annualPlanPrice: annualPlanPrice,
    priceHistory: priceHistory,
  );
}

void main() {
  group('equivalências', () {
    test('delega o cálculo mensal e anual à calculadora', () {
      final sub = _sub(price: 480, cycle: BillingCycle.annual);
      expect(sub.monthlyEquivalent, closeTo(40, 0.01));
      expect(sub.annualEquivalent, closeTo(480, 0.01));
    });
  });

  group('costPerUse', () {
    test('usa a estimativa de uso do nível informado', () {
      final sub = _sub(price: 40, usage: UsageLevel.medium);
      expect(sub.costPerUse, closeTo(10, 0.01));
    });

    test('devolve null quando o usuário marcou que não usa', () {
      expect(_sub(usage: UsageLevel.never).costPerUse, isNull);
    });
  });

  group('histórico de preços', () {
    test('sem histórico, o preço original é o atual', () {
      final sub = _sub(price: 59.90);
      expect(sub.originalPrice, closeTo(59.90, 0.01));
      expect(sub.priceIncreasePercent, isNull);
    });

    test('calcula o aumento percentual desde o primeiro registro', () {
      final sub = _sub(
        price: 59.90,
        priceHistory: <PricePoint>[
          PricePoint(price: 39.90, changedAt: DateTime(2024)),
          PricePoint(price: 49.90, changedAt: DateTime(2025)),
        ],
      );
      expect(sub.originalPrice, closeTo(39.90, 0.01));
      expect(sub.priceIncreasePercent, closeTo(50.13, 0.05));
    });

    test('withNewPrice arquiva o preço anterior', () {
      final sub = _sub(price: 49.90);
      final updated = sub.withNewPrice(59.90, at: DateTime(2026, 9, 17));

      expect(updated.price, closeTo(59.90, 0.01));
      expect(updated.priceHistory, hasLength(1));
      expect(updated.priceHistory.first.price, closeTo(49.90, 0.01));
    });

    test('withNewPrice com o mesmo preço não cria registro', () {
      final sub = _sub(price: 49.90);
      expect(sub.withNewPrice(49.90).priceHistory, isEmpty);
    });
  });

  group('annualSwitchSavings', () {
    test('devolve a economia quando o plano anual é mais barato', () {
      final sub = _sub(price: 19.90, annualPlanPrice: 179);
      expect(sub.annualSwitchSavings, closeTo(59.80, 0.01));
    });

    test('devolve null quando o anual não economiza', () {
      expect(_sub(price: 10, annualPlanPrice: 200).annualSwitchSavings, isNull);
    });

    test('devolve null quando não há preço anual informado', () {
      expect(_sub().annualSwitchSavings, isNull);
    });

    test('devolve null quando a assinatura já é anual', () {
      final sub = _sub(price: 480, cycle: BillingCycle.annual, annualPlanPrice: 400);
      expect(sub.annualSwitchSavings, isNull);
    });
  });

  group('rolledForward', () {
    test('avança data passada até a próxima ocorrência futura', () {
      final sub = _sub(nextBilling: DateTime(2025, 3, 10), billingDay: 10);
      final rolled = sub.rolledForward(now: DateTime(2026, 9, 17));
      expect(rolled.nextBillingDate, DateTime(2026, 10, 10));
    });

    test('preserva o dia 31 usando a âncora', () {
      // Sem a âncora, a assinatura ficaria presa no dia 28 depois de fevereiro.
      final sub = _sub(nextBilling: DateTime(2026, 1, 31), billingDay: 31);
      final rolled = sub.rolledForward(now: DateTime(2026, 3, 15));
      expect(rolled.nextBillingDate, DateTime(2026, 3, 31));
    });

    test('devolve a mesma instância quando a data já é futura', () {
      final sub = _sub(nextBilling: DateTime(2026, 12));
      expect(sub.rolledForward(now: DateTime(2026, 9, 17)), same(sub));
    });
  });

  group('serialização', () {
    test('ida e volta preserva os campos relevantes', () {
      final original = _sub(
        price: 59.90,
        annualPlanPrice: 599,
        priceHistory: <PricePoint>[
          PricePoint(price: 39.90, changedAt: DateTime(2024, 5, 3)),
        ],
      );

      final restored = SubscriptionModel.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.price, closeTo(original.price, 0.001));
      expect(restored.cycle, original.cycle);
      expect(restored.billingDay, original.billingDay);
      expect(restored.nextBillingDate, original.nextBillingDate);
      expect(restored.status, original.status);
      expect(restored.usageLevel, original.usageLevel);
      expect(restored.annualPlanPrice, closeTo(599, 0.001));
      expect(restored.priceHistory, hasLength(1));
      expect(restored.priceHistory.first.price, closeTo(39.90, 0.001));
    });

    test('lê o formato antigo, com ciclo em português na chave billingCycle', () {
      // Migração: instalações anteriores gravavam `billingCycle: 'anual'`.
      final legacy = <String, dynamic>{
        'id': 'sub_legacy',
        'userId': 'usr_1',
        'name': 'PS Plus',
        'categoryId': 'cat_games',
        'price': 480.0,
        'billingCycle': 'anual',
        'billingDay': 15,
        'nextBillingDate': DateTime(2027, 2, 15).toIso8601String(),
        'status': 'active',
        'paymentMethod': 'Pix',
        'createdAt': DateTime(2025).toIso8601String(),
      };

      final restored = SubscriptionModel.fromJson(legacy);
      expect(restored.cycle, BillingCycle.annual);
      expect(restored.usageLevel, UsageLevel.medium);
      expect(restored.priceHistory, isEmpty);
    });

    test('valores desconhecidos caem em padrões seguros', () {
      final json = <String, dynamic>{
        'id': 'sub_x',
        'userId': 'usr_1',
        'name': 'Servico',
        'categoryId': 'cat_outros',
        'price': 10.0,
        'cycle': 'ciclo_inexistente',
        'nextBillingDate': DateTime(2026, 10).toIso8601String(),
        'status': 'status_inexistente',
        'usageLevel': 'uso_inexistente',
        'createdAt': DateTime(2026).toIso8601String(),
      };

      final restored = SubscriptionModel.fromJson(json);
      expect(restored.cycle, BillingCycle.monthly);
      expect(restored.status, SubscriptionStatus.active);
      expect(restored.usageLevel, UsageLevel.medium);
      expect(restored.paymentMethod, 'Outro');
      expect(restored.billingDay, 1);
    });
  });

  group('BillingCycle', () {
    test('converte rótulos em português usados antes da migração', () {
      expect(BillingCycle.fromStorage('mensal'), BillingCycle.monthly);
      expect(BillingCycle.fromStorage('Anual'), BillingCycle.annual);
      expect(BillingCycle.fromStorage('semanal'), BillingCycle.weekly);
      expect(BillingCycle.fromStorage('trimestral'), BillingCycle.quarterly);
      expect(BillingCycle.fromStorage('semestral'), BillingCycle.semiannual);
    });

    test('converte os nomes do enum', () {
      for (final cycle in BillingCycle.values) {
        expect(BillingCycle.fromStorage(cycle.name), cycle);
      }
    });

    test('valor desconhecido ou nulo cai em mensal', () {
      expect(BillingCycle.fromStorage(null), BillingCycle.monthly);
      expect(BillingCycle.fromStorage('personalizada'), BillingCycle.monthly);
    });

    test('ocorrências por ano estão corretas', () {
      expect(BillingCycle.weekly.occurrencesPerYear, 52);
      expect(BillingCycle.monthly.occurrencesPerYear, 12);
      expect(BillingCycle.quarterly.occurrencesPerYear, 4);
      expect(BillingCycle.semiannual.occurrencesPerYear, 2);
      expect(BillingCycle.annual.occurrencesPerYear, 1);
    });
  });
}
