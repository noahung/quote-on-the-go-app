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

  Future<void> createEvent(CalendarEvent event) async {
    await _firestore.collection('events').add({
      ...event.toJson()..remove('id'),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateEvent(CalendarEvent event) async {
    await _firestore.collection('events').doc(event.id).update({
      ...event.toJson()..remove('id'),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteEvent(String eventId) async {
    await _firestore.collection('events').doc(eventId).delete();
  }
}

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return ScheduleRepository(firestore);
});
