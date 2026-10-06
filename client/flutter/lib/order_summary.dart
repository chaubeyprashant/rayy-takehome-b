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

class _OrderSummaryState extends State<OrderSummary>
    with SingleTickerProviderStateMixin {
  bool _paying = false;
  bool _failed = false;
  late final AnimationController _enter;

  static const _ink = Color(0xFF14181C);
  static const _muted = Color(0xFF5C6670);
  static const _line = Color(0xFFE2E6EA);
  static const _surface = Color(0xFFFFFFFF);
  static const _mist = Color(0xFFF3F5F7);
  static const _accent = Color(0xFF0F6B57);
  static const _accentSoft = Color(0xFFE4F3EE);
  static const _danger = Color(0xFF9B2C2C);
  static const _dangerSoft = Color(0xFFF8EAEA);

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

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
    final textTheme = Theme.of(context).textTheme;

    final fade = CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(fade);

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _line),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: paid ? _accent : const Color(0xFFC4A35A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Order ${order['order_id']}',
                      style: textTheme.labelLarge?.copyWith(
                        color: _muted,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: paid ? _accentSoft : _mist,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      paid ? 'PAID' : 'PENDING',
                      style: textTheme.labelSmall?.copyWith(
                        color: paid ? _accent : _muted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Amount due',
                style: textTheme.labelMedium?.copyWith(
                  color: _muted,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                formatPaise(order['total_paise'] as int),
                style: textTheme.displaySmall?.copyWith(
                  color: _ink,
                  fontWeight: FontWeight.w600,
                  height: 1.05,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: _mist,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subtotal: ${formatPaise(order['subtotal_paise'] as int)}',
                      style: textTheme.bodyLarge?.copyWith(
                        color: _ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (discount != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _accentSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _accent.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Text(
                          'Discount (${discount['code']}): '
                          '-${formatPaise(discount['amount_paise'] as int)}',
                          style: textTheme.bodyMedium?.copyWith(
                            color: _accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(height: 1, color: _line),
                    const SizedBox(height: 12),
                    Text(
                      'Total: ${formatPaise(order['total_paise'] as int)}',
                      style: textTheme.titleMedium?.copyWith(
                        color: _ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (_failed && !paid) ...[
                const SizedBox(height: 14),
                AnimatedOpacity(
                  opacity: 1,
                  duration: const Duration(milliseconds: 220),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _dangerSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _danger.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      'Payment failed. Please try again.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: _danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: enabled ? _pay : null,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: paid ? _accent : _ink,
                    disabledBackgroundColor:
                        paid ? _accent.withValues(alpha: 0.55) : const Color(0xFF9AA3AB),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white.withValues(alpha: 0.92),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_paying) ...[
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Text(
                        paid ? 'Paid' : 'Pay',
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
