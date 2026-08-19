import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/custom_email_template.dart';

class CustomEmailTemplateRepository {
  final FirebaseFirestore _firestore;

  CustomEmailTemplateRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<CustomEmailTemplate>> getTemplates(String companyId, {String? docType}) async {
    if (companyId.isEmpty) return [];

    try {
      final snap = await _firestore
          .collection('custom_email_templates')
          .where('companyId', isEqualTo: companyId)
          .get();

      final templates = snap.docs.map((doc) => CustomEmailTemplate.fromFirestore(doc)).toList();

      if (docType != null && docType.isNotEmpty) {
        return templates.where((t) => t.type == 'all' || t.type == docType).toList();
      }
      return templates;
    } catch (e) {
      debugPrint('Error fetching custom email templates: $e');
      return [];
    }
  }

  Future<String?> createTemplate(CustomEmailTemplate template) async {
    try {
      final ref = await _firestore.collection('custom_email_templates').add(template.toFirestore());
      return ref.id;
    } catch (e) {
      debugPrint('Error creating custom email template: $e');
      return null;
    }
  }

  Future<bool> deleteTemplate(String templateId) async {
    try {
      await _firestore.collection('custom_email_templates').doc(templateId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting custom email template: $e');
      return false;
    }
  }
}
