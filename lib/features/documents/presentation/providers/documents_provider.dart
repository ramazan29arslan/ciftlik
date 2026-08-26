import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/models/document_model.dart';
import '../../../../core/services/firestore_service.dart' show FirestoreService, firestoreServiceProvider;
import '../../../farms/presentation/providers/farm_provider.dart';

const _uuid = Uuid();

class DocumentsNotifier extends StateNotifier<List<EntityDocument>> {
  final FirestoreService _firestore;
  final String _farmId;
  StreamSubscription<List<EntityDocument>>? _sub;

  DocumentsNotifier(this._firestore, this._farmId) : super([]) {
    if (_farmId.isEmpty) return;
    _sub = _firestore
        .stream<EntityDocument>(
          farmId: _farmId,
          collection: 'documents',
          fromFirestore: EntityDocument.fromFirestore,
          orderBy: 'createdAt',
          descending: true,
        )
        .listen((list) => state = list);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> add(EntityDocument doc) async {
    state = [...state, doc];
    try {
      await _firestore.set(
        farmId: _farmId,
        collection: 'documents',
        docId: doc.id,
        data: doc.toJson(),
      );
    } catch (e) {
      state = state.where((d) => d.id != doc.id).toList();
      rethrow;
    }
  }

  Future<void> update(EntityDocument doc) async {
    state = state.map((d) => d.id == doc.id ? doc : d).toList();
    try {
      await _firestore.update(
        farmId: _farmId,
        collection: 'documents',
        docId: doc.id,
        data: doc.toJson(),
      );
    } catch (_) {
      rethrow;
    }
  }

  Future<void> delete(String id) => _firestore.delete(
    farmId: _farmId,
    collection: 'documents',
    docId: id,
  );

  List<EntityDocument> forEntity(String entityId) =>
      state.where((d) => d.entityId == entityId).toList();
}

final documentsNotifierProvider =
    StateNotifierProvider<DocumentsNotifier, List<EntityDocument>>((ref) {
  final farmId = ref.watch(activeFarmIdProvider) ?? '';
  final firestore = ref.watch(firestoreServiceProvider);
  return DocumentsNotifier(firestore, farmId);
});

final entityDocumentsProvider = Provider.family<List<EntityDocument>, String>(
  (ref, entityId) {
    final all = ref.watch(documentsNotifierProvider);
    return all.where((d) => d.entityId == entityId).toList();
  },
);

// Documents expiring within 10 days (for notifications)
final expiringDocumentsProvider = Provider<List<EntityDocument>>((ref) {
  final all = ref.watch(documentsNotifierProvider);
  return all.where((d) => d.isExpiringSoon && !d.isExpired).toList();
});

EntityDocument createDocument({
  required String farmId,
  required String entityId,
  required EntityType entityType,
  required String entityName,
  required String title,
  required DocType docType,
  DateTime? issueDate,
  DateTime? expiryDate,
  String? notes,
  String? fileUrl,
  String? fileName,
  String? existingId,
}) => EntityDocument(
  id: existingId ?? _uuid.v4(),
  farmId: farmId,
  entityId: entityId,
  entityType: entityType,
  entityName: entityName,
  title: title,
  docType: docType,
  issueDate: issueDate,
  expiryDate: expiryDate,
  notes: notes,
  fileUrl: fileUrl,
  fileName: fileName,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);
