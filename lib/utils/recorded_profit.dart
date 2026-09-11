import '../models/invoice.dart';
import '../models/expense.dart';

/// An operational comparison of gross paid invoices and recorded expenses.
/// This is not an accounting net-profit or VAT calculation.
class RecordedProfit {
  const RecordedProfit(this.revenue, this.expenses, this.excludedCurrencyCount);
  final double revenue, expenses;
  final int excludedCurrencyCount;
  double get balance => revenue - expenses;
  double? get margin => revenue == 0 ? null : balance / revenue * 100;
  static DateTime periodStart(int days, DateTime now) {
    final utc = now.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day - days + 1);
  }

  static DateTime periodEnd(DateTime now) {
    final utc = now.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day + 1)
        .subtract(const Duration(milliseconds: 1));
  }

  static bool inRange(String date, DateTime cutoff, DateTime end) {
    // Date-only business records are UTC dates, matching the web report.
    final parsed =
        DateTime.tryParse(date.length == 10 ? '${date}T00:00:00Z' : date);
    return parsed != null && !parsed.isBefore(cutoff) && !parsed.isAfter(end);
  }

  String csvRows(DateTime start, DateTime end) => [
        'Period start (UTC),${start.toUtc().toIso8601String()}',
        'Period end (UTC),${end.toUtc().toIso8601String()}',
        'Paid invoices (GBP),${revenue.toStringAsFixed(2)}',
        'Recorded expenses (GBP),${expenses.toStringAsFixed(2)}',
        'Recorded balance (GBP),${balance.toStringAsFixed(2)}',
        'Recorded margin (%),${margin?.toStringAsFixed(2) ?? 'Unavailable'}',
        'Other currency expenses excluded,$excludedCurrencyCount',
        'Basis,"Paid invoice totals minus recorded GBP expenses by document date (UTC). Tax is included. This is an operational balance, not accounting net profit. Rejected, void, cancelled and deleted expenses are excluded."',
      ].join('\n');

  static RecordedProfit calculate(List<Invoice> invoices,
      List<Expense> expenses, DateTime cutoff, DateTime end) {
    final revenue = invoices
        .where((invoice) =>
            invoice.status == 'Paid' && inRange(invoice.date, cutoff, end))
        .fold(
            0.0,
            (sum, invoice) =>
                sum + (invoice.total.isFinite ? invoice.total : 0));
    final recorded = expenses.where((expense) =>
        inRange(expense.date, cutoff, end) &&
        !['rejected', 'void', 'cancelled', 'deleted']
            .contains(expense.status.trim().toLowerCase()));
    bool isGbp(Expense expense) =>
        expense.currency == null ||
        expense.currency!.trim().isEmpty ||
        ['GBP', '£'].contains(expense.currency!.trim().toUpperCase());
    return RecordedProfit(
        revenue,
        recorded.where(isGbp).fold(
            0.0,
            (sum, expense) =>
                sum + (expense.amount.isFinite ? expense.amount : 0)),
        recorded.where((expense) => !isGbp(expense)).length);
  }
}
