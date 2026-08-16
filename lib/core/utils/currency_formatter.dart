import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static String formatBRL(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }
}
