import 'package:cloud_firestore/cloud_firestore.dart';

enum FeedbackType { complaint, suggestion, question }

enum FeedbackStatus { pending, replied }

class FeedbackModel {
  final String id;
  final String userId;
  final String userEmail;
  final String userName;
  final FeedbackType type;
  final String message;
  final FeedbackStatus status;
  final String? adminReply;
  final DateTime? repliedAt;
  final DateTime createdAt;

  const FeedbackModel({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.type,
    required this.message,
    this.status = FeedbackStatus.pending,
    this.adminReply,
    this.repliedAt,
    required this.createdAt,
  });

  String get typeLabel {
    switch (type) {
      case FeedbackType.complaint: return 'Şikayet';
      case FeedbackType.suggestion: return 'Öneri';
      case FeedbackType.question: return 'Soru';
    }
  }

  String get statusLabel {
    switch (status) {
      case FeedbackStatus.pending: return 'Beklemede';
      case FeedbackStatus.replied: return 'Yanıtlandı';
    }
  }

  factory FeedbackModel.fromFirestore(Map<String, dynamic> data, String id) {
    DateTime _parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.parse(v);
      return DateTime.now();
    }
    return FeedbackModel(
      id: id,
      userId: data['userId'] as String? ?? '',
      userEmail: data['userEmail'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      type: FeedbackType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'suggestion'),
        orElse: () => FeedbackType.suggestion,
      ),
      message: data['message'] as String? ?? '',
      status: FeedbackStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'pending'),
        orElse: () => FeedbackStatus.pending,
      ),
      adminReply: data['adminReply'] as String?,
      repliedAt: data['repliedAt'] != null ? _parseDate(data['repliedAt']) : null,
      createdAt: _parseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'userEmail': userEmail,
    'userName': userName,
    'type': type.name,
    'message': message,
    'status': status.name,
    'adminReply': adminReply,
    'repliedAt': repliedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };
}
