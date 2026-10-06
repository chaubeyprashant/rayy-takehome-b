import 'package:flutter_test/flutter_test.dart';
import 'package:rayy_client/main.dart';

void main() {
  testWidgets('demo app shows order summary', (tester) async {
    await tester.pumpWidget(const RayyClientDemo());
    expect(find.text('Order ord_demo_1'), findsOneWidget);
    expect(find.text('Pay'), findsOneWidget);
  });
}
