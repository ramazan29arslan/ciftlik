import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/activity_log_model.dart';

const _uuid = Uuid();

class ActivityLogService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String farmId;
  final String userId;
  final String userName;

  ActivityLogService({
    required this.farmId,
    required this.userId,
    required this.userName,
  });

  Future<void> log({
    required LogAction action,
    required String entityType,
    required String entityId,
    required String entityName,
    String? details,
  }) async {
    if (farmId.isEmpty || userId.isEmpty) return;
    try {
      final logModel = ActivityLogModel(
        id: _uuid.v4(),
        farmId: farmId,
        userId: userId,
        userName: userName,
        action: action,
        entityType: entityType,
        entityId: entityId,
        entityName: entityName,
        details: details,
        timestamp: DateTime.now(),
      );
      await _db
          .collection('farms')
          .doc(farmId)
          .collection('activityLogs')
          .doc(logModel.id)
          .set(logModel.toJson());
    } catch (_) {
      // Log failure should not break the app
    }
  }

  Stream<List<ActivityLogModel>> logsForEntity(String entityId) {
    return _db
        .collection('farms')
        .doc(farmId)
        .collection('activityLogs')
        .where('entityId', isEqualTo: entityId)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ActivityLogModel.fromFirestore(d.data(), d.id))
            .toList());
  }

  Stream<List<ActivityLogModel>> logsForFarm() {
    return _db
        .collection('farms')
        .doc(farmId)
        .collection('activityLogs')
        .orderBy('timestamp', descending: true)
        .limit(200)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ActivityLogModel.fromFirestore(d.data(), d.id))
            .toList());
  }

  Stream<List<ActivityLogModel>> logsForFarmFiltered(String entityType) {
    return _db
        .collection('farms')
        .doc(farmId)
        .collection('activityLogs')
        .where('entityType', isEqualTo: entityType)
        .orderBy('timestamp', descending: true)
        .limit(200)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ActivityLogModel.fromFirestore(d.data(), d.id))
            .toList());
  }
}
