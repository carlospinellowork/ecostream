import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecostream/main.dart';

void main() {
  testWidgets('EcoStream App initial smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: EcoStreamApp()));
    await tester.pump();

    expect(find.byType(EcoStreamApp), findsOneWidget);
  });
}
