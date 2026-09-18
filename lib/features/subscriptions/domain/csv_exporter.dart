import '../../../core/utils/date_formatter.dart';
import '../../categories/domain/category_model.dart';
import 'subscription_model.dart';

/// Serialização das assinaturas para CSV.
///
/// Usa **ponto e vírgula** como separador: o Excel em português interpreta a vírgula
/// como separador decimal, então um CSV com vírgulas abre tudo numa só coluna para o
/// usuário brasileiro. Os valores também saem no formato pt-BR (1.234,56).
class CsvExporter {
  CsvExporter._();

  static const String separator = ';';

  static const List<String> headers = <String>[
    'Nome',
    'Categoria',
    'Valor',
    'Periodicidade',
    'Equivalente mensal',
    'Equivalente anual',
    'Proxima cobranca',
    'Status',
    'Forma de pagamento',
    'Uso',
    'Observacoes',
  ];

  static String subscriptionsToCsv(List<SubscriptionModel> subscriptions) {
    final buffer = StringBuffer()..writeln(headers.join(separator));

    for (final sub in subscriptions) {
      buffer.writeln(
        <String>[
          _escape(sub.name),
          _escape(CategoryModel.byId(sub.categoryId).name),
          _number(sub.price),
          sub.cycle.label,
          _number(sub.monthlyEquivalent),
          _number(sub.annualEquivalent),
          DateFormatter.short(sub.nextBillingDate),
          sub.status.label,
          _escape(sub.paymentMethod),
          sub.usageLevel.label,
          _escape(sub.notes ?? ''),
        ].join(separator),
      );
    }

    return buffer.toString();
  }

  /// Formata número no padrão pt-BR, sem símbolo de moeda.
  static String _number(double value) => value.toStringAsFixed(2).replaceAll('.', ',');

  /// Protege o campo contra o separador e contra quebras de linha.
  ///
  /// Uma observação com ponto e vírgula desalinharia todas as colunas seguintes.
  static String _escape(String value) {
    final normalized = value.replaceAll('\r\n', ' ').replaceAll('\n', ' ');
    if (!normalized.contains(separator) && !normalized.contains('"')) {
      return normalized;
    }
    return '"${normalized.replaceAll('"', '""')}"';
  }
}
