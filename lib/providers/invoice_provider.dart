import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import 'auth_provider.dart';
import 'quotation_provider.dart';

part 'invoice_provider.g.dart';

// Stream of all invoices for current company
@riverpod
Stream<List<Invoice>> invoicesStream(Ref ref) {
  final companyId = ref.watch(companyIdProvider);
  final firestore = ref.watch(firestoreProvider);

  if (companyId == null) return Stream.value([]);

  return firestore
      .collection('invoices')
      .where('companyId', isEqualTo: companyId)
      .snapshots()
      .map((snapshot) {
    final list =
        snapshot.docs.map((doc) => Invoice.fromFirestore(doc)).toList();
    list.sort((a, b) => (b.createdAt ?? DateTime(2000))
        .compareTo(a.createdAt ?? DateTime(2000)));
    return list;
  });
}

// Provider for invoices list
@riverpod
List<Invoice> invoices(Ref ref) {
  return ref.watch(invoicesStreamProvider).valueOrNull ?? [];
}

// Stream of a single invoice
@riverpod
Stream<Invoice?> invoiceStream(Ref ref, String invoiceId) {
  final firestore = ref.watch(firestoreProvider);

  return firestore
      .collection('invoices')
      .doc(invoiceId)
      .snapshots()
      .map((doc) => doc.exists ? Invoice.fromFirestore(doc) : null);
}

// Single invoice provider
@riverpod
Invoice? invoice(Ref ref, String invoiceId) {
  return ref.watch(invoiceStreamProvider(invoiceId)).valueOrNull;
}

// Invoices by status
@riverpod
List<Invoice> invoicesByStatus(Ref ref, String status) {
  final invoices = ref.watch(invoicesProvider);
  return invoices.where((i) => i.status == status).toList();
}

// Active (sent/overdue) invoices count
@riverpod
int activeInvoicesCount(Ref ref) {
  final invoices = ref.watch(invoicesProvider);
  return invoices
      .where((i) => i.status == 'Sent' || i.status == 'Overdue')
      .length;
}

// Overdue invoices count
@riverpod
int overdueInvoicesCount(Ref ref) {
  final invoices = ref.watch(invoicesProvider);
  return invoices.where((i) => i.status == 'Overdue').length;
}

// Paid invoices total
@riverpod
double totalRevenue(Ref ref) {
  final invoices = ref.watch(invoicesProvider);
  return invoices
      .where((i) => i.status == 'Paid')
      .fold(0.0, (acc, i) => acc + i.total);
}

// Outstanding revenue
@riverpod
double outstandingRevenue(Ref ref) {
  final invoices = ref.watch(invoicesProvider);
  return invoices
      .where((i) => i.status == 'Sent' || i.status == 'Overdue')
      .fold(0.0, (acc, i) => acc + i.total);
}

// Class for invoice operations
class InvoiceRepository {
  final FirebaseFirestore _firestore;

  InvoiceRepository(this._firestore);

  Future<String> createInvoice(Invoice invoice) async {
    final docRef = _firestore.collection('invoices').doc();
    final data = {
      ...invoice.toJson(),
      'items': invoice.items.map((i) => i.toJson()).toList(),
      'id': docRef.id,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await docRef.set(data);
    return docRef.id;
  }

  Future<void> updateInvoice(String id, Map<String, dynamic> data) async {
    await _firestore.collection('invoices').doc(id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteInvoice(String id) async {
    await _firestore.collection('invoices').doc(id).delete();
  }

  Future<void> updateInvoiceStatus(String id, String status) async {
    final updateData = {
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (status == 'Paid') {
      updateData['paidAt'] = FieldValue.serverTimestamp();
    }

    await _firestore.collection('invoices').doc(id).update(updateData);

    // Write an in-app notification for owner/admin users when marked Paid
    if (status == 'Paid') {
      try {
        final invoiceSnap =
            await _firestore.collection('invoices').doc(id).get();
        final data = invoiceSnap.data();
        if (data != null) {
          final companyId = data['companyId'] as String?;
          final invoiceNumber = data['invoiceNumber'] as String? ?? id;
          final customerName = data['customerName'] as String? ?? 'Customer';
          if (companyId != null) {
            final usersSnap = await _firestore
                .collection('users')
                .where('companyId', isEqualTo: companyId)
                .where('role', whereIn: ['owner', 'admin'])
                .limit(5)
                .get();
            final batch = _firestore.batch();
            for (final userDoc in usersSnap.docs) {
              final notifRef =
                  _firestore.collection('user_notifications').doc();
              batch.set(notifRef, {
                'userId': userDoc.id,
                'companyId': companyId,
                'title': 'Invoice Paid',
                'message': '$customerName paid invoice $invoiceNumber',
                'type': 'invoice_paid',
                'relatedDocumentId': id,
                'link': '/invoices/$id',
                'isRead': false,
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
            await batch.commit();
          }
        }
      } catch (e) {
        // Non-fatal — status was already updated
        debugPrint('[InvoiceRepo] Failed to write paid notification: $e');
      }
    }
  }
}

// Repository provider
final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return InvoiceRepository(firestore);
});
