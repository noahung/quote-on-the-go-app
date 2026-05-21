import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/service.dart';
import 'auth_provider.dart';
import 'quotation_provider.dart';

part 'service_provider.g.dart';

@riverpod
Stream<List<Service>> servicesStream(ServicesStreamRef ref) {
  final companyId = ref.watch(companyIdProvider);
  final firestore = ref.watch(firestoreProvider);
  if (companyId == null) return const Stream.empty();

  return firestore
      .collection('services')
      .where('companyId', isEqualTo: companyId)
      .snapshots()
      .map((snapshot) {
    final list =
        snapshot.docs.map((doc) => Service.fromFirestore(doc)).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  });
}

class ServiceRepository {
  final FirebaseFirestore _firestore;

  ServiceRepository(this._firestore);

  Future<void> createService(Service service) async {
    await _firestore.collection('services').add({
      ...service.toJson()..remove('id'),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateService(Service service) async {
    await _firestore.collection('services').doc(service.id).update({
      ...service.toJson()..remove('id'),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteService(String serviceId) async {
    await _firestore.collection('services').doc(serviceId).delete();
  }
}

final serviceRepositoryProvider = Provider<ServiceRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return ServiceRepository(firestore);
});
