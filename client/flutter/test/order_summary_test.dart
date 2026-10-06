import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rayy_client/format_paise.dart';
import 'package:rayy_client/order_summary.dart';

Map<String, dynamic> _order({String status = 'pending', Map<String, dynamic>? discount}) => {
      'order_id': 'ord_test_1',
      'subtotal_paise': 29999,
      'total_paise': discount == null ? 29999 : 29999 - (discount['amount_paise'] as int),
      'status': status,
      'discount': discount,
    };

Future<void> _pump(WidgetTester tester, Map<String, dynamic> order, Future<void> Function() onPay) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: OrderSummary(order: order, onPay: onPay))));

ElevatedButton _button(WidgetTester tester) => tester.widget<ElevatedButton>(find.byType(ElevatedButton));

void main() {
  group('formatPaise', () {
    test('formats with Indian grouping', () {
      expect(formatPaise(0), '₹0.00');
      expect(formatPaise(5), '₹0.05');
      expect(formatPaise(100), '₹1.00');
      expect(formatPaise(99999), '₹999.99');
      expect(formatPaise(100000), '₹1,000.00');
      expect(formatPaise(199999), '₹1,999.99');
      expect(formatPaise(1000000), '₹10,000.00');
      expect(formatPaise(12345678), '₹1,23,456.78');
      expect(formatPaise(123456789), '₹12,34,567.89');
      expect(formatPaise(1234567890), '₹1,23,45,678.90');
    });

    test('throws on negative', () {
      expect(() => formatPaise(-1), throwsArgumentError);
    });
  });

  group('OrderSummary', () {
    testWidgets('renders', (tester) async {
      await _pump(tester, _order(), () async {});
      expect(find.byType(OrderSummary), findsOneWidget);
    });

    testWidgets('shows subtotal and total, no discount line', (tester) async {
      await _pump(tester, _order(), () async {});
      expect(find.text('Subtotal: ₹299.99'), findsOneWidget);
      expect(find.text('Total: ₹299.99'), findsOneWidget);
      expect(find.textContaining('Discount'), findsNothing);
    });

    testWidgets('shows discount code and amount', (tester) async {
      await _pump(tester, _order(discount: {'code': 'BIG40', 'amount_paise': 7500}), () async {});
      expect(find.text('Discount (BIG40): -₹75.00'), findsOneWidget);
      expect(find.text('Total: ₹224.99'), findsOneWidget);
    });

    testWidgets('Pay is disabled while payment in progress, still reads Pay', (tester) async {
      final completer = Completer<void>();
      var calls = 0;
      await _pump(tester, _order(), () {
        calls++;
        return completer.future;
      });
      expect(_button(tester).onPressed, isNotNull);
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(_button(tester).onPressed, isNull);
      expect(find.text('Pay'), findsOneWidget);
      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      expect(calls, 1);
      completer.complete();
      await tester.pump();
      expect(_button(tester).onPressed, isNotNull);
      expect(find.textContaining('Payment failed'), findsNothing);
    });

    testWidgets('paid order shows Paid and is disabled', (tester) async {
      await _pump(tester, _order(status: 'paid'), () async {});
      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('Pay'), findsNothing);
      expect(_button(tester).onPressed, isNull);
    });

    testWidgets('failure shows error and allows retry', (tester) async {
      var calls = 0;
      await _pump(tester, _order(), () async {
        calls++;
        if (calls == 1) throw Exception('boom');
      });
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Payment failed'), findsOneWidget);
      expect(_button(tester).onPressed, isNotNull);
      expect(find.text('Pay'), findsOneWidget);
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump();
      expect(calls, 2);
      expect(find.textContaining('Payment failed'), findsNothing);
    });
  });
}
