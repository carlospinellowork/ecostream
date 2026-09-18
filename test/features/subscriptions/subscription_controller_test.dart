import 'package:ecostream/core/domain/billing_cycle.dart';
import 'package:ecostream/core/error/app_exception.dart';
import 'package:ecostream/core/storage/key_value_store.dart';
import 'package:ecostream/features/billing/domain/entitlements.dart';
import 'package:ecostream/features/billing/domain/plan.dart';
import 'package:ecostream/features/subscriptions/data/subscription_repository.dart';
import 'package:ecostream/features/subscriptions/domain/subscription_model.dart';
import 'package:ecostream/features/subscriptions/presentation/controllers/subscription_controller.dart';
import 'package:flutter_test/flutter_test.dart';

const String _userId = 'usr_test';
final DateTime _now = DateTime(2026, 9, 17);

SubscriptionModel _sub({
  required String id,
  String name = 'Servico',
  double price = 50,
  String categoryId = 'cat_streaming',
  BillingCycle cycle = BillingCycle.monthly,
  DateTime? nextBilling,
  SubscriptionStatus status = SubscriptionStatus.active,
}) {
  final billing = nextBilling ?? DateTime(2026, 10, 10);
  return SubscriptionModel(
    id: id,
    userId: _userId,
    name: name,
    categoryId: categoryId,
    price: price,
    cycle: cycle,
    billingDay: billing.day,
    nextBillingDate: billing,
    paymentMethod: 'Pix',
    createdAt: DateTime(2025),
    status: status,
  );
}

