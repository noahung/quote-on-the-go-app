import 'auth_provider.dart';
import '../services/api_client.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'quotation_provider.dart'; // to reuse firestoreProvider

class UnifiedActivityItem {
  final String id;
  final String type; // 'comment' | 'timeline'
  final DateTime timestamp;
  final String authorName;
  final String initials;
  final String content;
  final String badgeText;
  final String badgeColor;
  final bool isResolved;
  final bool isPrivate;
  final String? authorPhotoURL;

  UnifiedActivityItem({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.authorName,
    required this.initials,
    required this.content,
    required this.badgeText,
    required this.badgeColor,
    required this.isResolved,
    required this.isPrivate,
    this.authorPhotoURL,
  });
}

class DocumentLockInfo {
  final String? lockedBy;
  final DateTime? lockedAt;

  DocumentLockInfo({this.lockedBy, this.lockedAt});

  bool get isLocked => lockedBy != null;
}

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
  final String? authorPhotoURL;

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
    this.authorPhotoURL,
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
      authorPhotoURL: authorMap['photoURL'] as String? ?? authorMap['photoUrl'] as String?,
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

class ActivityTimelineItem {
  final String id;
  final String documentId;
  final String documentType;
  final String activityType;
  final String description;
  final Map<String, dynamic> actor;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  final String companyId;

  ActivityTimelineItem({
    required this.id,
    required this.documentId,
    required this.documentType,
    required this.activityType,
    required this.description,
    required this.actor,
    required this.timestamp,
    required this.metadata,
    required this.companyId,
  });

  factory ActivityTimelineItem.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedDate;
    final createdVal = map['timestamp'];
    if (createdVal is Timestamp) {
      parsedDate = createdVal.toDate();
    } else if (createdVal is String) {
      parsedDate = DateTime.tryParse(createdVal) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return ActivityTimelineItem(
      id: docId,
      documentId: map['documentId'] as String? ?? '',
      documentType: map['documentType'] as String? ?? '',
      activityType: map['activityType'] as String? ?? 'other',
      description: map['description'] as String? ?? '',
      actor: Map<String, dynamic>.from(map['actor'] ?? {}),
      timestamp: parsedDate,
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      companyId: map['companyId'] as String? ?? '',
    );
  }
}

class ApprovalWorkflowStep {
  final int stepNumber;
  final String approverRole;
  final String? approverUserId;
  String status;
  final bool isRequired;
  final Map<String, dynamic>? approvedBy;
  final DateTime? approvedAt;
  final String? comments;

  ApprovalWorkflowStep({
    required this.stepNumber,
    required this.approverRole,
    this.approverUserId,
    required this.status,
    required this.isRequired,
    this.approvedBy,
    this.approvedAt,
    this.comments,
  });

  factory ApprovalWorkflowStep.fromMap(Map<String, dynamic> map) {
    DateTime? parsedDate;
    final approvedAtVal = map['approvedAt'];
    if (approvedAtVal is Timestamp) {
      parsedDate = approvedAtVal.toDate();
    } else if (approvedAtVal is String) {
      parsedDate = DateTime.tryParse(approvedAtVal);
    }

    return ApprovalWorkflowStep(
      stepNumber: (map['stepNumber'] as num?)?.toInt() ?? 1,
      approverRole: map['approverRole'] as String? ?? '',
      approverUserId: map['approverUserId'] as String?,
      status: map['status'] as String? ?? 'pending',
      isRequired: map['isRequired'] as bool? ?? true,
      approvedBy: map['approvedBy'] != null ? Map<String, dynamic>.from(map['approvedBy'] as Map) : null,
      approvedAt: parsedDate,
      comments: map['comments'] as String?,
    );
  }

