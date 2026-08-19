import 'package:cloud_firestore/cloud_firestore.dart';

class CustomEmailTemplate {
  final String id;
  final String companyId;
  final String name;
  final String subject;
  final String body;
  final String type; // 'quotation', 'invoice', or 'all'
  final String? headerColor;
  final DateTime? createdAt;

  CustomEmailTemplate({
    required this.id,
    required this.companyId,
    required this.name,
    required this.subject,
    required this.body,
    this.type = 'all',
    this.headerColor = '#f47421',
    this.createdAt,
  });

  factory CustomEmailTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime? created;
    if (data['createdAt'] is Timestamp) {
      created = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is String) {
      created = DateTime.tryParse(data['createdAt']);
    }

    return CustomEmailTemplate(
      id: doc.id,
      companyId: data['companyId'] ?? '',
      name: data['name'] ?? '',
      subject: data['subject'] ?? '',
      body: data['body'] ?? '',
      type: data['type'] ?? 'all',
      headerColor: data['headerColor'] ?? '#f47421',
      createdAt: created,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'name': name,
      'subject': subject,
      'body': body,
      'type': type,
      'headerColor': headerColor,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
