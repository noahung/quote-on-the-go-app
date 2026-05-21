import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  Future<String> createEvent(CalendarEvent event) async {
    final data = {
      ...event.toJson()..remove('id'),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    // Ensure job fields are persisted if present
    if (event.customerId != null) data['customerId'] = event.customerId;
    if (event.customerName != null) data['customerName'] = event.customerName;
    if (event.customerAddress != null) {
      data['customerAddress'] = event.customerAddress;
    }
    if (event.status != null) data['status'] = event.status;
    final doc = await _firestore.collection('events').add(data);
    return doc.id;
  }

  Future<void> updateEvent(CalendarEvent event) async {
    final data = {
      ...event.toJson()..remove('id'),
      'updatedAt': FieldValue.serverTimestamp(),
    };
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
