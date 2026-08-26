import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../animals/data/models/animal_model.dart';
import '../../domain/entities/sale_transfer.dart';

class SaleTransferService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _collection = 'saleTransfers';

  /// Creates a transfer request when an animal is sold.
  /// Returns the transfer ID, or null if buyerEmail is empty.
  Future<String?> createAnimalTransfer({
    required AnimalModel animal,
    required String sellerUserId,
    required String sellerFarmId,
    required String sellerDisplayName,
    required String sellerEmail,
  }) async {
    final buyerEmail = animal.buyerEmail;
    if (buyerEmail == null || buyerEmail.isEmpty) return null;

    // Check if a pending transfer already exists for this animal
    final existing = await _db
        .collection(_collection)
        .where('entityId', isEqualTo: animal.id)
        .where('status', isEqualTo: 'pending')
        .get();
    if (existing.docs.isNotEmpty) {
      // Already pending — return existing
      return existing.docs.first.id;
    }

    final id = const Uuid().v4();
    final entityData = animal.toJson();
    entityData['id'] = animal.id;
    entityData['farmId'] = sellerFarmId;

    await _db.collection(_collection).doc(id).set({
      'sellerUserId': sellerUserId,
      'sellerFarmId': sellerFarmId,
      'sellerDisplayName': sellerDisplayName,
      'sellerEmail': sellerEmail,
      'buyerEmail': buyerEmail.toLowerCase().trim(),
      'buyerUserId': null,
      'buyerFarmId': null,
      'status': 'pending',
      'entityType': 'animal',
      'entityId': animal.id,
      'entityName': animal.displayName,
      'entityData': entityData,
      'createdAt': FieldValue.serverTimestamp(),
      'respondedAt': null,
    });
    return id;
  }

  /// Stream of transfers sent by the current user (as seller).
  Stream<List<SaleTransfer>> outgoingTransfers(String sellerUserId) {
    return _db
        .collection(_collection)
        .where('sellerUserId', isEqualTo: sellerUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((_) {})
        .map((s) => s.docs
            .map((d) => SaleTransfer.fromFirestore(d.data(), d.id))
            .toList());
  }

  /// Stream of transfers incoming to the current user (as buyer).
  Stream<List<SaleTransfer>> incomingTransfers(String buyerEmail) {
    return _db
        .collection(_collection)
        .where('buyerEmail', isEqualTo: buyerEmail.toLowerCase().trim())
        .orderBy('createdAt', descending: true)
        .snapshots()
        .handleError((_) {})
        .map((s) => s.docs
            .map((d) => SaleTransfer.fromFirestore(d.data(), d.id))
            .toList());
  }

  /// Count of pending incoming transfers for badge display.
  Stream<int> pendingIncomingCount(String buyerEmail) {
    return incomingTransfers(buyerEmail).map((list) =>
        list.where((t) => t.status == SaleTransferStatus.pending).length);
  }

  /// Buyer accepts the transfer: copy entity to buyer's farm.
  Future<void> acceptTransfer({
    required SaleTransfer transfer,
    required String buyerUserId,
    required String buyerFarmId,
  }) async {
    final db = _db;
    final batch = db.batch();

    // 1) Copy animal to buyer's farm
    final animalData = Map<String, dynamic>.from(transfer.entityData);
    animalData['farmId'] = buyerFarmId;
    animalData['status'] = 'active'; // Reset to active in buyer's farm
    animalData['buyerEmail'] = null;
    animalData['saleDate'] = null;
    animalData['createdAt'] = FieldValue.serverTimestamp();
    animalData['updatedAt'] = FieldValue.serverTimestamp();

    final newEntityRef = db
        .collection('farms')
        .doc(buyerFarmId)
        .collection('animals')
        .doc(transfer.entityId);
    batch.set(newEntityRef, animalData);

    // 2) Update transfer status
    final transferRef = db.collection(_collection).doc(transfer.id);
    batch.update(transferRef, {
      'status': 'accepted',
      'buyerUserId': buyerUserId,
      'buyerFarmId': buyerFarmId,
      'respondedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Buyer rejects the transfer.
  Future<void> rejectTransfer(String transferId, String buyerUserId) async {
    await _db.collection(_collection).doc(transferId).update({
      'status': 'rejected',
      'buyerUserId': buyerUserId,
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cancel a transfer (seller cancels pending request).
  Future<void> cancelTransfer(String transferId) async {
    await _db.collection(_collection).doc(transferId).update({
      'status': 'rejected',
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }
}
