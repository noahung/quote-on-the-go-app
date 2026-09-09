/// Mirrors the web document calculation: discount first, then tax, rounded
/// to currency precision. Negative documents retain their credit direction.
class DocumentTotals {
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double total;

  const DocumentTotals({required this.subtotal, required this.discountAmount,
    required this.taxAmount, required this.total});

  factory DocumentTotals.calculate({required double subtotal,
    double taxRate = 0, double discount = 0, String discountType = 'percentage'}) {
    if (![subtotal, taxRate, discount].every((v) => v.isFinite) ||
        taxRate < 0 || discount < 0 ||
        !['percentage', 'fixed'].contains(discountType)) {
      throw const FormatException('Enter valid tax and discount amounts.');
    }
    final reduction = (discountType == 'percentage'
        ? subtotal.abs() * discount / 100 : discount).clamp(0.0, subtotal.abs());
    final discounted = subtotal.sign * (subtotal.abs() - reduction);
    final tax = discounted * taxRate / 100;
    double money(double value) => double.parse(value.toStringAsFixed(2));
    return DocumentTotals(subtotal: money(subtotal), discountAmount: money(reduction),
      taxAmount: money(tax), total: money(discounted + tax));
  }
}
