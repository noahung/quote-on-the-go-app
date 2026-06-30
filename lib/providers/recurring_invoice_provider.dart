import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import 'auth_provider.dart';
import 'quotation_provider.dart';


part 'recurring_invoice_provider.g.dart';

// Stream of all recurring invoices for the current company
@riverpod
Stream<List<RecurringInvoice>> recurringInvoicesStream(Ref ref) {
  final companyId = ref.watch(companyIdProvider);
  final repository = ref.watch(recurringInvoiceRepositoryProvider);

  if (companyId == null) return Stream.value([]);

  return repository.streamForCompany(companyId);
}

// Provider for recurring invoices list
@riverpod
List<RecurringInvoice> recurringInvoices(Ref ref) {
  return ref.watch(recurringInvoicesStreamProvider).valueOrNull ?? [];
}

// Stream of a single recurring invoice
@riverpod
Stream<RecurringInvoice?> recurringInvoiceStream(Ref ref, String id) {
  final repository = ref.watch(recurringInvoiceRepositoryProvider);
  return repository.streamSingle(id);
}

// Single recurring invoice provider
@riverpod
RecurringInvoice? recurringInvoice(Ref ref, String id) {
  return ref.watch(recurringInvoiceStreamProvider(id)).valueOrNull;
}

class RecurringInvoiceRepository {
  final FirebaseFirestore _firestore;

  RecurringInvoiceRepository(this._firestore);

  Stream<List<RecurringInvoice>> streamForCompany(String companyId) {
    return _firestore
        .collection('recurringInvoices')
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => RecurringInvoice.fromFirestore(doc))
          .toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(2000))
          .compareTo(a.createdAt ?? DateTime(2000)));
      return list;
    });
  }

  Stream<RecurringInvoice?> streamSingle(String id) {
    return _firestore
        .collection('recurringInvoices')
        .doc(id)
        .snapshots()
        .map((doc) => doc.exists ? RecurringInvoice.fromFirestore(doc) : null);
  }

  Future<String> createRecurringInvoice(RecurringInvoice recurringInvoice) async {
    final docRef = _firestore.collection('recurringInvoices').doc();
    final data = {
      ...recurringInvoice.toJson(),
      'items': recurringInvoice.items.map((i) => i.toJson()).toList(),
      'id': docRef.id,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await docRef.set(data);
    return docRef.id;
  }

  Future<void> updateRecurringInvoice(String id, Map<String, dynamic> data) async {
    await _firestore.collection('recurringInvoices').doc(id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteRecurringInvoice(String id) async {
    await _firestore.collection('recurringInvoices').doc(id).delete();
  }

  Future<void> toggleRecurringInvoiceStatus(String id, bool isActive) async {
    await _firestore.collection('recurringInvoices').doc(id).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> triggerManualRun(String id, String userId) async {
    final docRef = _firestore.collection('recurringInvoices').doc(id);
    final snap = await docRef.get();
    if (!snap.exists) {
      throw Exception('Recurring invoice not found');
    }
    final rec = RecurringInvoice.fromFirestore(snap);

    // Fetch company profile
    final companyDoc = await _firestore.collection('companies').doc(rec.companyId).get();
    final companyData = companyDoc.data();
    Map<String, dynamic>? companyProfile;
    if (companyData != null) {
      companyProfile = {
        'name': companyData['name'] ?? '',
        'address': companyData['address'] ?? '',
        'phone': companyData['phone'] ?? '',
        'email': companyData['email'] ?? '',
        'website': companyData['website'] ?? '',
        'bankAccounts': companyData['bankAccounts'] ?? [],
        'defaultTaxRate': companyData['defaultTaxRate'] ?? 5,
        'defaultHourlyRate': companyData['defaultHourlyRate'],
        'defaultPdfTemplateId': companyData['defaultPdfTemplateId'],
        'defaultPdfThemeColor': companyData['defaultPdfThemeColor'],
      };
    }

    // Generate a unique invoice number
    final timestampStr = DateTime.now().millisecondsSinceEpoch.toString();
    final sliceStart = timestampStr.length > 6 ? timestampStr.length - 6 : 0;
    final timestampPart = timestampStr.substring(sliceStart);
    final randomVal = 10 + (DateTime.now().microsecondsSinceEpoch % 90);
    final invoiceNumber = 'INV-REC-$timestampPart-$randomVal';

    final now = DateTime.now();
    final invoiceDate = now.toIso8601String();
    final dueDate = now.add(const Duration(days: 30)).toIso8601String();

    final newInvoiceRef = _firestore.collection('invoices').doc();
    final newInvoicePayload = {
      'id': newInvoiceRef.id,
      'companyId': rec.companyId,
      'createdBy': userId,
      'invoiceNumber': invoiceNumber,
      'customerName': rec.customerName,
      'customerEmail': rec.customerEmail,
      'customerPhone': rec.customerPhone ?? '',
      'customerAddress': rec.customerAddress ?? '',
      'date': invoiceDate,
      'dueDate': dueDate,
      'items': rec.items.map((i) => i.toJson()).toList(),
      'subtotal': rec.subtotal,
      'taxRate': rec.taxRate ?? 0.0,
      'taxAmount': rec.taxAmount ?? 0.0,
      'discount': rec.discount ?? 0.0,
      'discountType': rec.discountType ?? 'percentage',
      'discountAmount': rec.discountAmount ?? 0.0,
      'total': rec.total,
      'status': 'Sent',
      'notes': rec.notes ?? '',
      'company': companyProfile,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await newInvoiceRef.set(newInvoicePayload);
    final newInvoiceId = newInvoiceRef.id;

    // Calculate the next run date based on frequency
    final nextRun = DateTime.parse(rec.nextRunDate);
    DateTime calculatedNextRun;
    if (rec.frequency == 'weekly') {
      calculatedNextRun = nextRun.add(const Duration(days: 7));
    } else if (rec.frequency == 'monthly') {
      calculatedNextRun = DateTime(nextRun.year, nextRun.month + 1, nextRun.day);
    } else if (rec.frequency == 'quarterly') {
      calculatedNextRun = DateTime(nextRun.year, nextRun.month + 3, nextRun.day);
    } else if (rec.frequency == 'yearly') {
      calculatedNextRun = DateTime(nextRun.year + 1, nextRun.month, nextRun.day);
    } else {
      calculatedNextRun = DateTime(nextRun.year, nextRun.month + 1, nextRun.day);
    }

    bool shouldDeactivate = false;
    if (rec.endDate != null) {
      final end = DateTime.parse(rec.endDate!);
      if (calculatedNextRun.isAfter(end)) {
        shouldDeactivate = true;
      }
    }

    await docRef.update({
      'nextRunDate': calculatedNextRun.toIso8601String(),
      'lastRunAt': FieldValue.serverTimestamp(),
      'generatedInvoiceIds': FieldValue.arrayUnion([newInvoiceId]),
      'isActive': shouldDeactivate ? false : rec.isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return newInvoiceId;
  }
}

// Repository provider
final recurringInvoiceRepositoryProvider = Provider<RecurringInvoiceRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return RecurringInvoiceRepository(firestore);
});