  ApprovalWorkflowStep copyWith({
    int? stepNumber,
    String? approverRole,
    String? approverUserId,
    String? status,
    bool? isRequired,
    Map<String, dynamic>? approvedBy,
    DateTime? approvedAt,
    String? comments,
  }) {
    return ApprovalWorkflowStep(
      stepNumber: stepNumber ?? this.stepNumber,
      approverRole: approverRole ?? this.approverRole,
      approverUserId: approverUserId ?? this.approverUserId,
      status: status ?? this.status,
      isRequired: isRequired ?? this.isRequired,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      comments: comments ?? this.comments,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'stepNumber': stepNumber,
      'approverRole': approverRole,
      if (approverUserId != null) 'approverUserId': approverUserId,
      'status': status,
      'isRequired': isRequired,
      if (approvedBy != null) 'approvedBy': approvedBy,
      if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
      if (comments != null) 'comments': comments,
    };
  }
}

class ApprovalWorkflow {
  final String id;
  final String documentId;
  final String documentType;
  final String workflowType;
  final int currentStep;
  final int totalSteps;
  final String status;
  final List<ApprovalWorkflowStep> steps;
  final Map<String, dynamic> initiatedBy;
  final DateTime? initiatedAt;
  final String companyId;

  ApprovalWorkflow({
    required this.id,
    required this.documentId,
    required this.documentType,
    required this.workflowType,
    required this.currentStep,
    required this.totalSteps,
    required this.status,
    required this.steps,
    required this.initiatedBy,
    this.initiatedAt,
    required this.companyId,
  });

  factory ApprovalWorkflow.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? parsedDate;
    final initiatedAtVal = map['initiatedAt'];
    if (initiatedAtVal is Timestamp) {
      parsedDate = initiatedAtVal.toDate();
    } else if (initiatedAtVal is String) {
      parsedDate = DateTime.tryParse(initiatedAtVal);
    }

    final rawSteps = (map['steps'] as List?) ?? [];
    return ApprovalWorkflow(
      id: docId,
      documentId: map['documentId'] as String? ?? '',
      documentType: map['documentType'] as String? ?? '',
      workflowType: map['workflowType'] as String? ?? '',
      currentStep: (map['currentStep'] as num?)?.toInt() ?? 1,
      totalSteps: (map['totalSteps'] as num?)?.toInt() ?? 1,
      status: map['status'] as String? ?? 'pending',
      steps: rawSteps.map((s) => ApprovalWorkflowStep.fromMap(s as Map<String, dynamic>)).toList(),
      initiatedBy: Map<String, dynamic>.from(map['initiatedBy'] ?? {}),
      initiatedAt: parsedDate,
      companyId: map['companyId'] as String? ?? '',
    );
  }
}

class ApprovalStep {
  final int stepNumber;
  final String approverRole;
  final String? approverUserId;
  final bool isRequired;
  final bool allowParallel;

  ApprovalStep({
    required this.stepNumber,
    required this.approverRole,
    this.approverUserId,
    required this.isRequired,
    required this.allowParallel,
  });

  factory ApprovalStep.fromMap(Map<String, dynamic> map) {
    return ApprovalStep(
      stepNumber: (map['stepNumber'] as num?)?.toInt() ?? 1,
      approverRole: map['approverRole'] as String? ?? '',
      approverUserId: map['approverUserId'] as String?,
      isRequired: map['isRequired'] as bool? ?? true,
      allowParallel: map['allowParallel'] as bool? ?? false,
    );
  }
}

class ApprovalRule {
  final String id;
  final String name;
  final String description;
  final bool isActive;
  final String documentType;
  final List<ApprovalStep> approvalSteps;
  final String companyId;

  ApprovalRule({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
    required this.documentType,
    required this.approvalSteps,
    required this.companyId,
  });

  factory ApprovalRule.fromMap(Map<String, dynamic> map, String docId) {
    final rawSteps = (map['approvalSteps'] as List?) ?? [];
    return ApprovalRule(
      id: docId,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
      documentType: map['documentType'] as String? ?? 'both',
      approvalSteps: rawSteps.map((s) => ApprovalStep.fromMap(s as Map<String, dynamic>)).toList(),
      companyId: map['companyId'] as String? ?? '',
    );
  }
}

