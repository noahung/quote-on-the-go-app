import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/expense.dart';
import 'auth_provider.dart';
import 'quotation_provider.dart';

part 'expense_provider.g.dart';

@riverpod
Stream<List<Expense>> expensesStream(ExpensesStreamRef ref) {
  final companyId = ref.watch(companyIdProvider);
  final firestore = ref.watch(firestoreProvider);
  if (companyId == null) return const Stream.empty();

  return firestore
      .collection('expenses')
      .where('companyId', isEqualTo: companyId)
      .snapshots()
      .map((snapshot) {
    final list =
        snapshot.docs.map((doc) => Expense.fromFirestore(doc)).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  });
}

class ExpenseRepository {
  final FirebaseFirestore _firestore;

  ExpenseRepository(this._firestore);

  Future<void> createExpense(Expense expense) async {
    await _firestore.collection('expenses').add({
      ...expense.toJson()..remove('id'),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateExpense(Expense expense) async {
    await _firestore.collection('expenses').doc(expense.id).update({
      ...expense.toJson()..remove('id'),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteExpense(String expenseId) async {
    await _firestore.collection('expenses').doc(expenseId).delete();
  }
}

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return ExpenseRepository(firestore);
});
