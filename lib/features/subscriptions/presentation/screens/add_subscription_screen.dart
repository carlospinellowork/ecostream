import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/domain/billing_cycle.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/financial_calculator.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_card.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../billing/presentation/controllers/entitlement_controller.dart';
import '../../../categories/domain/category_model.dart';
import '../../domain/subscription_model.dart';
import '../controllers/subscription_controller.dart';

/// Cadastro e edição de assinatura.
///
/// Virou tela cheia (antes era um bottom sheet): o formulário tem oito campos e um
/// seletor de data, e em aparelho pequeno com teclado aberto o sheet cobria o botão
/// de salvar. Como tela, também passou a ter rota própria — e portanto deep link e
/// botão "voltar" previsível.
class AddSubscriptionScreen extends ConsumerStatefulWidget {
  const AddSubscriptionScreen({super.key, this.subscriptionId});

  /// Quando informado, a tela edita a assinatura correspondente.
  final String? subscriptionId;

  @override
  ConsumerState<AddSubscriptionScreen> createState() => _AddSubscriptionScreenState();
}

class _AddSubscriptionScreenState extends ConsumerState<AddSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _annualPriceController = TextEditingController();
  final _notesController = TextEditingController();

  late String _categoryId;
  late BillingCycle _cycle;
  late String _paymentMethod;
  late DateTime _nextBillingDate;
  UsageLevel _usageLevel = UsageLevel.medium;

  SubscriptionModel? _editing;
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _categoryId = CategoryModel.defaultCategories.first.id;
    _cycle = BillingCycle.monthly;
    _paymentMethod = AppConstants.paymentMethods.first;
    _nextBillingDate = DateTime.now().add(const Duration(days: 7));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final id = widget.subscriptionId;
    if (id == null) return;

    // A assinatura vem do estado já carregado; ler aqui evita um FutureBuilder
    // só para preencher o formulário.
    final matches = ref
        .read(subscriptionControllerProvider)
        .subscriptions
        .where((s) => s.id == id);
    if (matches.isEmpty) return;
    final existing = matches.first;

    _editing = existing;
    _nameController.text = existing.name;
    _priceController.text = CurrencyFormatter.plain(existing.price);
    _annualPriceController.text = existing.annualPlanPrice == null
        ? ''
        : CurrencyFormatter.plain(existing.annualPlanPrice!);
    _notesController.text = existing.notes ?? '';
    _categoryId = existing.categoryId;
    _cycle = existing.cycle;
    _paymentMethod = existing.paymentMethod;
    _nextBillingDate = existing.nextBillingDate;
    _usageLevel = existing.usageLevel;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _annualPriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _price => Validators.parsePrice(_priceController.text) ?? 0;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextBillingDate,
      // Permite registrar cobrança de ontem: quem cadastra depois do débito precisa
      // informar a data real, senão o ciclo fica deslocado.
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: 'Próxima cobrança',
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) setState(() => _nextBillingDate = picked);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    final controller = ref.read(subscriptionControllerProvider.notifier);
    final userId = ref.read(currentUserProvider)?.id ?? '';
    final annualPrice = Validators.parsePrice(_annualPriceController.text);
    final notes = _notesController.text.trim();
    final existing = _editing;

    final subscription = SubscriptionModel(
      id: existing?.id ?? 'sub_${const Uuid().v4()}',
      userId: existing?.userId ?? userId,
      name: _nameController.text.trim(),
      categoryId: _categoryId,
      price: _price,
      cycle: _cycle,
      billingDay: _nextBillingDate.day,
      nextBillingDate: _nextBillingDate,
      status: existing?.status ?? SubscriptionStatus.active,
      paymentMethod: _paymentMethod,
      notes: notes.isEmpty ? null : notes,
      usageLevel: _usageLevel,
      createdAt: existing?.createdAt ?? DateTime.now(),
      priceHistory: existing?.priceHistory ?? const <PricePoint>[],
      annualPlanPrice: annualPrice,
    );

    final error = existing == null
        ? await controller.addSubscription(
            subscription,
            entitlements: ref.read(entitlementsProvider),
          )
        : await controller.updateSubscription(subscription);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      AppSnackBar.showError(context, error.message);
      // Limite do plano atingido: leva direto ao paywall, com a origem marcada.
      if (error is EntitlementException) {
        context.push('${AppRoutes.paywall}?origem=limite-assinaturas');
      }
      return;
    }

    AppSnackBar.showSuccess(
      context,
      existing == null ? 'Assinatura cadastrada.' : 'Assinatura atualizada.',
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = _editing != null;
    final monthly = FinancialCalculator.monthlyEquivalent(price: _price, cycle: _cycle);
    final annual = FinancialCalculator.annualEquivalent(price: _price, cycle: _cycle);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar assinatura' : 'Nova assinatura'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: <Widget>[
              CustomTextField(
                label: 'Nome do serviço',
                hint: 'Ex.: Netflix',
                controller: _nameController,
                prefixIcon: Icons.label_outline,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                validator: Validators.subscriptionName,
              ),
              const SizedBox(height: 20),

              CustomTextField(
                label: 'Valor cobrado',
                hint: '0,00',
                helperText: 'O valor de cada cobrança, não o total do ano.',
                controller: _priceController,
                prefixIcon: Icons.attach_money,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                validator: Validators.price,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),

              _CycleSelector(
                selected: _cycle,
                onChanged: (cycle) => setState(() => _cycle = cycle),
              ),
              const SizedBox(height: 16),

              // Prévia do impacto real. Mostrar o equivalente anual no momento do
              // cadastro é o que faz o usuário perceber o peso da assinatura.
              if (_price > 0)
                CustomCard(
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.06),
                  borderColor: theme.colorScheme.primary.withValues(alpha: 0.25),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.insights_outlined,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${CurrencyFormatter.format(monthly)} por mês',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 15,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              'Equivale a ${CurrencyFormatter.format(annual)} por ano',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              const SectionHeader(title: 'Categoria'),
              const SizedBox(height: 10),
              _CategoryPicker(
                selectedId: _categoryId,
                onChanged: (id) => setState(() => _categoryId = id),
              ),
              const SizedBox(height: 24),

              const SectionHeader(title: 'Próxima cobrança'),
              const SizedBox(height: 10),
              CustomCard(
                onTap: _pickDate,
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.event_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        DateFormatter.short(_nextBillingDate),
                        style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
                      ),
                    ),
                    Text('Alterar', style: TextStyle(color: theme.colorScheme.primary)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const SectionHeader(title: 'Forma de pagamento'),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _paymentMethod,
                items: AppConstants.paymentMethods
                    .map(
                      (method) => DropdownMenuItem<String>(
                        value: method,
                        child: Text(method),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) setState(() => _paymentMethod = value);
                },
              ),
              const SizedBox(height: 24),

              const SectionHeader(title: 'Com que frequência você usa?'),
              const SizedBox(height: 4),
              Text(
                'É o que permite identificar serviços que você paga e não aproveita.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              _UsagePicker(
                selected: _usageLevel,
                onChanged: (level) => setState(() => _usageLevel = level),
              ),
              const SizedBox(height: 24),

              if (_cycle != BillingCycle.annual) ...<Widget>[
                CustomTextField(
                  label: 'Preço do plano anual (opcional)',
                  hint: '0,00',
                  helperText: 'Informe para calcularmos quanto você economiza migrando.',
                  controller: _annualPriceController,
                  prefixIcon: Icons.calendar_today_outlined,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    return Validators.price(value);
                  },
                ),
                const SizedBox(height: 20),
              ],

              CustomTextField(
                label: 'Observações (opcional)',
                hint: 'Ex.: plano família, compartilhado com 3 pessoas',
                controller: _notesController,
                prefixIcon: Icons.notes_outlined,
                maxLines: 3,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: 28),

              CustomButton(
                text: isEditing ? 'Salvar alterações' : 'Cadastrar assinatura',
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CycleSelector extends StatelessWidget {
  const _CycleSelector({required this.selected, required this.onChanged});

  final BillingCycle selected;
  final ValueChanged<BillingCycle> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Periodicidade',
          style: theme.textTheme.labelLarge?.copyWith(
            fontSize: 14,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: BillingCycle.values
              .map(
                (cycle) => ChoiceChip(
                  label: Text(cycle.label),
                  selected: selected == cycle,
                  onSelected: (_) => onChanged(cycle),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.selectedId, required this.onChanged});

  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: CategoryModel.defaultCategories.map((category) {
        final selected = category.id == selectedId;
        return ChoiceChip(
          label: Text(category.name),
          avatar: Icon(category.icon, size: 16, color: category.color),
          selected: selected,
          selectedColor: category.color.withValues(alpha: 0.16),
          onSelected: (_) => onChanged(category.id),
        );
      }).toList(growable: false),
    );
  }
}

class _UsagePicker extends StatelessWidget {
  const _UsagePicker({required this.selected, required this.onChanged});

  final UsageLevel selected;
  final ValueChanged<UsageLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: UsageLevel.values
          .map(
            (level) => ChoiceChip(
              label: Text(level.label),
              selected: selected == level,
              onSelected: (_) => onChanged(level),
            ),
          )
          .toList(growable: false),
    );
  }
}
