import 'package:intl/intl.dart';

/// Formatação de datas em pt-BR.
///
/// Os padrões dependem dos dados de locale, carregados em `bootstrap.dart` via
/// `initializeDateFormatting('pt_BR')`. Sem essa inicialização o `intl` lança
/// `LocaleDataException` na primeira formatação com locale explícito.
class DateFormatter {
  DateFormatter._();

  static const String _locale = 'pt_BR';

  static final DateFormat _short = DateFormat('dd/MM/yyyy', _locale);
  static final DateFormat _dayMonth = DateFormat('dd/MM', _locale);
  static final DateFormat _monthYear = DateFormat("MMMM 'de' yyyy", _locale);
  static final DateFormat _dayOfWeek = DateFormat('EEEE', _locale);
  static final DateFormat _longDate = DateFormat("d 'de' MMMM", _locale);

  /// `17/09/2026`
  static String short(DateTime date) => _short.format(date);

  /// `17/09`
  static String dayMonth(DateTime date) => _dayMonth.format(date);

  /// `setembro de 2026`
  static String monthYear(DateTime date) => _monthYear.format(date);

  /// `quinta-feira`
  static String dayOfWeek(DateTime date) => _dayOfWeek.format(date);

  /// `17 de setembro`
  static String longDate(DateTime date) => _longDate.format(date);

  /// `Setembro de 2026` — primeira letra maiúscula, para títulos.
  static String monthYearCapitalized(DateTime date) {
    final text = monthYear(date);
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
