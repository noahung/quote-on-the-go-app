import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'auth_provider.dart';

class DocumentTemplateRepository {
  final FirebaseFirestore _firestore;
  DocumentTemplateRepository(this._firestore);

  Stream<List<DocumentTemplate>> streamForCompany(String companyId) {
    return _firestore
        .collection('document_templates')
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map((d) => DocumentTemplate.fromFirestore(d)).toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  Future<void> createTemplate({
    required String companyId,
    required String name,
    String? description,
    required String type, // 'quotation' | 'invoice'
    required List<LineItem> items,
    String? notes,
    double? taxRate,
    String? pdfTemplateId,
    String? pdfThemeColor,
    double? discount,
    String? discountType,
    double? discountAmount,
  }) async {
    await _firestore.collection('document_templates').add({
      'companyId': companyId,
      'name': name,
      'description': description,
      'type': type,
      'items': items.map((i) => i.toJson()).toList(),
      'notes': notes,
      'taxRate': taxRate,
      'pdfTemplateId': pdfTemplateId,
      'pdfThemeColor': pdfThemeColor,
      'discount': discount,
      'discountType': discountType,
      'discountAmount': discountAmount,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTemplate(
    String templateId, {
    required String name,
    String? description,
    required String type,
    required List<LineItem> items,
    String? notes,
    double? taxRate,
    String? pdfTemplateId,
    String? pdfThemeColor,
    double? discount,
    String? discountType,
    double? discountAmount,
  }) async {
    await _firestore.collection('document_templates').doc(templateId).update({
      'name': name,
      'description': description,
      'type': type,
      'items': items.map((i) => i.toJson()).toList(),
      'notes': notes,
      'taxRate': taxRate,
      'pdfTemplateId': pdfTemplateId,
      'pdfThemeColor': pdfThemeColor,
      'discount': discount,
      'discountType': discountType,
      'discountAmount': discountAmount,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteTemplate(String templateId) async {
    await _firestore.collection('document_templates').doc(templateId).delete();
  }
}

final documentTemplateRepositoryProvider =
    Provider<DocumentTemplateRepository>((ref) {
  return DocumentTemplateRepository(FirebaseFirestore.instance);
});

final documentTemplatesStreamProvider =
    StreamProvider<List<DocumentTemplate>>((ref) {
  final companyId = ref.watch(companyIdProvider);
  if (companyId == null) return const Stream.empty();
  return ref
      .read(documentTemplateRepositoryProvider)
      .streamForCompany(companyId);
});

final documentTemplatesProvider = Provider<List<DocumentTemplate>>((ref) {
  return ref.watch(documentTemplatesStreamProvider).valueOrNull ?? [];
});
