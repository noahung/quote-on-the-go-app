import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/calendar_event.dart';
import 'auth_provider.dart';
import 'quotation_provider.dart';

part 'schedule_provider.g.dart';

@riverpod
Stream<List<CalendarEvent>> scheduleStream(ScheduleStreamRef ref) {
  final companyId = ref.watch(companyIdProvider);
  final firestore = ref.watch(firestoreProvider);
  if (companyId == null) return const Stream.empty();

  return firestore
      .collection('events')
      .where('companyId', isEqualTo: companyId)
      .snapshots()
      .map((snapshot) {
    final list =
        snapshot.docs.map((doc) => CalendarEvent.fromFirestore(doc)).toList();
    list.sort((a, b) => a.start.compareTo(b.start));
    return list;
  });
}

class ScheduleRepository {
  final FirebaseFirestore _firestore;

  ScheduleRepository(this._firestore);

  Future<String> createEvent(CalendarEvent event, {String? quotationId}) async {
    final data = {
      ...event.toJson()..remove('id'),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final startDt = DateTime.tryParse(event.start);
    if (startDt != null) data['start'] = Timestamp.fromDate(startDt);
    final endDt = DateTime.tryParse(event.end);
    if (endDt != null) data['end'] = Timestamp.fromDate(endDt);
    // Ensure job fields are persisted if present
    if (event.customerId != null) data['customerId'] = event.customerId;
    if (event.customerName != null) data['customerName'] = event.customerName;
    if (event.customerAddress != null) {
      data['customerAddress'] = event.customerAddress;
    }
    if (event.status != null) data['status'] = event.status;
    final doc = _firestore.collection('events').doc();
    await _firestore.runTransaction((transaction) async {
      if (quotationId != null) {
        final quotation = _firestore.collection('quotations').doc(quotationId);
        final existing = await transaction.get(quotation);
        if (!existing.exists || existing.data()?['companyId'] != event.companyId) {
          throw StateError('Quotation is unavailable.');
        }
        if (existing.data()?['jobId'] != null && existing.data()?['jobId'] != '') {
          throw StateError('This quotation already has a job. Open the linked job instead.');
        }
        transaction.update(quotation, {'jobId': doc.id, 'updatedAt': FieldValue.serverTimestamp()});
      }
      transaction.set(doc, data);
    });
    return doc.id;
  }

  Future<void> updateEvent(CalendarEvent event) async {
    final data = {
      ...event.toJson()..remove('id'),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final startDt = DateTime.tryParse(event.start);
    if (startDt != null) data['start'] = Timestamp.fromDate(startDt);
    final endDt = DateTime.tryParse(event.end);
    if (endDt != null) data['end'] = Timestamp.fromDate(endDt);
    if (event.customerId != null) data['customerId'] = event.customerId;
    if (event.customerName != null) data['customerName'] = event.customerName;
    if (event.customerAddress != null) {
      data['customerAddress'] = event.customerAddress;
    }
    if (event.status != null) data['status'] = event.status;
    await _firestore.collection('events').doc(event.id).update(data);
  }

  Future<void> deleteEvent(String eventId) async {
    await _firestore.collection('events').doc(eventId).delete();
  }

  Stream<List<CalendarEvent>> watchJobsByCustomer(
      String companyId, String customerId) {
    return _firestore
        .collection('events')
        .where('companyId', isEqualTo: companyId)
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => CalendarEvent.fromFirestore(doc)).toList());
  }
}

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return ScheduleRepository(firestore);
});