final collaborationCommentsProvider = StreamProvider.family<List<InternalComment>, ({String documentId, String documentType})>((ref, arg) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('internal_comments')
      .where('companyId', isEqualTo: ref.watch(companyIdProvider) ?? '')
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
      .where('companyId', isEqualTo: ref.watch(companyIdProvider) ?? '')
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

final unifiedActivityStreamProvider = StreamProvider.family<List<UnifiedActivityItem>, ({String documentId, String documentType})>((ref, arg) {
  final controller = StreamController<List<UnifiedActivityItem>>();
  
  List<InternalComment> currentComments = [];
  List<ActivityTimelineItem> currentTimeline = [];

  void emitMerged() {
    final merged = <UnifiedActivityItem>[];
    
    for (final comment in currentComments) {
      final initials = _getInitials(comment.authorName);
      merged.add(UnifiedActivityItem(
        id: comment.id,
        type: 'comment',
        timestamp: comment.createdAt,
        authorName: comment.authorName,
        initials: initials,
        content: comment.content,
        badgeText: comment.isPrivate ? 'Internal' : 'Customer',
        badgeColor: comment.isPrivate ? 'blue' : 'green',
        isResolved: comment.isResolved,
        isPrivate: comment.isPrivate,
        authorPhotoURL: comment.authorPhotoURL,
      ));
    }

    for (final item in currentTimeline) {
      final name = item.actor['userName'] as String? ?? item.actor['displayName'] as String? ?? 'System';
      final initials = _getInitials(name);
      final photoURL = item.actor['photoURL'] as String? ?? item.actor['photoUrl'] as String?;
      merged.add(UnifiedActivityItem(
        id: item.id,
        type: 'timeline',
        timestamp: item.timestamp,
        authorName: name,
        initials: initials,
        content: item.description,
        badgeText: 'System',
        badgeColor: 'grey',
        isResolved: false,
        isPrivate: false,
        authorPhotoURL: photoURL,
      ));
    }

    merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (!controller.isClosed) {
      controller.add(merged);
    }
  }

  ref.listen<AsyncValue<List<InternalComment>>>(collaborationCommentsProvider(arg), (previous, next) {
    currentComments = next.valueOrNull ?? [];
    emitMerged();
  }, fireImmediately: true);

  ref.listen<AsyncValue<List<ActivityTimelineItem>>>(documentTimelineProvider(arg), (previous, next) {
    currentTimeline = next.valueOrNull ?? [];
    emitMerged();
  }, fireImmediately: true);

  ref.onDispose(() {
    controller.close();
  });

  return controller.stream;
});

String _getInitials(String name) {
  if (name.isEmpty) return '?';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length > 1) {
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.last.isNotEmpty ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }
  return name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
}

