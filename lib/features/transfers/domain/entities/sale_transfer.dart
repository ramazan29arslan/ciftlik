import 'package:cloud_firestore/cloud_firestore.dart';

enum SaleTransferStatus { pending, accepted, rejected }

class SaleTransfer {
  final String id;
  final String sellerUserId;
  final String sellerFarmId;
  final String sellerDisplayName;
  final String sellerEmail;
  final String buyerEmail;
  final String? buyerUserId;
  final String? buyerFarmId;
  final SaleTransferStatus status;
  final String entityType;   // 'animal'
  final String entityId;
  final String entityName;
  final Map<String, dynamic> entityData;
  final DateTime createdAt;
  final DateTime? respondedAt;

  const SaleTransfer({
    required this.id,
    required this.sellerUserId,
    required this.sellerFarmId,
    required this.sellerDisplayName,
    required this.sellerEmail,
    required this.buyerEmail,
    this.buyerUserId,
    this.buyerFarmId,
    required this.status,
    required this.entityType,
    required this.entityId,
    required this.entityName,
    required this.entityData,
    required this.createdAt,
    this.respondedAt,
  });

  factory SaleTransfer.fromFirestore(Map<String, dynamic> data, String id) {
    return SaleTransfer(
      id: id,
      sellerUserId: data['sellerUserId'] as String? ?? '',
      sellerFarmId: data['sellerFarmId'] as String? ?? '',
      sellerDisplayName: data['sellerDisplayName'] as String? ?? '',
      sellerEmail: data['sellerEmail'] as String? ?? '',
      buyerEmail: data['buyerEmail'] as String? ?? '',
      buyerUserId: data['buyerUserId'] as String?,
      buyerFarmId: data['buyerFarmId'] as String?,
      status: SaleTransferStatus.values.firstWhere(
        (s) => s.name == (data['status'] ?? 'pending'),
        orElse: () => SaleTransferStatus.pending,
      ),
      entityType: data['entityType'] as String? ?? 'animal',
      entityId: data['entityId'] as String? ?? '',
      entityName: data['entityName'] as String? ?? '',
      entityData: Map<String, dynamic>.from(data['entityData'] as Map? ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'sellerUserId': sellerUserId,
      'sellerFarmId': sellerFarmId,
      'sellerDisplayName': sellerDisplayName,
      'sellerEmail': sellerEmail,
      'buyerEmail': buyerEmail,
      'buyerUserId': buyerUserId,
      'buyerFarmId': buyerFarmId,
      'status': status.name,
      'entityType': entityType,
      'entityId': entityId,
      'entityName': entityName,
      'entityData': entityData,
      'createdAt': FieldValue.serverTimestamp(),
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
    };
  }

  String get statusLabel {
    switch (status) {
      case SaleTransferStatus.pending: return 'Bekliyor';
      case SaleTransferStatus.accepted: return 'Kabul Edildi';
      case SaleTransferStatus.rejected: return 'Reddedildi';
    }
  }
}
