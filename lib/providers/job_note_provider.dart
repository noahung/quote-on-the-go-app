import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/job_note.dart';
import 'quotation_provider.dart' show firestoreProvider;

part 'job_note_provider.g.dart';

class JobNoteRepository {
  final FirebaseFirestore _firestore;

  JobNoteRepository(this._firestore);

  Stream<List<JobNote>> watchNotes(String jobId) {
    return _firestore
        .collection('jobNotes')
        .where('jobId', isEqualTo: jobId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => JobNote.fromFirestore(doc)).toList());
  }

  Future<void> createNote({
    required String jobId,
    required String companyId,
    required String content,
    required String createdBy,
  }) async {
    await _firestore.collection('jobNotes').add({
      'jobId': jobId,
      'companyId': companyId,
      'content': content,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteNote(String noteId) async {
    await _firestore.collection('jobNotes').doc(noteId).delete();
  }
}

final jobNoteRepositoryProvider = Provider<JobNoteRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return JobNoteRepository(firestore);
});

@riverpod
Stream<List<JobNote>> jobNotesStream(JobNotesStreamRef ref, String jobId) {
  final repo = ref.watch(jobNoteRepositoryProvider);
  return repo.watchNotes(jobId);
}
