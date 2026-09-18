import 'package:ecostream/core/domain/billing_cycle.dart';
import 'package:ecostream/features/billing/domain/plan.dart';
import 'package:ecostream/features/insights/domain/insight.dart';
import 'package:ecostream/features/insights/domain/insights_engine.dart';
import 'package:ecostream/features/subscriptions/domain/subscription_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Data fixa de referência para que as regras sensíveis a calendário não dependam
/// de quando o teste roda.
final DateTime _now = DateTime(2026, 9, 17);

SubscriptionModel _sub({
  required String id,
  required String name,
  required double price,
  String categoryId = 'cat_streaming',
  BillingCycle cycle = BillingCycle.monthly,
  UsageLevel usage = UsageLevel.high,
  DateTime? nextBilling,
  double? annualPlanPrice,
  List<PricePoint> priceHistory = const <PricePoint>[],
  SubscriptionStatus status = SubscriptionStatus.active,
}) {
  final billing = nextBilling ?? DateTime(2026, 10, 10);
  return SubscriptionModel(
    id: id,
    userId: 'usr_test',
    name: name,
    categoryId: categoryId,
    price: price,
    cycle: cycle,
    billingDay: billing.day,
    nextBillingDate: billing,
    paymentMethod: 'Cartão de Crédito',
    createdAt: DateTime(2025),
    usageLevel: usage,
    status: status,
    annualPlanPrice: annualPlanPrice,
    priceHistory: priceHistory,
  );
}

Insight? _find(List<Insight> insights, InsightKind kind) {
  for (final insight in insights) {
    if (insight.kind == kind) return insight;
  }
  return null;
}

