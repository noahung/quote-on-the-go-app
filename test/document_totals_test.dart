import 'package:flutter_test/flutter_test.dart';
import 'package:qotg_mobile/utils/document_totals.dart';

void main() {
  test('percentage discount is applied before tax', () {
    final result = DocumentTotals.calculate(subtotal: 100, discount: 10, taxRate: 20);
    expect(result.discountAmount, 10);
    expect(result.taxAmount, 18);
    expect(result.total, 108);
  });
  test('fixed discount is capped and credits preserve their sign', () {
    expect(DocumentTotals.calculate(subtotal: 50, discount: 80, discountType: 'fixed').total, 0);
    expect(DocumentTotals.calculate(subtotal: -100, discount: 10, taxRate: 20).total, -108);
  });
  test('money is rounded and invalid numbers rejected', () {
    expect(DocumentTotals.calculate(subtotal: 19.99, discount: 5, taxRate: 20).total, 22.79);
    expect(() => DocumentTotals.calculate(subtotal: double.nan), throwsFormatException);
    expect(() => DocumentTotals.calculate(subtotal: 10, discount: -1), throwsFormatException);
  });
}
