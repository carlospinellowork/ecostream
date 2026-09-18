import 'package:intl/intl.dart';

/// Formatação monetária em pt-BR.
///
/// Toda exibição de dinheiro passa por aqui. `toStringAsFixed(2)` cru produz
/// "59.90" em vez de "R$ 59,90", que é o formato que o usuário brasileiro espera.
class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _brl = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: r'R$',
  );

  static final NumberFormat _brlCompact = NumberFormat.compactCurrency(
    locale: 'pt_BR',
    symbol: r'R$',
    decimalDigits: 1,
  );

  static final NumberFormat _brlNoSymbol = NumberFormat.decimalPatternDigits(
    locale: 'pt_BR',
    decimalDigits: 2,
  );

  /// Formato padrão: `R$ 1.234,56`.
  static String format(double amount) => _brl.format(amount);

  /// Compacto para espaços apertados: `R$ 1,2 mil`.
  ///
  /// Use apenas em cards e gráficos. Em qualquer lugar onde o usuário precise
  /// conferir o valor exato, use [format].
  static String compact(double amount) => _brlCompact.format(amount);

  /// Sem símbolo: `1.234,56`. Para campos de edição e exportação CSV.
  static String plain(double amount) => _brlNoSymbol.format(amount);

  /// Valor seguido da unidade do ciclo: `R$ 59,90 / mês`.
  static String perUnit(double amount, String unitLabel) =>
      '${format(amount)} / $unitLabel';
}
