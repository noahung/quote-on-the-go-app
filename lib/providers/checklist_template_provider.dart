import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/checklist_template.dart';
import 'auth_provider.dart';

class ChecklistTemplateRepository {
  final FirebaseFirestore _firestore;
  ChecklistTemplateRepository(this._firestore);

  Stream<List<ChecklistTemplate>> streamForCompany(String companyId) {
    return _firestore
        .collection('checklist_templates')
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map((d) => ChecklistTemplate.fromFirestore(d)).toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  Future<void> createTemplate({
    required String companyId,
    required String name,
    required List<String> items,
  }) async {
    await _firestore.collection('checklist_templates').add({
      'companyId': companyId,
      'name': name,
      'items': items,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteTemplate(String templateId) async {
    await _firestore.collection('checklist_templates').doc(templateId).delete();
  }

  Future<void> updateTemplate(String templateId, String name, List<String> items) async {
    await _firestore.collection('checklist_templates').doc(templateId).update({
      'name': name,
      'items': items,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

final checklistTemplateRepositoryProvider =
    Provider<ChecklistTemplateRepository>((ref) {
  return ChecklistTemplateRepository(FirebaseFirestore.instance);
});

final checklistTemplatesProvider =
    StreamProvider<List<ChecklistTemplate>>((ref) {
  final companyId = ref.watch(companyIdProvider);
  if (companyId == null) return const Stream.empty();
  return ref
      .read(checklistTemplateRepositoryProvider)
      .streamForCompany(companyId);
});
