import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import 'auth_provider.dart';
import 'quotation_provider.dart';

part 'customer_provider.g.dart';

// Stream of all customers for current company
@riverpod
Stream<List<Customer>> customersStream(Ref ref) {
  final companyId = ref.watch(companyIdProvider);
  final firestore = ref.watch(firestoreProvider);

  if (companyId == null) return Stream.value([]);

  return firestore
      .collection('customers')
      .where('companyId', isEqualTo: companyId)
      .snapshots()
      .map((snapshot) {
    final list =
        snapshot.docs.map((doc) => Customer.fromFirestore(doc)).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  });
}

// Provider for customers list
@riverpod
List<Customer> customers(Ref ref) {
  return ref.watch(customersStreamProvider).valueOrNull ?? [];
}

// Stream of a single customer
@riverpod
Stream<Customer?> customerStream(Ref ref, String customerId) {
  final firestore = ref.watch(firestoreProvider);

  return firestore
      .collection('customers')
      .doc(customerId)
      .snapshots()
      .map((doc) => doc.exists ? Customer.fromFirestore(doc) : null);
}

// Single customer provider
@riverpod
Customer? customer(Ref ref, String customerId) {
  return ref.watch(customerStreamProvider(customerId)).valueOrNull;
}

// Class for customer operations
class CustomerRepository {
  final FirebaseFirestore _firestore;

  CustomerRepository(this._firestore);

  Future<String> createCustomer(Customer customer) async {
    final docRef = _firestore.collection('customers').doc();
    final data = {
      ...customer.toJson(),
      'id': docRef.id,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await docRef.set(data);
    return docRef.id;
  }

  Future<void> updateCustomer(String id, Map<String, dynamic> data) async {
    await _firestore.collection('customers').doc(id).update(data);
  }

  Future<void> deleteCustomer(String id) async {
    await _firestore.collection('customers').doc(id).delete();
  }

  Future<Customer?> findByEmail(String email, String companyId) async {
    final snapshot = await _firestore
        .collection('customers')
        .where('companyId', isEqualTo: companyId)
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return Customer.fromFirestore(snapshot.docs.first);
  }
}

// Repository provider
final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return CustomerRepository(firestore);
});