void main() {
  late InMemoryKeyValueStore store;
  late LocalSubscriptionRepository repository;
  var seedRequested = false;
  var seedMarked = false;

  SubscriptionController build({bool shouldSeedDemo = false}) {
    return SubscriptionController(
      repository: repository,
      userId: _userId,
      clock: () => _now,
      shouldSeedDemo: () {
        seedRequested = true;
        return shouldSeedDemo && !seedMarked;
      },
      markSeeded: () async {
        seedMarked = true;
      },
    );
  }

  setUp(() {
    store = InMemoryKeyValueStore();
    repository = LocalSubscriptionRepository(store: store);
    seedRequested = false;
    seedMarked = false;
  });

  /// O controller carrega no construtor; esperar um microtask basta porque o
  /// repositório em memória resolve imediatamente.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('carregamento', () {
    test('conta sem dados e sem semente fica vazia e pronta', () async {
      final controller = build();
      await settle();

      expect(controller.state.status, LoadStatus.ready);
      expect(controller.state.subscriptions, isEmpty);
      expect(controller.state.isEmpty, isTrue);
      expect(seedRequested, isTrue);
      expect(seedMarked, isFalse);
    });

    test('conta de demonstração recebe a carteira de exemplo, uma vez só', () async {
      final first = build(shouldSeedDemo: true);
      await settle();

      expect(first.state.subscriptions, isNotEmpty);
      expect(seedMarked, isTrue);
      final seededCount = first.state.subscriptions.length;

      // Um segundo controller sobre o mesmo storage não duplica nem re-semeia.
      final second = build(shouldSeedDemo: true);
      await settle();
      expect(second.state.subscriptions, hasLength(seededCount));
    });

    test('a semente é persistida, não só mantida em memória', () async {
      build(shouldSeedDemo: true);
      await settle();

      final persisted = await repository.loadAll(_userId);
      expect(persisted.valueOrNull, isNotEmpty);
    });

    test('rola para a frente datas de cobrança que já passaram', () async {
      await repository.saveAll(_userId, <SubscriptionModel>[
        _sub(id: '1', nextBilling: DateTime(2025, 3, 10)),
      ]);

      final controller = build();
      await settle();

      // 10/03/2025 mensal, visto em 17/09/2026, cai em 10/10/2026.
      expect(controller.state.subscriptions.single.nextBillingDate, DateTime(2026, 10, 10));
    });

    test('registro corrompido não impede o carregamento dos válidos', () async {
      await store.setJsonList('data.subscriptions.$_userId', <Map<String, dynamic>>[
        _sub(id: '1', name: 'Valida').toJson(),
        <String, dynamic>{'id': 'quebrada'},
      ]);

      final controller = build();
      await settle();

      expect(controller.state.subscriptions, hasLength(1));
      expect(controller.state.subscriptions.single.name, 'Valida');
    });
  });

  group('limite do plano', () {
    test('o plano gratuito recusa além do limite', () async {
      final controller = build();
      await settle();

      for (var i = 0; i < FreePlanLimits.maxSubscriptions; i++) {
        final error = await controller.addSubscription(
          _sub(id: 'sub_$i'),
          entitlements: Entitlements.free,
        );
        expect(error, isNull, reason: 'a assinatura $i deveria ser aceita');
      }

      final error = await controller.addSubscription(
        _sub(id: 'sub_extra'),
        entitlements: Entitlements.free,
      );
      expect(error, isA<EntitlementException>());
      expect(controller.state.activeCount, FreePlanLimits.maxSubscriptions);
    });

    test('o Pro não tem limite', () async {
      final controller = build();
      await settle();

      for (var i = 0; i < FreePlanLimits.maxSubscriptions + 4; i++) {
        final error = await controller.addSubscription(
          _sub(id: 'sub_$i'),
          entitlements: const Entitlements(plan: Plan.pro),
        );
        expect(error, isNull);
      }
      expect(controller.state.activeCount, FreePlanLimits.maxSubscriptions + 4);
    });

    test('assinaturas pausadas não consomem vaga do plano gratuito', () async {
      final controller = build();
      await settle();

      for (var i = 0; i < FreePlanLimits.maxSubscriptions; i++) {
        await controller.addSubscription(
          _sub(id: 'sub_$i'),
          entitlements: Entitlements.free,
        );
      }
      await controller.setStatus('sub_0', SubscriptionStatus.paused);

      final error = await controller.addSubscription(
        _sub(id: 'sub_nova'),
        entitlements: Entitlements.free,
      );
      expect(error, isNull);
    });
  });

  group('mutações', () {
    test('adicionar persiste no repositório', () async {
      final controller = build();
      await settle();

      await controller.addSubscription(
        _sub(id: '1', name: 'Netflix'),
        entitlements: Entitlements.free,
      );

      final persisted = await repository.loadAll(_userId);
      expect(persisted.valueOrNull, hasLength(1));
      expect(persisted.valueOrNull!.single.name, 'Netflix');
    });

    test('mudar o preço arquiva o anterior no histórico', () async {
      final controller = build();
      await settle();
      await controller.addSubscription(
        _sub(id: '1', price: 49.90),
        entitlements: Entitlements.free,
      );

      final current = controller.state.subscriptions.single;
      await controller.updateSubscription(current.copyWith(price: 59.90));

      final updated = controller.state.subscriptions.single;
      expect(updated.price, closeTo(59.90, 0.01));
      expect(updated.priceHistory, hasLength(1));
      expect(updated.priceHistory.single.price, closeTo(49.90, 0.01));
    });

    test('editar sem mudar o preço não cria registro de histórico', () async {
      final controller = build();
      await settle();
      await controller.addSubscription(
        _sub(id: '1', price: 49.90),
        entitlements: Entitlements.free,
      );

      final current = controller.state.subscriptions.single;
      await controller.updateSubscription(current.copyWith(name: 'Outro nome'));

      expect(controller.state.subscriptions.single.priceHistory, isEmpty);
      expect(controller.state.subscriptions.single.name, 'Outro nome');
    });

    test('excluir remove do repositório', () async {
      final controller = build();
      await settle();
      await controller.addSubscription(_sub(id: '1'), entitlements: Entitlements.free);
      await controller.deleteSubscription('1');

      expect(controller.state.subscriptions, isEmpty);
      expect((await repository.loadAll(_userId)).valueOrNull, isEmpty);
    });

    test('cancelar em lote marca todas as informadas', () async {
      final controller = build();
      await settle();
      for (final id in <String>['1', '2', '3']) {
        await controller.addSubscription(_sub(id: id), entitlements: Entitlements.free);
      }

      await controller.cancelMany(<String>['1', '3']);

      final byId = <String, SubscriptionModel>{
        for (final s in controller.state.subscriptions) s.id: s,
      };
      expect(byId['1']!.status, SubscriptionStatus.cancelled);
      expect(byId['2']!.status, SubscriptionStatus.active);
      expect(byId['3']!.status, SubscriptionStatus.cancelled);
      expect(controller.state.activeCount, 1);
    });

    test('mudar o nível de uso persiste', () async {
      final controller = build();
      await settle();
      await controller.addSubscription(_sub(id: '1'), entitlements: Entitlements.free);

      await controller.setUsageLevel('1', UsageLevel.never);
      expect(controller.state.subscriptions.single.usageLevel, UsageLevel.never);
    });
  });

  group('totais e derivados', () {
    Future<SubscriptionController> withWallet() async {
      final controller = build();
      await settle();
      await controller.addSubscription(
        _sub(id: '1', name: 'Netflix', price: 60),
        entitlements: const Entitlements(plan: Plan.pro),
      );
      await controller.addSubscription(
        _sub(id: '2', name: 'PS Plus', price: 480, cycle: BillingCycle.annual),
        entitlements: const Entitlements(plan: Plan.pro),
      );
      await controller.addSubscription(
        _sub(
          id: '3',
          name: 'Pausada',
          price: 100,
          status: SubscriptionStatus.paused,
        ),
        entitlements: const Entitlements(plan: Plan.pro),
      );
      return controller;
    }

    test('o total mensal ignora pausadas e normaliza o ciclo', () async {
      final controller = await withWallet();
      // 60 (mensal) + 40 (480/12) = 100. A pausada de 100 não entra.
      expect(controller.state.totalMonthlySpend, closeTo(100, 0.01));
      expect(controller.state.totalAnnualSpend, closeTo(1200, 0.01));
      expect(controller.state.activeCount, 2);
    });

    test('o gasto por categoria soma só as ativas', () async {
      final controller = await withWallet();
      final byCategory = controller.state.spendByCategory;
      expect(byCategory['cat_streaming'], closeTo(100, 0.01));
    });

    test('upcomingBilling respeita a janela de dias', () async {
      final controller = build();
      await settle();
      await controller.addSubscription(
        _sub(id: '1', name: 'Perto', nextBilling: DateTime(2026, 9, 20)),
        entitlements: Entitlements.free,
      );
      await controller.addSubscription(
        _sub(id: '2', name: 'Longe', nextBilling: DateTime(2026, 10, 20)),
        entitlements: Entitlements.free,
      );

      final upcoming = controller.state.upcomingBilling(now: _now);
      expect(upcoming, hasLength(1));
      expect(upcoming.single.name, 'Perto');
    });

    test('upcomingBilling inclui cobrança de hoje', () async {
      final controller = build();
      await settle();
      await controller.addSubscription(
        _sub(id: '1', nextBilling: _now),
        entitlements: Entitlements.free,
      );

      expect(controller.state.upcomingBilling(now: _now), hasLength(1));
    });
  });

  group('filtros e ordenação', () {
    Future<SubscriptionController> withWallet() async {
      final controller = build();
      await settle();
      await controller.addSubscription(
        _sub(
          id: '1',
          name: 'Zelda Pass',
          price: 30,
          categoryId: 'cat_games',
          nextBilling: DateTime(2026, 11),
        ),
        entitlements: const Entitlements(plan: Plan.pro),
      );
      await controller.addSubscription(
        _sub(
          id: '2',
          name: 'Netflix',
          price: 60,
          nextBilling: DateTime(2026, 10),
        ),
        entitlements: const Entitlements(plan: Plan.pro),
      );
      await controller.addSubscription(
        _sub(
          id: '3',
          name: 'Antiga',
          price: 10,
          status: SubscriptionStatus.cancelled,
          nextBilling: DateTime(2026, 12),
        ),
        entitlements: const Entitlements(plan: Plan.pro),
      );
      return controller;
    }

    test('a busca é insensível a caixa', () async {
      final controller = await withWallet();
      controller.setSearchQuery('NETFLIX');
      expect(controller.state.filteredSubscriptions.single.name, 'Netflix');
    });

    test('filtra por categoria', () async {
      final controller = await withWallet();
      controller.setCategoryFilter('cat_games');
      expect(controller.state.filteredSubscriptions.single.name, 'Zelda Pass');
    });

    test('filtra por status', () async {
      final controller = await withWallet();
      controller.setStatusFilter(StatusFilter.cancelled);
      expect(controller.state.filteredSubscriptions.single.name, 'Antiga');
    });

    test('ordena por próximo vencimento por padrão', () async {
      final controller = await withWallet();
      expect(
        controller.state.filteredSubscriptions.map((s) => s.name).toList(),
        <String>['Netflix', 'Zelda Pass', 'Antiga'],
      );
    });

    test('ordena por maior e menor valor', () async {
      final controller = await withWallet();

      controller.setSortBy(SubscriptionSort.priceDesc);
      expect(controller.state.filteredSubscriptions.first.name, 'Netflix');

      controller.setSortBy(SubscriptionSort.priceAsc);
      expect(controller.state.filteredSubscriptions.first.name, 'Antiga');
    });

    test('ordena por nome ignorando caixa', () async {
      final controller = await withWallet();
      controller.setSortBy(SubscriptionSort.name);
      expect(
        controller.state.filteredSubscriptions.map((s) => s.name).toList(),
        <String>['Antiga', 'Netflix', 'Zelda Pass'],
      );
    });

    test('clearFilters devolve a lista inteira', () async {
      final controller = await withWallet();
      controller
        ..setSearchQuery('netflix')
        ..setCategoryFilter('cat_games')
        ..setStatusFilter(StatusFilter.active);
      expect(controller.state.hasActiveFilters, isTrue);

      controller.clearFilters();
      expect(controller.state.hasActiveFilters, isFalse);
      expect(controller.state.filteredSubscriptions, hasLength(3));
    });

    test('limpar o filtro de categoria volta a mostrar tudo', () async {
      // Regressão: o `copyWith` precisa de sentinela para conseguir voltar um
      // campo anulável para null.
      final controller = await withWallet();
      controller.setCategoryFilter('cat_games');
      expect(controller.state.filteredSubscriptions, hasLength(1));

      controller.setCategoryFilter(null);
      expect(controller.state.categoryFilter, isNull);
      expect(controller.state.filteredSubscriptions, hasLength(3));
    });
  });
}
