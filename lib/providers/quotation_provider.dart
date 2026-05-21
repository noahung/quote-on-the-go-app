import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import 'auth_provider.dart';

part 'quotation_provider.g.dart';

// Firestore instance provider
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

// Stream of all quotations for current company
@riverpod
Stream<List<Quotation>> quotationsStream(Ref ref) {
  final companyId = ref.watch(companyIdProvider);
  final firestore = ref.watch(firestoreProvider);

  if (companyId == null) return Stream.value([]);

  return firestore
      .collection('quotations')
      .where('companyId', isEqualTo: companyId)
      .snapshots()
      .map((snapshot) {
    final list = snapshot.docs
        .map((doc) => Quotation.fromFirestore(doc))
        .where((q) => !q.isArchived)
        .toList();
    list.sort((a, b) => (b.createdAt ?? DateTime(2000))
        .compareTo(a.createdAt ?? DateTime(2000)));
    return list;
  });
}

// Provider for quotations list
@riverpod
List<Quotation> quotations(Ref ref) {
  return ref.watch(quotationsStreamProvider).valueOrNull ?? [];
}

// Stream of a single quotation
@riverpod
Stream<Quotation?> quotationStream(Ref ref, String quotationId) {
  final firestore = ref.watch(firestoreProvider);

  return firestore
      .collection('quotations')
      .doc(quotationId)
      .snapshots()
      .map((doc) => doc.exists ? Quotation.fromFirestore(doc) : null);
}

// Single quotation provider
@riverpod
Quotation? quotation(Ref ref, String quotationId) {
  return ref.watch(quotationStreamProvider(quotationId)).valueOrNull;
}

// Quotations by status
@riverpod
List<Quotation> quotationsByStatus(Ref ref, String status) {
  final quotations = ref.watch(quotationsProvider);
  return quotations.where((q) => q.status == status).toList();
}

// Pending quotations count
@riverpod
int pendingQuotationsCount(Ref ref) {
  final quotations = ref.watch(quotationsProvider);
  return quotations
      .where((q) => q.status == 'Draft' || q.status == 'Sent')
      .length;
}

// Accepted quotations count
@riverpod
int acceptedQuotationsCount(Ref ref) {
  final quotations = ref.watch(quotationsProvider);
  return quotations.where((q) => q.status == 'Accepted').length;
}

// Class for quotation operations
class QuotationRepository {
  final FirebaseFirestore _firestore;

  QuotationRepository(this._firestore);

  Future<String> createQuotation(Quotation quotation) async {
    final docRef = _firestore.collection('quotations').doc();
    final data = {
      ...quotation.toJson(),
      'id': docRef.id,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await docRef.set(data);
    return docRef.id;
  }

  Future<void> updateQuotation(String id, Map<String, dynamic> data) async {
    await _firestore.collection('quotations').doc(id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteQuotation(String id) async {
    await _firestore.collection('quotations').doc(id).delete();
  }

  Future<void> updateQuotationStatus(String id, String status) async {
    await _firestore.collection('quotations').doc(id).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

// Repository provider
final quotationRepositoryProvider = Provider<QuotationRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return QuotationRepository(firestore);
});
