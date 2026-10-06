/// Format integer paise as rupees: en-IN digit grouping, exactly two
/// decimals, integer maths only.
///
///     formatPaise(199999)   == '₹1,999.99'
///     formatPaise(12345678) == '₹1,23,456.78'
///     formatPaise(5)        == '₹0.05'
///     formatPaise(0)        == '₹0.00'
///
/// Throws an [ArgumentError] if [paise] is negative.
String formatPaise(int paise) {
  if (paise < 0) {
    throw ArgumentError.value(paise, 'paise', 'must not be negative');
  }
  final rupees = paise ~/ 100;
  final fraction = paise % 100;
  final digits = rupees.toString();

  String grouped;
  if (digits.length <= 3) {
    grouped = digits;
  } else {
    // Last three digits, then groups of two going left.
    final head = digits.substring(0, digits.length - 3);
    final tail = digits.substring(digits.length - 3);
    final parts = <String>[];
    var i = head.length;
    while (i > 0) {
      final start = i - 2 < 0 ? 0 : i - 2;
      parts.insert(0, head.substring(start, i));
      i = start;
    }
    grouped = '${parts.join(',')},$tail';
  }
  return '₹$grouped.${fraction.toString().padLeft(2, '0')}';
}
