import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
    final rulesQuery = await _firestore
        .collection('approval_rules')
        .where('companyId', isEqualTo: companyId)
        .where('isActive', isEqualTo: true)
        .where('documentType', whereIn: [documentType, 'both'])
        .get();

    final rules = rulesQuery.docs.map((doc) => ApprovalRule.fromMap(doc.data(), doc.id)).toList();
    var rule = _findApplicableRule(rules, documentId, documentType);

    rule ??= ApprovalRule(
        id: 'default_fallback_rule',
        name: 'Default Team Review',
        description: 'Requires approval from any Admin or Owner',
        isActive: true,
        documentType: 'both',
        approvalSteps: [
          ApprovalStep(stepNumber: 1, approverRole: 'admin', isRequired: true, allowParallel: false),
        ],
        companyId: companyId,
      );

    final workflowRef = _firestore.collection('approval_workflows').doc();
    final steps = rule.approvalSteps.asMap().entries.map((entry) {
      final template = entry.value;
      return ApprovalWorkflowStep(
        stepNumber: entry.key + 1,
        approverRole: template.approverRole,
        approverUserId: template.approverUserId,
        status: 'pending',
        isRequired: template.isRequired,
      );
    }).toList();

    await workflowRef.set({
      'id': workflowRef.id,
      'documentId': documentId,
      'documentType': documentType,
      'workflowType': workflowType,
      'currentStep': 1,
      'totalSteps': rule.approvalSteps.length,
      'status': 'pending',
      'steps': steps.map((s) => s.toMap()).toList(),
      'initiatedBy': {
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
      },
      'initiatedAt': FieldValue.serverTimestamp(),
      'companyId': companyId,
    });

    await _logActivity(
      documentId: documentId,
      documentType: documentType,
      activityType: 'created',
      description: 'Approval workflow initiated',
      actor: {'userId': userId, 'userName': userName, 'userEmail': userEmail},
      metadata: {},
      companyId: companyId,
    );

    return workflowRef.id;
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
    final workflowDoc = await _firestore.collection('approval_workflows').doc(workflowId).get();
    if (!workflowDoc.exists) throw Exception('Workflow not found');
    final workflowData = workflowDoc.data()!;

    final rawSteps = (workflowData['steps'] as List?) ?? [];
    final steps = rawSteps.map((s) => ApprovalWorkflowStep.fromMap(s as Map<String, dynamic>)).toList();
    final stepIndex = steps.indexWhere((s) => s.stepNumber == stepNumber);
    if (stepIndex == -1) throw Exception('Approval step not found');

    steps[stepIndex] = steps[stepIndex].copyWith(
      status: decision,
      approvedBy: {'userId': userId, 'userName': userName, 'userEmail': userEmail},
      approvedAt: DateTime.now(),
      comments: comments,
    );

    String newStatus = 'pending';
    if (decision == 'rejected') {
      newStatus = 'rejected';
    } else {
      final requiredSteps = steps.where((s) => s.isRequired).toList();
      if (requiredSteps.every((s) => s.status == 'approved')) {
        newStatus = 'approved';
      }
    }

    int currentStep = stepNumber;
    if (decision == 'approved' && newStatus == 'pending') {
      final nextStep = steps.firstWhereOrNull((s) => s.stepNumber == stepNumber + 1);
      if (nextStep != null) {
        steps[steps.indexOf(nextStep)] = nextStep.copyWith(status: 'pending');
        currentStep = stepNumber + 1;
      }
    }

    final updateData = {
      'steps': steps.map((s) => s.toMap()).toList(),
      'currentStep': currentStep,
      'status': newStatus,
    };

    if (newStatus != 'pending') {
      updateData['completedAt'] = FieldValue.serverTimestamp();
    }

    await _firestore.collection('approval_workflows').doc(workflowId).update(updateData);

    await _logActivity(
      documentId: workflowData['documentId'] as String,
      documentType: workflowData['documentType'] as String,
      activityType: newStatus == 'approved' ? 'approved' : (decision == 'rejected' ? 'status_changed' : 'approved'),
      description: newStatus == 'approved'
          ? 'Approval workflow completed and approved'
          : (newStatus == 'rejected' ? 'Approval workflow rejected' : 'Approved step $stepNumber in approval workflow'),
      actor: {'userId': userId, 'userName': userName, 'userEmail': userEmail},
      metadata: {},
      companyId: workflowData['companyId'] as String,
    );
  }

  Future<ApprovalWorkflow?> getActiveApprovalWorkflow({
    required String documentId,
    required String documentType,
  }) async {
    final snapshot = await _firestore
        .collection('approval_workflows')
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

  ApprovalRule? _findApplicableRule(List<ApprovalRule> rules, String documentId, String documentType) {
    return rules.firstWhereOrNull((rule) => rule.documentType == documentType || rule.documentType == 'both');
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
  return CollaborationRepository(firestore);
});

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
