import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/feedback_model.dart';

class FeedbackService {
  final _col = FirebaseFirestore.instance.collection('feedback');

  Future<void> sendFeedback({
    required String userId,
    required String userEmail,
    required String userName,
    required FeedbackType type,
    required String message,
  }) async {
    final doc = _col.doc();
    await doc.set(FeedbackModel(
      id: doc.id,
      userId: userId,
      userEmail: userEmail,
      userName: userName,
      type: type,
      message: message,
      createdAt: DateTime.now(),
    ).toJson());
  }

  /// Kullanıcının kendi gönderimlerini dinle
  Stream<List<FeedbackModel>> userFeedbackStream(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FeedbackModel.fromFirestore(d.data(), d.id))
            .toList());
  }

  /// Admin: tüm geri bildirimleri dinle
  Stream<List<FeedbackModel>> allFeedbackStream() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FeedbackModel.fromFirestore(d.data(), d.id))
            .toList());
  }

  /// Admin: yanıt gönder
  Future<void> sendReply(String feedbackId, String reply) async {
    await _col.doc(feedbackId).update({
      'adminReply': reply,
      'status': FeedbackStatus.replied.name,
      'repliedAt': DateTime.now().toIso8601String(),
    });
  }
}
