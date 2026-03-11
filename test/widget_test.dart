import 'package:flutter_test/flutter_test.dart';
import 'package:deaf_assist/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DeafAssistApp());
    expect(find.byType(DeafAssistApp), findsOneWidget);
  });
}
