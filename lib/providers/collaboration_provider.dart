import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'quotation_provider.dart'; // to reuse firestoreProvider

class InternalComment {
  final String id;
  final String documentId;
  final String documentType;
  final String content;
  final String authorName;
  final String authorId;
  final String authorEmail;
  final DateTime createdAt;
  final bool isResolved;
  final List<String> mentions;
  final bool isPrivate;
  final String companyId;

  InternalComment({
    required this.id,
    required this.documentId,
    required this.documentType,
    required this.content,
    required this.authorName,
    required this.authorId,
    required this.authorEmail,
    required this.createdAt,
    required this.isResolved,
    required this.mentions,
    required this.isPrivate,
    required this.companyId,
  });

  factory InternalComment.fromMap(Map<String, dynamic> map, String docId) {
    final authorMap = map['author'] as Map<String, dynamic>? ?? {};
    DateTime parsedDate;
    final createdVal = map['createdAt'];
    if (createdVal is Timestamp) {
      parsedDate = createdVal.toDate();
    } else if (createdVal is String) {
      parsedDate = DateTime.tryParse(createdVal) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return InternalComment(
      id: docId,
      documentId: map['documentId'] as String? ?? '',
      documentType: map['documentType'] as String? ?? '',
      content: map['content'] as String? ?? '',
      authorName: authorMap['userName'] as String? ?? authorMap['displayName'] as String? ?? 'Anonymous',
      authorId: authorMap['userId'] as String? ?? authorMap['uid'] as String? ?? '',
      authorEmail: authorMap['userEmail'] as String? ?? authorMap['email'] as String? ?? '',
      createdAt: parsedDate,
      isResolved: map['isResolved'] as bool? ?? false,
      mentions: List<String>.from(map['mentions'] ?? []),
      isPrivate: map['isPrivate'] as bool? ?? true,
      companyId: map['companyId'] as String? ?? '',
    );
  }
}

class DocumentVersion {
  final String id;
  final String documentId;
  final String documentType;
  final int versionNumber;
  final String title;
  final List<Map<String, dynamic>> changes;
  final Map<String, dynamic> snapshot;
  final String createdByName;
  final String createdById;
  final DateTime createdAt;
  final bool isActive;
  final String companyId;

  DocumentVersion({
    required this.id,
    required this.documentId,
    required this.documentType,
    required this.versionNumber,
    required this.title,
    required this.changes,
    required this.snapshot,
    required this.createdByName,
    required this.createdById,
    required this.createdAt,
    required this.isActive,
    required this.companyId,
  });

  factory DocumentVersion.fromMap(Map<String, dynamic> map, String docId) {
    final createdByMap = map['createdBy'] as Map<String, dynamic>? ?? {};
    DateTime parsedDate;
    final createdVal = map['createdAt'];
    if (createdVal is Timestamp) {
      parsedDate = createdVal.toDate();
    } else if (createdVal is String) {
      parsedDate = DateTime.tryParse(createdVal) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return DocumentVersion(
      id: docId,
      documentId: map['documentId'] as String? ?? '',
      documentType: map['documentType'] as String? ?? '',
      versionNumber: map['versionNumber'] as int? ?? 1,
      title: map['title'] as String? ?? 'Version',
      changes: List<Map<String, dynamic>>.from(
        (map['changes'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? []
      ),
      snapshot: Map<String, dynamic>.from(map['snapshot'] ?? {}),
      createdByName: createdByMap['userName'] as String? ?? createdByMap['displayName'] as String? ?? 'Anonymous',
      createdById: createdByMap['userId'] as String? ?? createdByMap['uid'] as String? ?? '',
      createdAt: parsedDate,
      isActive: map['isActive'] as bool? ?? true,
      companyId: map['companyId'] as String? ?? '',
    );
  }
}

final collaborationCommentsProvider = StreamProvider.family<List<InternalComment>, ({String documentId, String documentType})>((ref, arg) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('internal_comments')
      .where('documentId', isEqualTo: arg.documentId)
      .where('documentType', isEqualTo: arg.documentType)
      .snapshots()
      .map((snapshot) {
        final list = snapshot.docs
            .map((doc) => InternalComment.fromMap(doc.data(), doc.id))
            .toList();
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return list;
      });
});

final collaborationVersionsProvider = StreamProvider.family<List<DocumentVersion>, ({String documentId, String documentType})>((ref, arg) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('document_versions')
      .where('documentId', isEqualTo: arg.documentId)
      .where('documentType', isEqualTo: arg.documentType)
      .snapshots()
      .map((snapshot) {
        final list = snapshot.docs
            .map((doc) => DocumentVersion.fromMap(doc.data(), doc.id))
            .toList();
        list.sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
        return list;
      });
});

class CollaborationRepository {
  final FirebaseFirestore _firestore;

  CollaborationRepository(this._firestore);

  Future<void> addComment({
    required String documentId,
    required String documentType,
    required String content,
    required String userId,
    required String userName,
    required String userEmail,
    required String companyId,
  }) async {
    final commentRef = _firestore.collection('internal_comments').doc();
    await commentRef.set({
      'id': commentRef.id,
      'documentId': documentId,
      'documentType': documentType,
      'content': content,
      'author': {
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
      },
      'createdAt': FieldValue.serverTimestamp(),
      'isResolved': false,
      'mentions': <String>[],
      'isPrivate': true,
      'companyId': companyId,
    });
  }

  Future<void> createVersion({
    required String documentId,
    required String documentType,
    required String title,
    required List<Map<String, dynamic>> changes,
    required Map<String, dynamic> snapshot,
    required String userId,
    required String userName,
    required String userEmail,
    required String companyId,
  }) async {
    final query = await _firestore
        .collection('document_versions')
        .where('documentId', isEqualTo: documentId)
        .where('documentType', isEqualTo: documentType)
        .orderBy('versionNumber', descending: true)
        .limit(1)
        .get();

    final int nextVersionNumber = query.docs.isEmpty
        ? 1
        : ((query.docs.first.data()['versionNumber'] as num?)?.toInt() ?? 0) + 1;

    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.update({'isActive': false});
    }

    final versionRef = _firestore.collection('document_versions').doc();
    await versionRef.set({
      'id': versionRef.id,
      'documentId': documentId,
      'documentType': documentType,
      'versionNumber': nextVersionNumber,
      'title': title,
      'changes': changes,
      'snapshot': snapshot,
      'createdBy': {
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
      },
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
      'companyId': companyId,
    });
  }
}

final collaborationRepositoryProvider = Provider<CollaborationRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return CollaborationRepository(firestore);
});
