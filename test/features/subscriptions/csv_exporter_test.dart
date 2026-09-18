import 'package:ecostream/core/domain/billing_cycle.dart';
import 'package:ecostream/features/subscriptions/domain/csv_exporter.dart';
import 'package:ecostream/features/subscriptions/domain/subscription_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

SubscriptionModel _sub({String name = 'Netflix', String? notes}) {
  return SubscriptionModel(
    id: 'sub_1',
    userId: 'usr_1',
    name: name,
    categoryId: 'cat_streaming',
    price: 1234.56,
    cycle: BillingCycle.monthly,
    billingDay: 10,
    nextBillingDate: DateTime(2026, 10, 10),
    paymentMethod: 'Cartão de Crédito',
    createdAt: DateTime(2025),
    notes: notes,
  );
}

void main() {
  setUpAll(() {
    // O DateFormatter usa locale pt_BR explícito; sem os dados carregados o
    // `intl` lança LocaleDataException.
    initializeDateFormatting('pt_BR');
  });

  group('CsvExporter', () {
    test('a primeira linha é o cabeçalho', () {
      final csv = CsvExporter.subscriptionsToCsv(<SubscriptionModel>[]);
      expect(csv.trim(), CsvExporter.headers.join(CsvExporter.separator));
    });

    test('usa ponto e vírgula como separador', () {
      // Com vírgula, o Excel em português abriria tudo numa única coluna.
      expect(CsvExporter.separator, ';');
      final csv = CsvExporter.subscriptionsToCsv(<SubscriptionModel>[_sub()]);
      expect(csv.contains(';'), isTrue);
    });

    test('formata valores no padrão brasileiro', () {
      final csv = CsvExporter.subscriptionsToCsv(<SubscriptionModel>[_sub()]);
      expect(csv, contains('1234,56'));
    });

    test('gera uma linha por assinatura', () {
      final csv = CsvExporter.subscriptionsToCsv(<SubscriptionModel>[
        _sub(name: 'Netflix'),
        _sub(name: 'Spotify'),
      ]);
      final lines = csv.trim().split('\n');
      expect(lines, hasLength(3));
    });

    test('protege campo que contém o separador', () {
      final csv = CsvExporter.subscriptionsToCsv(<SubscriptionModel>[
        _sub(notes: 'plano familia; 4 telas'),
      ]);
      expect(csv, contains('"plano familia; 4 telas"'));
    });

    test('escapa aspas duplicando-as', () {
      final csv = CsvExporter.subscriptionsToCsv(<SubscriptionModel>[
        _sub(notes: 'plano "premium"'),
      ]);
      expect(csv, contains('""premium""'));
    });

    test('remove quebras de linha para não partir a linha do CSV', () {
      final csv = CsvExporter.subscriptionsToCsv(<SubscriptionModel>[
        _sub(notes: 'linha um\nlinha dois'),
      ]);
      final lines = csv.trim().split('\n');
      expect(lines, hasLength(2));
    });
  });
}
