import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../insights/presentation/controllers/insights_controller.dart';
import '../../domain/plan.dart';
import '../controllers/entitlement_controller.dart';

/// Tela de venda do EcoStream Pro.
///
/// A estrutura segue a ordem que converte: primeiro **o número do usuário** (quanto
/// ele deixa de economizar hoje), depois o que o Pro entrega, depois o preço com o
/// anual ancorado contra o mensal, e só então o botão. Preço antes de valor
/// percebido é o erro clássico de paywall.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key, this.source});

  /// Onde o usuário tocou para chegar aqui. Serve para medir qual gatilho converte.
  final String? source;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  PlanOffer _selected = PricingCatalog.annual;

  @override
  void initState() {
    super.initState();
    AppLogger.info(
      'Paywall aberto (origem: ${widget.source ?? 'desconhecida'})',
      scope: 'billing',
    );
  }

  Future<void> _purchase() async {
    final ok = await ref.read(entitlementControllerProvider.notifier).purchase(_selected);
    if (!mounted) return;

    if (ok) {
      AppSnackBar.showSuccess(context, 'Bem-vindo ao EcoStream Pro!');
      context.pop();
    } else {
      final message = ref.read(entitlementControllerProvider).errorMessage;
      if (message != null) AppSnackBar.showError(context, message);
    }
  }

  Future<void> _startTrial() async {
    final ok = await ref.read(entitlementControllerProvider.notifier).startTrial();
    if (!mounted) return;

    if (ok) {
      AppSnackBar.showSuccess(
        context,
        'Teste de ${PricingCatalog.trialDuration.inDays} dias ativado.',
      );
      context.pop();
    } else {
      final message = ref.read(entitlementControllerProvider).errorMessage;
      if (message != null) AppSnackBar.showError(context, message);
    }
  }

  Future<void> _restore() async {
    final ok = await ref.read(entitlementControllerProvider.notifier).restore();
    if (!mounted) return;

    if (ok) {
      AppSnackBar.showSuccess(context, 'Assinatura restaurada.');
      context.pop();
    } else {
      AppSnackBar.showError(context, 'Nenhuma compra anterior encontrada.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(entitlementControllerProvider);
    final savings = ref.watch(potentialAnnualSavingsProvider);
    final hasUsedTrial = state.entitlements.hasUsedTrial;

    return Scaffold(
      appBar: AppBar(
        title: const Text('EcoStream Pro'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Fechar',
          onPressed: () => context.pop(),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: state.isPurchasing ? null : _restore,
            child: const Text('Restaurar'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: <Widget>[
            _ValueHeadline(annualSavings: savings),
            const SizedBox(height: 28),

            const SectionHeader(title: 'O que você desbloqueia'),
            const SizedBox(height: 12),
            const _BenefitList(),
            const SizedBox(height: 28),

            const SectionHeader(title: 'Escolha seu plano'),
            const SizedBox(height: 12),
            ...PricingCatalog.offers.map(
              (offer) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _OfferTile(
                  offer: offer,
                  selected: _selected.id == offer.id,
                  onTap: () => setState(() => _selected = offer),
                ),
              ),
            ),
            const SizedBox(height: 8),

            CustomButton(
              text: 'Assinar ${_selected.title.toLowerCase()} — '
                  '${CurrencyFormatter.format(_selected.price)}',
              isLoading: state.isPurchasing,
              onPressed: state.isPurchasing ? null : _purchase,
            ),

            if (!hasUsedTrial) ...<Widget>[
              const SizedBox(height: 12),
              CustomButton(
                text: 'Testar ${PricingCatalog.trialDuration.inDays} dias grátis',
                variant: ButtonVariant.outlined,
                onPressed: state.isPurchasing ? null : _startTrial,
              ),
            ],

            const SizedBox(height: 20),
            Text(
              'Renovação automática, cancele quando quiser. '
              'O valor é cobrado pela loja do seu aparelho.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Abertura da tela: o número do próprio usuário, não uma promessa genérica.
class _ValueHeadline extends StatelessWidget {
  const _ValueHeadline({required this.annualSavings});

  final double annualSavings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSavings = annualSavings > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppColors.primary, Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.savings_outlined, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                hasSavings ? 'IDENTIFICAMOS NA SUA CARTEIRA' : 'O QUE O PRO FAZ POR VOCÊ',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            hasSavings
                ? '${CurrencyFormatter.format(annualSavings)} por ano'
                : 'Encontre o que sobra',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasSavings
                ? 'É quanto suas assinaturas atuais estão custando a mais do que '
                    'precisariam. O Pro mostra exatamente onde, item por item.'
                : 'O Pro cruza uso, preço e ciclo de cobrança de cada assinatura e '
                    'aponta onde dá para cortar sem perder o que importa.',
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.45),
          ),
          if (hasSavings) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'O Pro anual custa '
                '${CurrencyFormatter.format(PricingCatalog.annual.price)} — '
                'menos de ${(PricingCatalog.annual.price / annualSavings * 100).round()}% '
                'do que você economiza.',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BenefitList extends StatelessWidget {
  const _BenefitList();

  static const List<(IconData, String, String)> _benefits = <(IconData, String, String)>[
    (
      Icons.all_inclusive,
      'Assinaturas ilimitadas',
      'O plano gratuito para em ${FreePlanLimits.maxSubscriptions}. Quem tem o '
          'problema costuma ter o dobro disso.',
    ),
    (
      Icons.swap_horiz_rounded,
      'Consultor de plano anual',
      'Mostra quanto você economiza migrando de mensal para anual, serviço a serviço.',
    ),
    (
      Icons.content_copy_outlined,
      'Detecção de serviços sobrepostos',
      'Aponta quando três streamings entregam o mesmo catálogo.',
    ),
    (
      Icons.trending_up_rounded,
      'Alerta de reajuste',
      'Avisa quando um serviço aumenta de preço sem você perceber.',
    ),
    (
      Icons.notifications_active_outlined,
      'Lembretes personalizados',
      'Escolha a antecedência de cada aviso, em vez de um único dia fixo.',
    ),
    (
      Icons.download_outlined,
      'Exportação em CSV',
      'Leve seus dados para a planilha ou para o contador.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: _benefits.map((benefit) {
        final (icon, title, description) = benefit;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.pro.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: AppColors.pro),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: theme.textTheme.titleMedium?.copyWith(fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(description, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _OfferTile extends StatelessWidget {
  const _OfferTile({
    required this.offer,
    required this.selected,
    required this.onTap,
  });

  final PlanOffer offer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAnnual = offer.months == 12;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        offer.title,
                        style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
                      ),
                      if (offer.badge != null) ...<Widget>[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.pro.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            offer.badge!,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.pro,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${CurrencyFormatter.format(offer.monthlyEquivalent)} por mês',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (isAnnual) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      'Economize ${CurrencyFormatter.format(PricingCatalog.annualSavings)} '
                      'no ano (${PricingCatalog.annualDiscountPercent.round()}% off)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              CurrencyFormatter.format(offer.price),
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
