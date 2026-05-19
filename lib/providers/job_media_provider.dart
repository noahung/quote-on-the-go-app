import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/job_media.dart';
import 'quotation_provider.dart' show firestoreProvider;

part 'job_media_provider.g.dart';

class JobMediaRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  JobMediaRepository(this._firestore, this._storage);

  Stream<List<JobMedia>> watchMedia(String jobId) {
    return _firestore
        .collection('jobMedia')
        .where('jobId', isEqualTo: jobId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => JobMedia.fromFirestore(doc)).toList());
  }

  Future<JobMedia> uploadMedia({
    required String jobId,
    required String companyId,
    required String createdBy,
    required File file,
    required String filename,
    required String mimeType,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uniqueFilename = '${timestamp}_$filename';
    final storagePath =
        'companies/$companyId/jobs/$jobId/media/$uniqueFilename';

    String type = 'document';
    if (mimeType.startsWith('image/')) {
      type = 'image';
    } else if (mimeType.startsWith('video/')) {
      type = 'video';
    }

    final ref = _storage.ref().child(storagePath);
    final uploadTask = await ref.putFile(
      file,
      SettableMetadata(contentType: mimeType),
    );
    final url = await uploadTask.ref.getDownloadURL();

    final docRef = await _firestore.collection('jobMedia').add({
      'jobId': jobId,
      'companyId': companyId,
      'url': url,
      'type': type,
      'filename': uniqueFilename,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return JobMedia(
      id: docRef.id,
      jobId: jobId,
      companyId: companyId,
      url: url,
      type: type,
      filename: uniqueFilename,
      createdBy: createdBy,
    );
  }

  Future<void> deleteMedia(String mediaId) async {
    final doc = await _firestore.collection('jobMedia').doc(mediaId).get();
    final data = doc.data();
    if (data != null && data['url'] != null) {
      try {
        final storageRef = _storage.refFromURL(data['url'] as String);
        await storageRef.delete();
      } catch (_) {}
    }
    await _firestore.collection('jobMedia').doc(mediaId).delete();
  }
}

final jobMediaRepositoryProvider = Provider<JobMediaRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return JobMediaRepository(firestore, FirebaseStorage.instance);
});

@riverpod
Stream<List<JobMedia>> jobMediaStream(JobMediaStreamRef ref, String jobId) {
  final repo = ref.watch(jobMediaRepositoryProvider);
  return repo.watchMedia(jobId);
}
