import 'package:ecostream/features/billing/domain/entitlements.dart';
import 'package:ecostream/features/billing/domain/plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 17);

  group('Entitlements.free', () {
    test('não libera nenhum recurso pago', () {
      for (final feature in Feature.values) {
        expect(
          Entitlements.free.can(feature, now: now),
          isFalse,
          reason: '${feature.name} não deveria estar liberado no gratuito',
        );
      }
    });

    test('permite cadastrar até o limite do plano gratuito', () {
      const free = Entitlements.free;
      expect(free.canAddSubscription(0, now: now), isTrue);
      expect(
        free.canAddSubscription(FreePlanLimits.maxSubscriptions - 1, now: now),
        isTrue,
      );
      expect(free.canAddSubscription(FreePlanLimits.maxSubscriptions, now: now), isFalse);
      expect(
        free.canAddSubscription(FreePlanLimits.maxSubscriptions + 3, now: now),
        isFalse,
      );
    });

    test('vagas restantes nunca ficam negativas', () {
      expect(
        Entitlements.free.remainingSubscriptionSlots(99, now: now),
        0,
      );
    });
  });

  group('Pro ativo', () {
    test('sem prazo libera tudo', () {
      const pro = Entitlements(plan: Plan.pro);
      expect(pro.isProActive(now: now), isTrue);
      for (final feature in Feature.values) {
        expect(pro.can(feature, now: now), isTrue);
      }
      expect(pro.remainingSubscriptionSlots(500, now: now), isNull);
      expect(pro.canAddSubscription(500, now: now), isTrue);
    });

    test('dentro do prazo libera tudo', () {
      final pro = Entitlements(
        plan: Plan.pro,
        expiresAt: now.add(const Duration(days: 3)),
      );
      expect(pro.isProActive(now: now), isTrue);
      expect(pro.can(Feature.csvExport, now: now), isTrue);
    });

    test('depois do prazo volta a bloquear', () {
      final expired = Entitlements(
        plan: Plan.pro,
        expiresAt: now.subtract(const Duration(days: 1)),
      );
      expect(expired.isProActive(now: now), isFalse);
      expect(expired.can(Feature.csvExport, now: now), isFalse);
      expect(
        expired.canAddSubscription(FreePlanLimits.maxSubscriptions, now: now),
        isFalse,
      );
    });
  });

  group('Trial', () {
    test('trial vigente conta como Pro e é identificado como trial', () {
      final trial = Entitlements(
        plan: Plan.pro,
        trialStartedAt: now,
        expiresAt: now.add(PricingCatalog.trialDuration),
      );
      expect(trial.isProActive(now: now), isTrue);
      expect(trial.isInTrial(now: now), isTrue);
      expect(trial.hasUsedTrial, isTrue);
    });

    test('compra não é classificada como trial', () {
      final purchased = Entitlements(
        plan: Plan.pro,
        trialStartedAt: now.subtract(const Duration(days: 60)),
        expiresAt: now.add(const Duration(days: 300)),
        activeOfferId: PricingCatalog.annual.id,
      );
      expect(purchased.isInTrial(now: now), isFalse);
    });

    test('trial expirado mantém a marca de já usado', () {
      final used = Entitlements(
        plan: Plan.pro,
        trialStartedAt: now.subtract(const Duration(days: 30)),
        expiresAt: now.subtract(const Duration(days: 23)),
      );
      expect(used.isProActive(now: now), isFalse);
      expect(used.hasUsedTrial, isTrue);
    });
  });

  group('daysRemaining', () {
    test('devolve os dias até o vencimento', () {
      final pro = Entitlements(
        plan: Plan.pro,
        expiresAt: now.add(const Duration(days: 5)),
      );
      expect(pro.daysRemaining(now: now), 5);
    });

    test('devolve zero, e não negativo, para prazo vencido', () {
      final pro = Entitlements(
        plan: Plan.pro,
        expiresAt: now.subtract(const Duration(days: 5)),
      );
      expect(pro.daysRemaining(now: now), 0);
    });

    test('devolve null quando não há prazo', () {
      expect(const Entitlements(plan: Plan.pro).daysRemaining(now: now), isNull);
    });
  });

  group('serialização', () {
    test('ida e volta preserva os campos', () {
      final original = Entitlements(
        plan: Plan.pro,
        trialStartedAt: DateTime(2026, 8),
        expiresAt: DateTime(2027, 8),
        activeOfferId: PricingCatalog.annual.id,
      );

      final restored = Entitlements.fromJson(original.toJson());
      expect(restored, original);
    });

    test('JSON vazio ou inválido cai no plano gratuito', () {
      expect(Entitlements.fromJson(const <String, dynamic>{}).plan, Plan.free);
      expect(
        Entitlements.fromJson(<String, dynamic>{
          'plan': 'plano_inexistente',
          'expiresAt': 'nao-e-data',
        }).plan,
        Plan.free,
      );
    });
  });

  group('PricingCatalog', () {
    test('o anual é mais barato por mês que o mensal', () {
      expect(
        PricingCatalog.annual.monthlyEquivalent,
        lessThan(PricingCatalog.monthly.price),
      );
    });

    test('o desconto anual e a economia são coerentes entre si', () {
      final fullPrice = PricingCatalog.monthly.price * 12;
      expect(
        PricingCatalog.annualSavings,
        closeTo(fullPrice - PricingCatalog.annual.price, 0.01),
      );
      expect(
        PricingCatalog.annualDiscountPercent,
        closeTo(PricingCatalog.annualSavings / fullPrice * 100, 0.01),
      );
    });

    test('o anual é a oferta destacada', () {
      expect(PricingCatalog.annual.highlight, isTrue);
      expect(PricingCatalog.offers.first, PricingCatalog.annual);
    });

    test('busca por id encontra as ofertas do catálogo', () {
      expect(PricingCatalog.offerById(PricingCatalog.annual.id), PricingCatalog.annual);
      expect(PricingCatalog.offerById('inexistente'), isNull);
    });
  });
}
