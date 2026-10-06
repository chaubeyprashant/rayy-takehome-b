import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'order_summary.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const RayyClientDemo());
}

class RayyClientDemo extends StatelessWidget {
  const RayyClientDemo({super.key});

  static const _ink = Color(0xFF14181C);
  static const _muted = Color(0xFF5C6670);
  static const _paper = Color(0xFFF2F4F6);
  static const _accent = Color(0xFF0F6B57);

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _accent,
        brightness: Brightness.light,
        primary: _accent,
        surface: Colors.white,
      ),
    );

    return MaterialApp(
      title: 'RAYY',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: GoogleFonts.manropeTextTheme(base.textTheme).copyWith(
          displaySmall: GoogleFonts.fraunces(
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
          headlineMedium: GoogleFonts.fraunces(
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
          titleLarge: GoogleFonts.fraunces(
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
        ),
      ),
      home: const _CheckoutScreen(),
    );
  }
}

class _CheckoutScreen extends StatelessWidget {
  const _CheckoutScreen();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          const _Backdrop(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
                  children: [
                    Text(
                      'RAYY',
                      style: textTheme.headlineMedium?.copyWith(
                        fontSize: 42,
                        letterSpacing: 1.2,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Confirm your order',
                      style: textTheme.titleMedium?.copyWith(
                        color: RayyClientDemo._muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const _DemoOrder(),
                    const SizedBox(height: 18),
                    Text(
                      'Payments are secured. Partner discounts settle monthly.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: RayyClientDemo._muted.withValues(alpha: 0.9),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE9EEF2),
            Color(0xFFF5F6F7),
            Color(0xFFE7EFEA),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _Blob(
              size: 240,
              color: const Color(0xFF0F6B57).withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            bottom: 40,
            left: -70,
            child: _Blob(
              size: 220,
              color: const Color(0xFFC4A35A).withValues(alpha: 0.10),
            ),
          ),
          CustomPaint(
            painter: _GridPainter(),
            child: const SizedBox.expand(),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF14181C).withValues(alpha: 0.035)
      ..strokeWidth = 1;

    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DemoOrder extends StatefulWidget {
  const _DemoOrder();

  @override
  State<_DemoOrder> createState() => _DemoOrderState();
}

class _DemoOrderState extends State<_DemoOrder> {
  late Map<String, dynamic> _order;
  var _failNext = true;

  @override
  void initState() {
    super.initState();
    _order = {
      'order_id': 'ord_demo_1',
      'subtotal_paise': 29999,
      'total_paise': 22499,
      'status': 'pending',
      'discount': {'code': 'BIG40', 'amount_paise': 7500},
    };
  }

  Future<void> _onPay() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (_failNext) {
      _failNext = false;
      throw Exception('gateway error');
    }
    setState(() {
      _order = {..._order, 'status': 'paid'};
    });
  }

  @override
  Widget build(BuildContext context) {
    return OrderSummary(order: _order, onPay: _onPay);
  }
}