final documentLockProvider = StreamProvider.family<DocumentLockInfo, ({String documentId, String documentType})>((ref, arg) {
  final firestore = ref.watch(firestoreProvider);
  
  final lockDocStream = firestore.collection('document_locks').doc(arg.documentId).snapshots();
  final docCollection = arg.documentType == 'quotation' ? 'quotations' : 'invoices';
  final docStream = firestore.collection(docCollection).doc(arg.documentId).snapshots();

  final controller = StreamController<DocumentLockInfo>();
  
  String? lockDocLockedBy;
  DateTime? lockDocLockedAt;
  
  String? mainDocLockedBy;
  DateTime? mainDocLockedAt;

  void emitLock() {
    if (lockDocLockedBy != null) {
      if (!controller.isClosed) {
        controller.add(DocumentLockInfo(lockedBy: lockDocLockedBy, lockedAt: lockDocLockedAt));
      }
    } else if (mainDocLockedBy != null) {
      if (!controller.isClosed) {
        controller.add(DocumentLockInfo(lockedBy: mainDocLockedBy, lockedAt: mainDocLockedAt));
      }
    } else {
      if (!controller.isClosed) {
        controller.add(DocumentLockInfo(lockedBy: null, lockedAt: null));
      }
    }
  }

  final sub1 = lockDocStream.listen((snapshot) {
    if (snapshot.exists) {
      final data = snapshot.data();
      lockDocLockedBy = data?['lockedBy'] as String?;
      final t = data?['lockedAt'];
      if (t is Timestamp) {
        lockDocLockedAt = t.toDate();
      } else if (t is String) {
        lockDocLockedAt = DateTime.tryParse(t);
      } else {
        lockDocLockedAt = null;
      }
    } else {
      lockDocLockedBy = null;
      lockDocLockedAt = null;
    }
    emitLock();
  }, onError: (err) {
    debugPrint('Error in lockDocStream: $err');
  });

  final sub2 = docStream.listen((snapshot) {
    if (snapshot.exists) {
      final data = snapshot.data();
      mainDocLockedBy = data?['lockedBy'] as String?;
      final t = data?['lockedAt'];
      if (t is Timestamp) {
        mainDocLockedAt = t.toDate();
      } else if (t is String) {
        mainDocLockedAt = DateTime.tryParse(t);
      } else {
        mainDocLockedAt = null;
      }
    } else {
      mainDocLockedBy = null;
      mainDocLockedAt = null;
    }
    emitLock();
  }, onError: (err) {
    debugPrint('Error in docStream: $err');
  });

  ref.onDispose(() {
    sub1.cancel();
    sub2.cancel();
    controller.close();
  });

  return controller.stream;
});

class CollaborationRepository {
  final FirebaseFirestore _firestore;

  final String companyId;

  CollaborationRepository(this._firestore, this.companyId);

  Future<void> lockDocument({
    required String documentId,
    required String documentType,
    required String userId,
  }) async {
    final collection = documentType == 'quotation' ? 'quotations' : 'invoices';
    await _firestore.collection(collection).doc(documentId).update({
      'lockedBy': userId,
      'lockedAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('document_locks').doc(documentId).set({
      'documentId': documentId,
      'documentType': documentType,
      'lockedBy': userId,
      'companyId': companyId,
      'lockedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unlockDocument({
    required String documentId,
    required String documentType,
  }) async {
    final collection = documentType == 'quotation' ? 'quotations' : 'invoices';
    await _firestore.collection(collection).doc(documentId).update({
      'lockedBy': null,
      'lockedAt': null,
    });

    await _firestore.collection('document_locks').doc(documentId).delete();
  }

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
        .where('companyId', isEqualTo: companyId)
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

    await _logActivity(
      documentId: documentId,
      documentType: documentType,
      activityType: 'version_created',
      description: 'Version $nextVersionNumber created',
      actor: {'userId': userId, 'userName': userName, 'userEmail': userEmail},
      metadata: {'versionId': versionRef.id},
      companyId: companyId,
    );
  }

