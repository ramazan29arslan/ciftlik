import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/stock_model.dart';
import '../../domain/entities/stock_item.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../farms/presentation/providers/farm_provider.dart';

const _uuid = Uuid();

class StockNotifier extends StateNotifier<List<StockItemModel>> {
  final FirestoreService _firestore;
  final String _farmId;
  StreamSubscription<List<StockItemModel>>? _sub;

  StockNotifier(this._firestore, this._farmId) : super([]) {
    if (_farmId.isEmpty) return;
    _sub = _firestore
        .stream<StockItemModel>(
          farmId: _farmId,
          collection: 'stockItems',
          fromFirestore: StockItemModel.fromFirestore,
        )
        .listen((list) => state = list);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> add(StockItemModel item) => _firestore.set(
        farmId: _farmId, collection: 'stockItems', docId: item.id, data: item.toJson());

  Future<void> update(StockItemModel item) => _firestore.update(
        farmId: _farmId, collection: 'stockItems', docId: item.id, data: item.toJson());

  Future<void> delete(String id) => _firestore.delete(
        farmId: _farmId, collection: 'stockItems', docId: id);

  Future<void> addQuantity(String id, double qty) async {
    final item = state.firstWhere((s) => s.id == id);
    await _firestore.update(
      farmId: _farmId,
      collection: 'stockItems',
      docId: id,
      data: {'currentQuantity': item.currentQuantity + qty},
    );
  }

  Future<void> removeQuantity(String id, double qty) async {
    final item = state.firstWhere((s) => s.id == id);
    final newQty = (item.currentQuantity - qty).clamp(0.0, double.infinity);
    await _firestore.update(
      farmId: _farmId,
      collection: 'stockItems',
      docId: id,
      data: {'currentQuantity': newQty},
    );
  }

  StockItemModel? getById(String id) {
    try { return state.firstWhere((s) => s.id == id); } catch (_) { return null; }
  }
}

class StockMovementsNotifier extends StateNotifier<List<StockMovementModel>> {
  final FirestoreService _firestore;
  final String _farmId;
  StreamSubscription<List<StockMovementModel>>? _sub;

  StockMovementsNotifier(this._firestore, this._farmId) : super([]) {
    if (_farmId.isEmpty) return;
    _sub = _firestore
        .stream<StockMovementModel>(
          farmId: _farmId,
          collection: 'stockMovements',
          fromFirestore: StockMovementModel.fromFirestore,
          orderBy: 'date',
        )
        .listen((list) => state = list);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> add(StockMovementModel m) => _firestore.set(
        farmId: _farmId, collection: 'stockMovements', docId: m.id, data: m.toJson());

  Future<void> delete(String id) => _firestore.delete(
        farmId: _farmId, collection: 'stockMovements', docId: id);
}

// ── Providers ─────────────────────────────────────────────

final stockNotifierProvider =
    StateNotifierProvider<StockNotifier, List<StockItemModel>>((ref) {
  final farmId = ref.watch(activeFarmIdProvider) ?? '';
  final firestore = ref.watch(firestoreServiceProvider);
  return StockNotifier(firestore, farmId);
});

final stockMovementsNotifierProvider =
    StateNotifierProvider<StockMovementsNotifier, List<StockMovementModel>>((ref) {
  final farmId = ref.watch(activeFarmIdProvider) ?? '';
  final firestore = ref.watch(firestoreServiceProvider);
  return StockMovementsNotifier(firestore, farmId);
});

final stockItemsProvider = Provider.family<List<StockItemModel>, String>(
  (ref, farmId) => ref.watch(stockNotifierProvider),
);

final stockItemDetailProvider = Provider.family<StockItemModel?, String>(
  (ref, id) {
    try { return ref.watch(stockNotifierProvider).firstWhere((s) => s.id == id); }
    catch (_) { return null; }
  },
);

final stockMovementsProvider = Provider.family<List<StockMovementModel>, String>(
  (ref, stockItemId) =>
      ref.watch(stockMovementsNotifierProvider).where((m) => m.stockItemId == stockItemId).toList(),
);

final lowStockCountProvider = Provider.family<int, String>(
  (ref, farmId) => ref.watch(stockNotifierProvider).where((s) => s.isLowStock).length,
);

final lowStockItemsProvider = Provider.family<List<StockItemModel>, String>(
  (ref, farmId) => ref.watch(stockNotifierProvider).where((s) => s.isLowStock).toList(),
);

// ── Helpers ───────────────────────────────────────────────

StockItemModel createStockItem({
  required String userId,
  required String name, required String category,
  required String unit, double currentQuantity = 0,
  required double minimumQuantity, double? unitPrice,
  String? supplier, String? notes,
}) => StockItemModel(
  id: _uuid.v4(), farmId: userId, name: name, category: category,
  unit: unit, currentQuantity: currentQuantity,
  minimumQuantity: minimumQuantity, unitPrice: unitPrice,
  supplier: supplier, notes: notes,
  createdAt: DateTime.now(), updatedAt: DateTime.now(),
);

StockMovementModel createMovement({
  required String stockItemId, required StockMovementType type,
  required double quantity, double? unitPrice,
  String? reason, String? supplier, String? notes,
}) => StockMovementModel(
  id: _uuid.v4(), stockItemId: stockItemId, type: type,
  quantity: quantity, unitPrice: unitPrice,
  totalCost: unitPrice != null ? quantity * unitPrice : null,
  reason: reason, supplier: supplier,
  date: DateTime.now(), notes: notes,
);
