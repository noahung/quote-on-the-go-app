import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/expense.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';
import '../../components/glass_card.dart';
import '../../components/mesh_background.dart';
import '../../components/curved_header.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesStreamProvider);

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            CurvedHeader(
              title: 'Expenses',
              actions: [
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: () => context.push('/expenses/new'),
                ),
              ],
            ),
            Expanded(
              child: expensesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
                data: (expenses) {
                  if (expenses.isEmpty) {
                    return AppEmptyState(
                      icon: LucideIcons.receipt,
                      title: 'No expenses yet',
                      subtitle: 'Track your business spending here.',
                      actionLabel: 'Add Expense',
                      onAction: () => context.push('/expenses/new'),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: expenses.length,
                    itemBuilder: (context, index) {
                      final expense = expenses[index];
                      return _ExpenseCard(
                        expense: expense,
                        onTap: () => context.push('/expenses/${expense.id}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final Expense expense;
  final VoidCallback? onTap;

  const _ExpenseCard({required this.expense, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    expense.merchant,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                StatusChip(status: expense.status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.category_outlined,
                    size: 16, color: colorScheme.outline),
                const SizedBox(width: 4),
                Text(
                  expense.category,
                  style: TextStyle(color: colorScheme.outline),
                ),
                const SizedBox(width: 16),
                Icon(Icons.calendar_today_outlined,
                    size: 16, color: colorScheme.outline),
                const SizedBox(width: 4),
                Text(
                  expense.date,
                  style: TextStyle(color: colorScheme.outline),
                ),
              ],
            ),
            if (expense.jobId != null && expense.jobId!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3), width: 0.6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.hammer, size: 11, color: Color(0xFF0284C7)),
                    SizedBox(width: 4),
                    Text(
                      'Job Linked',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (expense.description != null &&
                    expense.description!.isNotEmpty)
                  Expanded(
                    child: Text(
                      expense.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Text(
                  '-${NumberFormat.currency(symbol: expense.currency ?? '£').format(expense.amount)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
