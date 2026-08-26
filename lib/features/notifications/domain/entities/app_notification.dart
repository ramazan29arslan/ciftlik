import 'package:equatable/equatable.dart';

enum NotificationType {
  vaccination,
  insurance,
  maintenance,
  lowStock,
  inspection,
  pregnancy,
  general,
}

enum NotificationPriority { low, medium, high, critical }

class AppNotification extends Equatable {
  final String id;
  final String farmId;
  final String title;
  final String body;
  final NotificationType type;
  final NotificationPriority priority;
  final String? entityId;
  final String? entityType;
  final DateTime scheduledAt;
  final bool isRead;
  final bool isSent;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.farmId,
    required this.title,
    required this.body,
    required this.type,
    required this.priority,
    this.entityId,
    this.entityType,
    required this.scheduledAt,
    this.isRead = false,
    this.isSent = false,
    required this.createdAt,
  });

  String get typeLabel {
    switch (type) {
      case NotificationType.vaccination:
        return 'Aşı';
      case NotificationType.insurance:
        return 'Sigorta';
      case NotificationType.maintenance:
        return 'Bakım';
      case NotificationType.lowStock:
        return 'Düşük Stok';
      case NotificationType.inspection:
        return 'Muayene';
      case NotificationType.pregnancy:
        return 'Gebelik';
      case NotificationType.general:
        return 'Genel';
    }
  }

  @override
  List<Object?> get props => [id, farmId, title, type, scheduledAt];
}
