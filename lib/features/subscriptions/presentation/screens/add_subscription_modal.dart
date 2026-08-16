import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/financial_calculator.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../categories/domain/category_model.dart';
import '../../domain/subscription_model.dart';
import '../controllers/subscription_controller.dart';

class AddSubscriptionModal extends ConsumerStatefulWidget {
  final SubscriptionModel? subscriptionToEdit;

  const AddSubscriptionModal({super.key, this.subscriptionToEdit});

  @override
  ConsumerState<AddSubscriptionModal> createState() => _AddSubscriptionModalState();
}

class _AddSubscriptionModalState extends ConsumerState<AddSubscriptionModal> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _notesController;

  late String _selectedCategory;
  late String _selectedBillingCycle;
  late String _selectedPaymentMethod;
  late DateTime _nextBillingDate;

  double _monthlyEquivalent = 0.0;
  double _annualEquivalent = 0.0;

  @override
  void initState() {
    super.initState();
    final edit = widget.subscriptionToEdit;

    _nameController = TextEditingController(text: edit?.name ?? '');
    _priceController = TextEditingController(text: edit != null ? edit.price.toStringAsFixed(2) : '');
    _notesController = TextEditingController(text: edit?.notes ?? '');

    _selectedCategory = edit?.categoryId ?? CategoryModel.defaultCategories.first.id;
    _selectedBillingCycle = edit?.billingCycle ?? 'mensal';
    _selectedPaymentMethod = edit?.paymentMethod ?? AppConstants.paymentMethods.first;
    _nextBillingDate = edit?.nextBillingDate ?? DateTime.now().add(const Duration(days: 7));

    _recalculateFinancials();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _recalculateFinancials() {
    final priceStr = _priceController.text.replaceAll(',', '.');
    final price = double.tryParse(priceStr) ?? 0.0;

    setState(() {
      _monthlyEquivalent = FinancialCalculator.calculateMonthlyEquivalent(
        price: price,
        billingCycle: _selectedBillingCycle,
      );
      _annualEquivalent = FinancialCalculator.calculateAnnualEquivalent(
        price: price,
        billingCycle: _selectedBillingCycle,
      );
    });
  }

  void _onSave() {
    if (_formKey.currentState?.validate() ?? false) {
      final user = ref.read(authControllerProvider).user;
      final priceStr = _priceController.text.replaceAll(',', '.');
      final price = double.tryParse(priceStr) ?? 0.0;

      final isEdit = widget.subscriptionToEdit != null;
      final sub = SubscriptionModel(
        id: isEdit ? widget.subscriptionToEdit!.id : const Uuid().v4(),
        userId: user?.id ?? 'usr_demo_1',
        name: _nameController.text.trim(),
        categoryId: _selectedCategory,
        price: price,
        billingCycle: _selectedBillingCycle,
        billingDay: _nextBillingDate.day,
        nextBillingDate: _nextBillingDate,
        status: isEdit ? widget.subscriptionToEdit!.status : SubscriptionStatus.active,
        paymentMethod: _selectedPaymentMethod,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: isEdit ? widget.subscriptionToEdit!.createdAt : DateTime.now(),
      );

      final controller = ref.read(subscriptionControllerProvider.notifier);
      if (isEdit) {
        controller.updateSubscription(sub);
      } else {
        controller.addSubscription(sub);
      }

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra Superior / Título
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.subscriptionToEdit == null ? 'Nova Assinatura' : 'Editar Assinatura',
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),

              // Nome da Assinatura
              CustomTextField(
                label: 'Nome do Serviço / Assinatura',
                hint: 'Ex: Netflix, Spotify, ChatGPT...',
                controller: _nameController,
                validator: (val) => (val == null || val.isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 16),

              // Categoria e Periodicidade em Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Categoria',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          isExpanded: true,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: CategoryModel.defaultCategories.map((c) {
                            return DropdownMenuItem(
                              value: c.id,
                              child: Row(
                                children: [
                                  Icon(c.icon, size: 18, color: c.color),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(c.name, overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedCategory = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Periodicidade',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedBillingCycle,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: AppConstants.billingCycles.map((cycle) {
                            return DropdownMenuItem(
                              value: cycle,
                              child: Text(cycle[0].toUpperCase() + cycle.substring(1)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              _selectedBillingCycle = val;
                              _recalculateFinancials();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Valor e Forma de Pagamento
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      label: 'Valor (R\$)',
                      hint: '59,90',
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _recalculateFinancials(),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Informe o valor';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pagamento',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedPaymentMethod,
                          isExpanded: true,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: AppConstants.paymentMethods.map((pm) {
                            return DropdownMenuItem(value: pm, child: Text(pm, overflow: TextOverflow.ellipsis));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedPaymentMethod = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Data da Próxima Cobrança
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Data da Próxima Cobrança',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _nextBillingDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                      );
                      if (picked != null) {
                        setState(() => _nextBillingDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('dd/MM/yyyy').format(_nextBillingDate),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                          const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Painel de Recálculo Automático Financeiro
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Equivalente Mensal', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.formatBRL(_monthlyEquivalent),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                        ),
                      ],
                    ),
                    Container(height: 24, width: 1, color: AppColors.primary.withOpacity(0.3)),
                    Column(
                      children: [
                        const Text('Equivalente Anual', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.formatBRL(_annualEquivalent),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.secondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              CustomButton(
                text: widget.subscriptionToEdit == null ? 'Salvar Assinatura' : 'Atualizar Assinatura',
                onPressed: _onSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