  Future<void> resolveComment({
    required String commentId,
    required String userId,
    required String userName,
    required String userEmail,
  }) async {
    await _firestore.collection('internal_comments').doc(commentId).update({
      'isResolved': true,
      'resolvedBy': {
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
      },
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> restoreDocumentVersion({
    required String documentId,
    required String documentType,
    required String versionId,
    required String userId,
    required String userName,
    required String userEmail,
    required String companyId,
  }) async {
    final versionDoc = await _firestore.collection('document_versions').doc(versionId).get();
    if (!versionDoc.exists) throw Exception('Version not found');
    final versionData = versionDoc.data()!;

    if (versionData['documentId'] != documentId || versionData['documentType'] != documentType) {
      throw Exception('Version mismatch');
    }

    final docRef = _firestore.collection(documentType == 'quotation' ? 'quotations' : 'invoices').doc(documentId);
    await docRef.update({
      ...Map<String, dynamic>.from(versionData['snapshot'] as Map),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await createVersion(
      documentId: documentId,
      documentType: documentType,
      title: 'Restored Revision',
      changes: [
        {
          'field': 'restored',
          'oldValue': 'current',
          'newValue': 'version ${versionData['versionNumber']}',
          'changeType': 'modified',
          'description': 'Restored to version ${versionData['versionNumber']}',
        }
      ],
      snapshot: Map<String, dynamic>.from(versionData['snapshot'] as Map),
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      companyId: companyId,
    );
  }

  Future<String> initiateApprovalWorkflow({
    required String documentId,
    required String documentType,
    required String workflowType,
    required String userId,
    required String userName,
    required String userEmail,
    required String companyId,
  }) async {
    final result = await ApiClient.post('/api/mobile/operations', {
      'operation': 'approval.start', 'documentId': documentId, 'documentType': documentType,
    });
    return result['workflowId'] as String;
  }

  Future<void> processApprovalDecision({
    required String workflowId,
    required int stepNumber,
    required String decision,
    required String comments,
    required String userId,
    required String userName,
    required String userEmail,
  }) async {
    await ApiClient.post('/api/mobile/operations', {
      'operation': 'approval.decide', 'workflowId': workflowId, 'stepNumber': stepNumber,
      'decision': decision, 'comments': comments,
    });
  }

  Future<ApprovalWorkflow?> getActiveApprovalWorkflow({
    required String documentId,
    required String documentType,
  }) async {
    final snapshot = await _firestore
        .collection('approval_workflows')
        .where('companyId', isEqualTo: companyId)
        .where('documentId', isEqualTo: documentId)
        .where('documentType', isEqualTo: documentType)
        .orderBy('initiatedAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return ApprovalWorkflow.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
  }

  Stream<ApprovalWorkflow?> watchActiveApprovalWorkflow({
    required String documentId,
    required String documentType,
  }) {
    return _firestore
        .collection('approval_workflows')
        .where('companyId', isEqualTo: companyId)
        .where('documentId', isEqualTo: documentId)
        .where('documentType', isEqualTo: documentType)
        .orderBy('initiatedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return ApprovalWorkflow.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
    });
  }

  Stream<List<ActivityTimelineItem>> watchDocumentTimeline({
    required String documentId,
    required String documentType,
  }) {
    return _firestore
        .collection('activity_timeline')
        .where('companyId', isEqualTo: companyId)
        .where('documentId', isEqualTo: documentId)
        .where('documentType', isEqualTo: documentType)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ActivityTimelineItem.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> _logActivity({
    required String documentId,
    required String documentType,
    required String activityType,
    required String description,
    required Map<String, dynamic> actor,
    required Map<String, dynamic> metadata,
    required String companyId,
  }) async {
    try {
      final ref = _firestore.collection('activity_timeline').doc();
      await ref.set({
        'id': ref.id,
        'documentId': documentId,
        'documentType': documentType,
        'activityType': activityType,
        'description': description,
        'actor': actor,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': metadata,
        'companyId': companyId,
      });
    } catch (e) {
      debugPrint('Error logging activity: $e');
    }
  }

}

final documentTimelineProvider = StreamProvider.family<List<ActivityTimelineItem>, ({String documentId, String documentType})>((ref, arg) {
  final repo = ref.watch(collaborationRepositoryProvider);
  return repo.watchDocumentTimeline(documentId: arg.documentId, documentType: arg.documentType);
});

final activeApprovalWorkflowProvider = StreamProvider.family<ApprovalWorkflow?, ({String documentId, String documentType})>((ref, arg) {
  final repo = ref.watch(collaborationRepositoryProvider);
  return repo.watchActiveApprovalWorkflow(documentId: arg.documentId, documentType: arg.documentType);
});

final collaborationRepositoryProvider = Provider<CollaborationRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return CollaborationRepository(firestore, ref.watch(companyIdProvider) ?? '');
});
