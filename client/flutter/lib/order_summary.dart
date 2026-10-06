import 'package:flutter/material.dart';

import 'format_paise.dart';

/// Shows the subtotal, the discount (code and amount) when there is one, and
/// the total, all through `formatPaise`, plus a Pay button.
///
/// [order] is the JSON from GET /orders/{id} plus discount info:
/// `order_id` (String), `subtotal_paise` (int), `total_paise` (int),
/// `status` (String, e.g. 'pending' or 'paid'), and `discount`
/// (null, or a map with `code` (String) and `amount_paise` (int)).
///
/// - The Pay button is an [ElevatedButton] whose child is `Text('Pay')`.
/// - It is disabled while [onPay] is pending (no double submit); it still
///   shows `Text('Pay')`.
/// - Only when `status` is 'paid' does it show `Text('Paid')`; it is then
///   disabled.
/// - If [onPay] throws, show a [Text] containing 'Payment failed' and
///   re-enable the button.
class OrderSummary extends StatefulWidget {
  const OrderSummary({super.key, required this.order, required this.onPay});

  final Map<String, dynamic> order;
  final Future<void> Function() onPay;

  @override
  State<OrderSummary> createState() => _OrderSummaryState();
}

class _OrderSummaryState extends State<OrderSummary> {
  bool _paying = false;
  bool _failed = false;

  Future<void> _pay() async {
    if (_paying) return;
    setState(() {
      _paying = true;
      _failed = false;
    });
    try {
      await widget.onPay();
      if (!mounted) return;
      setState(() => _paying = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _paying = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final discount = order['discount'] as Map<String, dynamic>?;
    final paid = order['status'] == 'paid';
    final enabled = !paid && !_paying;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Order ${order['order_id']}'),
        Text('Subtotal: ${formatPaise(order['subtotal_paise'] as int)}'),
        if (discount != null)
          Text('Discount (${discount['code']}): '
              '-${formatPaise(discount['amount_paise'] as int)}'),
        Text('Total: ${formatPaise(order['total_paise'] as int)}'),
        if (_failed && !paid) const Text('Payment failed. Please try again.'),
        ElevatedButton(
          onPressed: enabled ? _pay : null,
          child: Text(paid ? 'Paid' : 'Pay'),
        ),
      ],
    );
  }
}
