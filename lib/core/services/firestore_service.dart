import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> col(String farmId, String collection) =>
      _db.collection('farms').doc(farmId).collection(collection);

  Stream<List<T>> stream<T>({
    required String farmId,
    required String collection,
    required T Function(Map<String, dynamic> data, String id) fromFirestore,
    List<List<dynamic>>? where,
    String orderBy = 'createdAt',
    bool descending = true,
  }) {
    Query<Map<String, dynamic>> q = col(farmId, collection);
    if (where != null) {
      for (final w in where) {
        q = q.where(w[0] as String, isEqualTo: w[1]);
      }
    }
    return q.orderBy(orderBy, descending: descending).snapshots().map(
          (s) => s.docs.map((d) => fromFirestore(d.data(), d.id)).toList(),
        );
  }

  Future<String> add({
    required String farmId,
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    final ref = await col(farmId, collection).add(data);
    return ref.id;
  }

  Future<void> set({
    required String farmId,
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
  }) {
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    return col(farmId, collection).doc(docId).set(data);
  }

  Future<void> update({
    required String farmId,
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
  }) {
    data['updatedAt'] = FieldValue.serverTimestamp();
    return col(farmId, collection).doc(docId).update(data);
  }

  Future<void> delete({
    required String farmId,
    required String collection,
    required String docId,
  }) {
    return col(farmId, collection).doc(docId).delete();
  }
}

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});
