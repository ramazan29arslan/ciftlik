import 'package:equatable/equatable.dart';

enum TimelineEventType {
  fuelAdded,
  documentUploaded,
  maintenanceDone,
  vaccinationDone,
  expenseAdded,
  stockMovement,
  animalBorn,
  animalSold,
  noteAdded,
  statusChanged,
  general,
}

class TimelineEvent extends Equatable {
  final String id;
  final String entityId;
  final String entityType;
  final TimelineEventType type;
  final String title;
  final String? description;
  final double? amount;
  final String? photoUrl;
  final DateTime eventDate;
  final String? createdBy;
  final DateTime createdAt;

  const TimelineEvent({
    required this.id,
    required this.entityId,
    required this.entityType,
    required this.type,
    required this.title,
    this.description,
    this.amount,
    this.photoUrl,
    required this.eventDate,
    this.createdBy,
    required this.createdAt,
  });

  String get typeLabel {
    switch (type) {
      case TimelineEventType.fuelAdded:
        return 'Yakıt Alındı';
      case TimelineEventType.documentUploaded:
        return 'Belge Yüklendi';
      case TimelineEventType.maintenanceDone:
        return 'Bakım Yapıldı';
      case TimelineEventType.vaccinationDone:
        return 'Aşı Yapıldı';
      case TimelineEventType.expenseAdded:
        return 'Gider Eklendi';
      case TimelineEventType.stockMovement:
        return 'Stok Hareketi';
      case TimelineEventType.animalBorn:
        return 'Doğum';
      case TimelineEventType.animalSold:
        return 'Satış';
      case TimelineEventType.noteAdded:
        return 'Not Eklendi';
      case TimelineEventType.statusChanged:
        return 'Durum Değişti';
      case TimelineEventType.general:
        return 'Genel';
    }
  }

  @override
  List<Object?> get props => [id, entityId, entityType, type, eventDate];
}
