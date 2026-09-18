import '../../../core/domain/billing_cycle.dart';
import '../../../core/utils/recurrence.dart';
import '../domain/subscription_model.dart';

/// Carteira de exemplo usada quando o usuário entra pela primeira vez.
///
/// Antes essa lista era criada dentro do controller e reaparecia a cada abertura do
/// app, sobrescrevendo o que o usuário tinha cadastrado. Agora é semente: gravada
/// uma única vez, e a partir daí o dado é do usuário.
///
/// A composição é proposital — inclui serviços sem uso, streamings sobrepostos,
/// um com reajuste e um com plano anual mais barato — para que a tela de Insights
/// mostre valor real na primeira abertura, em vez de um estado vazio.
class DemoSubscriptions {
  DemoSubscriptions._();

  static List<SubscriptionModel> build({
    required String userId,
    DateTime? now,
  }) {
    final today = Recurrence.dateOnly(now ?? DateTime.now());

    DateTime inDays(int days) => today.add(Duration(days: days));

    return <SubscriptionModel>[
      SubscriptionModel(
        id: 'demo_netflix',
        userId: userId,
        name: 'Netflix',
        categoryId: 'cat_streaming',
        price: 59.90,
        cycle: BillingCycle.monthly,
        billingDay: inDays(1).day,
        nextBillingDate: inDays(1),
        paymentMethod: 'Cartão de Crédito',
        notes: 'Plano Premium 4K',
        usageLevel: UsageLevel.high,
        createdAt: today.subtract(const Duration(days: 610)),
        // Histórico: entrou a R$ 39,90 e já sofreu dois reajustes.
        priceHistory: <PricePoint>[
          PricePoint(price: 39.90, changedAt: today.subtract(const Duration(days: 610))),
          PricePoint(price: 49.90, changedAt: today.subtract(const Duration(days: 300))),
        ],
      ),
      SubscriptionModel(
        id: 'demo_spotify',
        userId: userId,
        name: 'Spotify',
        categoryId: 'cat_streaming',
        price: 21.90,
        cycle: BillingCycle.monthly,
        billingDay: inDays(3).day,
        nextBillingDate: inDays(3),
        paymentMethod: 'Cartão de Crédito',
        notes: 'Plano Individual',
        usageLevel: UsageLevel.high,
        createdAt: today.subtract(const Duration(days: 800)),
      ),
      SubscriptionModel(
        id: 'demo_gamepass',
        userId: userId,
        name: 'Game Pass Ultimate',
        categoryId: 'cat_games',
        price: 119.90,
        cycle: BillingCycle.monthly,
        billingDay: inDays(4).day,
        nextBillingDate: inDays(4),
        paymentMethod: 'Pix',
        usageLevel: UsageLevel.medium,
        createdAt: today.subtract(const Duration(days: 200)),
      ),
      SubscriptionModel(
        id: 'demo_chatgpt',
        userId: userId,
        name: 'ChatGPT Plus',
        categoryId: 'cat_ai',
        price: 97.70,
        cycle: BillingCycle.monthly,
        billingDay: inDays(5).day,
        nextBillingDate: inDays(5),
        paymentMethod: 'Cartão de Crédito',
        usageLevel: UsageLevel.high,
        createdAt: today.subtract(const Duration(days: 210)),
      ),
      SubscriptionModel(
        id: 'demo_disney',
        userId: userId,
        name: 'Disney+',
        categoryId: 'cat_streaming',
        price: 43.90,
        cycle: BillingCycle.monthly,
        billingDay: inDays(11).day,
        nextBillingDate: inDays(11),
        paymentMethod: 'Cartão de Crédito',
        // Assinado na época de um lançamento e esquecido desde então.
        usageLevel: UsageLevel.never,
        createdAt: today.subtract(const Duration(days: 420)),
      ),
      SubscriptionModel(
        id: 'demo_icloud',
        userId: userId,
        name: 'iCloud 200GB',
        categoryId: 'cat_cloud',
        price: 39.90,
        cycle: BillingCycle.monthly,
        billingDay: 5,
        nextBillingDate: Recurrence.clampToMonth(
          year: today.year,
          month: today.month + 1,
          day: 5,
        ),
        paymentMethod: 'Cartão de Crédito',
        usageLevel: UsageLevel.high,
        createdAt: today.subtract(const Duration(days: 1100)),
      ),
      SubscriptionModel(
        id: 'demo_prime',
        userId: userId,
        name: 'Prime Video',
        categoryId: 'cat_streaming',
        price: 19.90,
        cycle: BillingCycle.monthly,
        billingDay: 12,
        nextBillingDate: Recurrence.clampToMonth(
          year: today.year,
          month: today.month + 1,
          day: 12,
        ),
        paymentMethod: 'Cartão de Crédito',
        usageLevel: UsageLevel.medium,
        createdAt: today.subtract(const Duration(days: 580)),
        // Plano anual conhecido: habilita o insight de migração.
        annualPlanPrice: 179.00,
      ),
      SubscriptionModel(
        id: 'demo_canva',
        userId: userId,
        name: 'Canva Pro',
        categoryId: 'cat_software',
        price: 34.90,
        cycle: BillingCycle.monthly,
        billingDay: 14,
        nextBillingDate: Recurrence.clampToMonth(
          year: today.year,
          month: today.month + 1,
          day: 14,
        ),
        paymentMethod: 'Cartão de Crédito',
        usageLevel: UsageLevel.low,
        createdAt: today.subtract(const Duration(days: 380)),
        annualPlanPrice: 299.00,
      ),
      SubscriptionModel(
        id: 'demo_psplus',
        userId: userId,
        name: 'PlayStation Plus',
        categoryId: 'cat_games',
        price: 480.00,
        cycle: BillingCycle.annual,
        billingDay: 15,
        nextBillingDate: Recurrence.clampToMonth(
          year: today.year + 1,
          month: 2,
          day: 15,
        ),
        paymentMethod: 'Cartão de Crédito',
        usageLevel: UsageLevel.medium,
        createdAt: today.subtract(const Duration(days: 215)),
      ),
      SubscriptionModel(
        id: 'demo_jornal',
        userId: userId,
        name: 'Jornal O Globo',
        categoryId: 'cat_jornais',
        price: 30.90,
        cycle: BillingCycle.monthly,
        billingDay: 10,
        nextBillingDate: Recurrence.clampToMonth(
          year: today.year,
          month: today.month + 1,
          day: 10,
        ),
        paymentMethod: 'Débito Automático',
        usageLevel: UsageLevel.never,
        createdAt: today.subtract(const Duration(days: 480)),
      ),
      SubscriptionModel(
        id: 'demo_github',
        userId: userId,
        name: 'GitHub Pro',
        categoryId: 'cat_software',
        price: 24.00,
        cycle: BillingCycle.monthly,
        billingDay: 8,
        nextBillingDate: Recurrence.clampToMonth(
          year: today.year,
          month: today.month + 1,
          day: 8,
        ),
        paymentMethod: 'Cartão de Crédito',
        usageLevel: UsageLevel.high,
        createdAt: today.subtract(const Duration(days: 620)),
      ),
      SubscriptionModel(
        id: 'demo_smartfit',
        userId: userId,
        name: 'Smart Fit',
        categoryId: 'cat_academias',
        price: 119.90,
        cycle: BillingCycle.monthly,
        billingDay: 1,
        nextBillingDate: Recurrence.clampToMonth(
          year: today.year,
          month: today.month + 1,
          day: 1,
        ),
        paymentMethod: 'Cartão de Crédito',
        usageLevel: UsageLevel.low,
        createdAt: today.subtract(const Duration(days: 255)),
      ),
    ];
  }
}