void main() {
  const engineDefault = InsightsEngine();
  final engine = InsightsEngine(now: _now);

  group('InsightsEngine.analyze — entradas degeneradas', () {
    test('lista vazia não gera insight', () {
      expect(engineDefault.analyze(const <SubscriptionModel>[]), isEmpty);
    });

    test('assinaturas inativas são ignoradas', () {
      final insights = engine.analyze(<SubscriptionModel>[
        _sub(
          id: '1',
          name: 'Cancelada',
          price: 100,
          status: SubscriptionStatus.cancelled,
          usage: UsageLevel.never,
        ),
        _sub(
          id: '2',
          name: 'Pausada',
          price: 100,
          status: SubscriptionStatus.paused,
          usage: UsageLevel.never,
        ),
      ]);
      expect(insights, isEmpty);
    });
  });

  group('Regra: serviço pago e não usado', () {
    test('marca como crítico e soma o desperdício anual', () {
      final insights = engine.analyze(<SubscriptionModel>[
        _sub(id: '1', name: 'Disney+', price: 43.90, usage: UsageLevel.never),
        _sub(id: '2', name: 'Netflix', price: 59.90),
      ]);

      final wasted = insights.firstWhere((i) => i.id == 'wasted_never');
      expect(wasted.severity, InsightSeverity.critical);
      expect(wasted.potentialAnnualSavings, closeTo(43.90 * 12, 0.01));
      expect(wasted.subscriptionIds, <String>['1']);
    });

    test('uso raro gera alerta separado, com severidade menor', () {
      final insights = engine.analyze(<SubscriptionModel>[
        _sub(id: '1', name: 'Canva', price: 34.90, usage: UsageLevel.low),
      ]);

      final low = insights.firstWhere((i) => i.id == 'wasted_low');
      expect(low.severity, InsightSeverity.warning);
      expect(low.potentialAnnualSavings, closeTo(34.90 * 12, 0.01));
    });

    test('carteira toda utilizada não gera insight de desperdício', () {
      final insights = engine.analyze(<SubscriptionModel>[
        _sub(id: '1', name: 'Netflix', price: 59.90),
        _sub(id: '2', name: 'Spotify', price: 21.90, categoryId: 'cat_software'),
      ]);
      expect(_find(insights, InsightKind.wastedSpend), isNull);
    });
  });

  group('Regra: migração para plano anual', () {
    test('sugere migração quando o anual é mais barato', () {
      final insights = engine.analyze(<SubscriptionModel>[
        _sub(id: '1', name: 'Prime Video', price: 19.90, annualPlanPrice: 179),
      ]);

      final switchInsight = insights.firstWhere((i) => i.id == 'annual_switch');
      expect(switchInsight.potentialAnnualSavings, closeTo(59.80, 0.01));
      expect(switchInsight.requiredFeature, Feature.annualSwitchAdvisor);
    });

    test('não sugere quando o anual sai mais caro', () {
      final insights = engine.analyze(<SubscriptionModel>[
        _sub(id: '1', name: 'Servico', price: 10, annualPlanPrice: 200),
      ]);
      expect(_find(insights, InsightKind.annualSwitch), isNull);
    });

    test('não sugere para assinatura que já é anual', () {
      final insights = engine.analyze(<SubscriptionModel>[
        _sub(
          id: '1',
          name: 'PS Plus',
          price: 480,
          cycle: BillingCycle.annual,
          annualPlanPrice: 400,
        ),
      ]);
      expect(_find(insights, InsightKind.annualSwitch), isNull);
    });
  });

  group('Regra: serviços sobrepostos', () {
    test('a partir de três na mesma categoria gera alerta', () {
      final insights = engine.analyze(<SubscriptionModel>[
        _sub(id: '1', name: 'Netflix', price: 59.90),
        _sub(id: '2', name: 'Disney+', price: 43.90),
        _sub(id: '3', name: 'Prime', price: 19.90),
      ]);

      final overlap = insights.firstWhere((i) => i.kind == InsightKind.overlap);
      // A economia sugerida é cortar o mais barato — não a soma dos três.
      expect(overlap.potentialAnnualSavings, closeTo(19.90 * 12, 0.01));
      expect(overlap.subscriptionIds, hasLength(3));
    });

    test('dois serviços na mesma categoria não geram alerta', () {
      final insights = engine.analyze(<SubscriptionModel>[
        _sub(id: '1', name: 'Netflix', price: 59.90),
        _sub(id: '2', name: 'Disney+', price: 43.90),
      ]);
      expect(_find(insights, InsightKind.overlap), isNull);
    });
  });

  group('Regra: reajuste de preço', () {
    test('detecta aumento acima do limite e calcula a diferença anual', () {
      final insights = engine.analyze(<SubscriptionModel>[
        _sub(
          id: '1',
          name: 'Netflix',
          price: 59.90,
          priceHistory: <PricePoint>[
            PricePoint(price: 39.90, changedAt: DateTime(2024)),
          ],
        ),
      ]);

      final increase = insights.firstWhere((i) => i.kind == InsightKind.priceIncrease);
      // (59,90 - 39,90) * 12 = 240,00 a mais por ano.
      expect(increase.description, contains('240,00'));
      expect(increase.requiredFeature, Feature.priceHistory);
    });

    test('ignora variação abaixo do limite de 5%', () {
      final insights = engine.analyze(<SubscriptionModel>[
        _sub(
          id: '1',
          name: 'Servico',
          price: 102,
          priceHistory: <PricePoint>[
            PricePoint(price: 100, changedAt: DateTime(2025)),
          ],
        ),
      ]);
      expect(_find(insights, InsightKind.priceIncrease), isNull);
    });

    test('assinatura sem histórico não gera alerta de reajuste', () {
      final insights = engine.analyze(<SubscriptionModel>[
        _sub(id: '1', name: 'Nova', price: 100),
      ]);
      expect(_find(insights, InsightKind.priceIncrease), isNull);
    });
  });

  group('Regra: concentração por categoria', () {
    test('alerta quando uma categoria passa de metade do gasto', () {
      final insights = engine.analyze(<SubscriptionModel>[
        _sub(id: '1', name: 'Netflix', price: 100),
        _sub(id: '2', name: 'GitHub', price: 20, categoryId: 'cat_software'),
      ]);

      final concentration =
          insights.firstWhere((i) => i.kind == InsightKind.concentration);
      expect(concentration.title, contains('83%'));
    });

    test('carteira equilibrada não gera alerta de concentração', () {
      final insights = engine.analyze(<SubscriptionModel>[
        _sub(id: '1', name: 'Netflix', price: 50),
        _sub(id: '2', name: 'GitHub', price: 50, categoryId: 'cat_software'),
        _sub(id: '3', name: 'iCloud', price: 50, categoryId: 'cat_cloud'),
      ]);
      expect(_find(insights, InsightKind.concentration), isNull);
    });
  });

  group('Regra: acúmulo de cobranças', () {
    test('alerta com quatro ou mais cobranças em sete dias', () {
      final insights = engine.analyze(<SubscriptionModel>[
        _sub(id: '1', name: 'A', price: 50, nextBilling: DateTime(2026, 9, 18)),
        _sub(id: '2', name: 'B', price: 50, nextBilling: DateTime(2026, 9, 19)),
        _sub(id: '3', name: 'C', price: 50, nextBilling: DateTime(2026, 9, 20)),
        _sub(id: '4', name: 'D', price: 50, nextBilling: DateTime(2026, 9, 21)),
      ]);

      final spike = insights.firstWhere((i) => i.kind == InsightKind.billingSpike);
      expect(spike.description, contains('200,00'));
    });

    test('três cobranças na semana não geram alerta', () {
      final insights = engine.analyze(<SubscriptionModel>[
        _sub(id: '1', name: 'A', price: 50, nextBilling: DateTime(2026, 9, 18)),
        _sub(id: '2', name: 'B', price: 50, nextBilling: DateTime(2026, 9, 19)),
        _sub(id: '3', name: 'C', price: 50, nextBilling: DateTime(2026, 9, 20)),
      ]);
      expect(_find(insights, InsightKind.billingSpike), isNull);
    });

    test('cobranças fora da janela de sete dias não contam', () {
      final insights = engine.analyze(<SubscriptionModel>[
        _sub(id: '1', name: 'A', price: 50, nextBilling: DateTime(2026, 9, 30)),
        _sub(id: '2', name: 'B', price: 50, nextBilling: DateTime(2026, 10)),
        _sub(id: '3', name: 'C', price: 50, nextBilling: DateTime(2026, 10, 2)),
        _sub(id: '4', name: 'D', price: 50, nextBilling: DateTime(2026, 10, 3)),
      ]);
      expect(_find(insights, InsightKind.billingSpike), isNull);
    });
  });

  group('Regra: projeção de cinco anos', () {
    test('projeta o gasto e cita o ano final', () {
      final insights = engine.analyze(<SubscriptionModel>[
        _sub(id: '1', name: 'Netflix', price: 49),
      ]);

      final projection = insights.firstWhere((i) => i.kind == InsightKind.projection);
      expect(projection.title, contains('2.940,00'));
      expect(projection.description, contains('2031'));
      expect(projection.requiredFeature, Feature.fiveYearProjection);
    });
  });

  group('Ordenação e totais', () {
    test('o insight mais severo vem primeiro', () {
      final insights = engine.analyze(<SubscriptionModel>[
        _sub(id: '1', name: 'Disney+', price: 43.90, usage: UsageLevel.never),
        _sub(id: '2', name: 'Netflix', price: 59.90),
        _sub(id: '3', name: 'GitHub', price: 24, categoryId: 'cat_software'),
      ]);

      expect(insights.first.severity, InsightSeverity.critical);
    });

    test('a soma das economias considera só insights acionáveis', () {
      final subscriptions = <SubscriptionModel>[
        _sub(id: '1', name: 'Disney+', price: 43.90, usage: UsageLevel.never),
        _sub(id: '2', name: 'Prime', price: 19.90, annualPlanPrice: 179),
      ];

      final total = engine.totalPotentialAnnualSavings(subscriptions);
      final manual = engine
          .analyze(subscriptions)
          .where((i) => i.potentialAnnualSavings > 0)
          .fold<double>(0, (sum, i) => sum + i.potentialAnnualSavings);

      expect(total, closeTo(manual, 0.01));
      expect(total, greaterThan(0));
    });

    test('a lista devolvida é imutável', () {
      final insights = engine.analyze(<SubscriptionModel>[
        _sub(id: '1', name: 'Netflix', price: 59.90),
      ]);
      expect(
        () => insights.add(
          const Insight(
            id: 'x',
            kind: InsightKind.summary,
            severity: InsightSeverity.info,
            title: 't',
            description: 'd',
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });
}
