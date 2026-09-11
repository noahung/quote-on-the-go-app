import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qotg_mobile/models/models.dart';
import 'package:qotg_mobile/providers/providers.dart';
import 'package:qotg_mobile/providers/collaboration_provider.dart';

class RecordingFirestore implements FirebaseFirestore {
  final writes = <Map<String, dynamic>>[];
  int reads = 0;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      RecordingCollection(this, path);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RecordingCollection implements CollectionReference<Map<String, dynamic>> {
  RecordingCollection(this.db, this.path);
  final RecordingFirestore db;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      RecordingDocument(db);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RecordingDocument implements DocumentReference<Map<String, dynamic>> {
  RecordingDocument(this.db);
  final RecordingFirestore db;
  @override
  Future<void> update(Map<Object, Object?> data) async =>
      db.writes.add(Map<String, dynamic>.from(data));
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get(
      [GetOptions? options]) async {
    db.reads++;
    return CompanySnapshot();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class CompanySnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  Map<String, dynamic> data() => {'companyId': 'company'};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RecordingApprovals implements CollaborationRepository {
  int calls = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #initiateApprovalWorkflow) {
      calls++;
      return Future<String>.value('workflow');
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  for (final type in ['invoice', 'quotation']) {
    for (final substantive in [false, true]) {
      test(
          '$type member ${substantive ? 'content changes still request approval' : 'star/archive changes preserve approval'}',
          () async {
        final db = RecordingFirestore();
        final approvals = RecordingApprovals();
        final container = ProviderContainer(overrides: [
          firestoreProvider.overrideWithValue(db),
          collaborationRepositoryProvider.overrideWithValue(approvals),
          userProfileProvider.overrideWith((ref) => UserProfile(
              uid: 'member',
              companyId: 'company',
              role: 'member',
              createdAt: DateTime(2026))),
        ]);
        addTearDown(container.dispose);
        final changes = <String, dynamic>{
          'isStarred': true,
          'isArchived': true,
          if (substantive) 'title': 'Revised scope'
        };
        if (type == 'invoice') {
          await container
              .read(invoiceRepositoryProvider)
              .updateInvoice('doc', changes);
        } else {
          await container
              .read(quotationRepositoryProvider)
              .updateQuotation('doc', changes);
        }
        final saved = db.writes.single;
        expect(saved['isStarred'], true);
        expect(saved['isArchived'], true);
        expect(saved['updatedAt'], isA<FieldValue>());
        expect(saved['approvalStatus'], substantive ? 'pending' : isNull);
        expect(saved['requiresApproval'], substantive ? true : isNull);
        expect(db.reads, substantive ? 1 : 0);
        expect(approvals.calls, substantive ? 1 : 0);
      });
    }
  }
}
