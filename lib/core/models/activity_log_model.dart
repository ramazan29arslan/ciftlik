import 'package:cloud_firestore/cloud_firestore.dart';

enum LogAction { eklendi, guncellendi, silindi }

extension LogActionLabel on LogAction {
  String get label {
    switch (this) {
      case LogAction.eklendi: return 'Eklendi';
      case LogAction.guncellendi: return 'Güncellendi';
      case LogAction.silindi: return 'Silindi';
    }
  }
}

class ActivityLogModel {
  final String id;
  final String farmId;
  final String userId;
  final String userName;
  final LogAction action;
  final String entityType;
  final String entityId;
  final String entityName;
  final String? details;
  final DateTime timestamp;

  ActivityLogModel({
    required this.id,
    required this.farmId,
    required this.userId,
    required this.userName,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.entityName,
    this.details,
    required this.timestamp,
  });

  factory ActivityLogModel.fromFirestore(Map<String, dynamic> data, String id) {
    return ActivityLogModel(
      id: id,
      farmId: data['farmId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Bilinmeyen',
      action: LogAction.values.firstWhere(
        (a) => a.name == data['action'],
        orElse: () => LogAction.eklendi,
      ),
      entityType: data['entityType'] ?? '',
      entityId: data['entityId'] ?? '',
      entityName: data['entityName'] ?? '',
      details: data['details'],
      timestamp: data['timestamp'] is Timestamp
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'farmId': farmId,
    'userId': userId,
    'userName': userName,
    'action': action.name,
    'entityType': entityType,
    'entityId': entityId,
    'entityName': entityName,
    if (details != null) 'details': details,
    'timestamp': Timestamp.fromDate(timestamp),
  };
}
