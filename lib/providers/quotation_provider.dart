import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import 'auth_provider.dart';
import 'collaboration_provider.dart';

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
  final Ref _ref;

  QuotationRepository(this._firestore, this._ref);

  Future<void> _checkAndInitiateApproval({
    required String docId,
    required String docType,
    required String companyId,
    required UserProfile userProfile,
  }) async {
    if (userProfile.role.toLowerCase() == 'member') {
      try {
        await _ref.read(collaborationRepositoryProvider).initiateApprovalWorkflow(
          documentId: docId,
          documentType: docType,
          workflowType: 'serial',
          userId: userProfile.uid,
          userName: userProfile.displayName ?? userProfile.email ?? 'Anonymous',
          userEmail: userProfile.email ?? '',
          companyId: companyId,
        );
      } catch (e) {
        debugPrint('[QuotationRepo] Failed to initiate approval workflow: $e');
      }
    }
  }

  Future<String> createQuotation(Quotation quotation) async {
    final userProfile = _ref.read(userProfileProvider);
    final isMember = userProfile?.role.toLowerCase() == 'member';

    final docRef = _firestore.collection('quotations').doc();
    final data = {
      ...quotation.toJson(),
      'items': quotation.items.map((i) => i.toJson()).toList(),
      'id': docRef.id,
      'requiresApproval': isMember ? true : false,
      'approvalStatus': isMember ? 'pending' : 'none',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await docRef.set(data);

    if (isMember && userProfile != null) {
      await _checkAndInitiateApproval(
        docId: docRef.id,
        docType: 'quotation',
        companyId: quotation.companyId,
        userProfile: userProfile,
      );
    }

    return docRef.id;
  }

  Future<void> updateQuotation(String id, Map<String, dynamic> data) async {
    final userProfile = _ref.read(userProfileProvider);
    final isMember = userProfile?.role.toLowerCase() == 'member';

    final updateData = {
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (isMember) {
      updateData['requiresApproval'] = true;
      updateData['approvalStatus'] = 'pending';
    }

    await _firestore.collection('quotations').doc(id).update(updateData);

    if (isMember && userProfile != null) {
      final snap = await _firestore.collection('quotations').doc(id).get();
      final companyId = snap.data()?['companyId'] as String? ?? userProfile.companyId;
      await _checkAndInitiateApproval(
        docId: id,
        docType: 'quotation',
        companyId: companyId,
        userProfile: userProfile,
      );
    }
  }

  Future<void> deleteQuotation(String id) async {
    await _firestore.collection('quotations').doc(id).delete();
  }

  Future<void> updateQuotationStatus(String id, String status) async {
    await _firestore.collection('quotations').doc(id).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Write in-app notification for owner/admin users (mirrors portalActions.ts)
    if (status == 'Accepted' || status == 'Declined' || status == 'Amended') {
      try {
        final snap = await _firestore.collection('quotations').doc(id).get();
        final data = snap.data();
        if (data != null) {
          final companyId = data['companyId'] as String?;
          final quotationNumber = data['quotationNumber'] as String? ?? id;
          final customerName = data['customerName'] as String? ?? 'A customer';
          if (companyId != null) {
            final usersSnap = await _firestore
                .collection('users')
                .where('companyId', isEqualTo: companyId)
                .where('role', whereIn: ['owner', 'admin'])
                .limit(5)
                .get();
            final typeMap = {
              'Accepted': 'quotation_accepted',
              'Declined': 'quotation_declined',
              'Amended': 'quotation_amended',
            };
            final titleMap = {
              'Accepted': 'Quotation Accepted',
              'Declined': 'Quotation Declined',
              'Amended': 'Amendment Requested',
            };
            final messageMap = {
              'Accepted': '$customerName accepted quotation $quotationNumber',
              'Declined': '$customerName declined quotation $quotationNumber',
              'Amended':
                  '$customerName requested changes to quotation $quotationNumber',
            };
            final type = typeMap[status]!;
            final title = titleMap[status]!;
            final message = messageMap[status]!;
            final batch = _firestore.batch();
            for (final userDoc in usersSnap.docs) {
              final notifRef =
                  _firestore.collection('user_notifications').doc();
              batch.set(notifRef, {
                'userId': userDoc.id,
                'companyId': companyId,
                'title': title,
                'message': message,
                'type': type,
                'relatedDocumentId': id,
                'link': '/quotations/$id',
                'isRead': false,
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
            await batch.commit();
          }
        }
      } catch (e) {
        debugPrint('[QuotationRepo] Failed to write status notification: $e');
      }
    }
  }
}

// Repository provider
final quotationRepositoryProvider = Provider<QuotationRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return QuotationRepository(firestore, ref);
});
