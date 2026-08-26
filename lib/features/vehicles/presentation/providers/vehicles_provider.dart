import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/vehicle_model.dart';
import '../../domain/entities/vehicle.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/activity_log_service.dart';
import '../../../../core/models/activity_log_model.dart';
import '../../../farms/presentation/providers/farm_provider.dart';

const _uuid = Uuid();

class VehiclesNotifier extends StateNotifier<List<VehicleModel>> {
  final FirestoreService _firestore;
  final String _farmId;
  final ActivityLogService _log;
  StreamSubscription<List<VehicleModel>>? _sub;

  VehiclesNotifier(this._firestore, this._farmId, this._log) : super([]) {
    if (_farmId.isEmpty) return;
    _sub = _firestore
        .stream<VehicleModel>(
          farmId: _farmId,
          collection: 'vehicles',
          fromFirestore: VehicleModel.fromFirestore,
        )
        .listen((list) => state = list);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> add(VehicleModel v) async {
    state = [...state, v];
    try {
      await _firestore.set(farmId: _farmId, collection: 'vehicles', docId: v.id, data: v.toJson());
      _log.log(
        action: LogAction.eklendi,
        entityType: 'vehicle',
        entityId: v.id,
        entityName: v.plate ?? '${v.brand} ${v.model}',
      );
    } catch (e) {
      state = state.where((x) => x.id != v.id).toList();
      rethrow;
    }
  }

  Future<void> update(VehicleModel v) async {
    state = state.map((x) => x.id == v.id ? v : x).toList();
    try {
      await _firestore.update(farmId: _farmId, collection: 'vehicles', docId: v.id, data: v.toJson());
      _log.log(
        action: LogAction.guncellendi,
        entityType: 'vehicle',
        entityId: v.id,
        entityName: v.plate ?? '${v.brand} ${v.model}',
      );
    } catch (_) { rethrow; }
  }

  Future<void> delete(String id) async {
    final existing = state.firstWhere((v) => v.id == id, orElse: () => state.first);
    final name = state.any((v) => v.id == id) ? (existing.plate ?? '${existing.brand} ${existing.model}') : id;
    await _firestore.delete(farmId: _farmId, collection: 'vehicles', docId: id);
    _log.log(
      action: LogAction.silindi,
      entityType: 'vehicle',
      entityId: id,
      entityName: name,
    );
  }

  VehicleModel? getById(String id) {
    try { return state.firstWhere((v) => v.id == id); } catch (_) { return null; }
  }
}

class FuelNotifier extends StateNotifier<List<FuelRecordModel>> {
  final FirestoreService _firestore;
  final String _farmId;
  final ActivityLogService _log;
  StreamSubscription<List<FuelRecordModel>>? _sub;

  FuelNotifier(this._firestore, this._farmId, this._log) : super([]) {
    if (_farmId.isEmpty) return;
    _sub = _firestore
        .stream<FuelRecordModel>(
          farmId: _farmId,
          collection: 'fuelRecords',
          fromFirestore: FuelRecordModel.fromFirestore,
          orderBy: 'date',
        )
        .listen((list) => state = list);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> add(FuelRecordModel r) async {
    state = [...state, r];
    try {
      await _firestore.set(farmId: _farmId, collection: 'fuelRecords', docId: r.id, data: r.toJson());
      _log.log(
        action: LogAction.eklendi,
        entityType: 'fuelRecord',
        entityId: r.id,
        entityName: 'Yakıt Girişi',
        details: '${r.liters.toStringAsFixed(1)} L',
      );
    } catch (e) {
      state = state.where((x) => x.id != r.id).toList();
      rethrow;
    }
  }

  Future<void> update(FuelRecordModel r) async {
    state = state.map((x) => x.id == r.id ? r : x).toList();
    await _firestore.update(farmId: _farmId, collection: 'fuelRecords', docId: r.id, data: r.toJson());
  }

  Future<void> delete(String id) => _firestore.delete(
        farmId: _farmId, collection: 'fuelRecords', docId: id);

  Future<void> deleteByVehicle(String vehicleId) async {
    final toDelete = state.where((r) => r.vehicleId == vehicleId).toList();
    for (final r in toDelete) {
      await _firestore.delete(farmId: _farmId, collection: 'fuelRecords', docId: r.id);
    }
  }
}

class MaintenanceNotifier extends StateNotifier<List<MaintenanceRecordModel>> {
  final FirestoreService _firestore;
  final String _farmId;
  final ActivityLogService _log;
  StreamSubscription<List<MaintenanceRecordModel>>? _sub;

  MaintenanceNotifier(this._firestore, this._farmId, this._log) : super([]) {
    if (_farmId.isEmpty) return;
    _sub = _firestore
        .stream<MaintenanceRecordModel>(
          farmId: _farmId,
          collection: 'maintenanceRecords',
          fromFirestore: MaintenanceRecordModel.fromFirestore,
          orderBy: 'maintenanceDate',
        )
        .listen((list) => state = list);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> add(MaintenanceRecordModel r) async {
    state = [...state, r];
    try {
      await _firestore.set(farmId: _farmId, collection: 'maintenanceRecords', docId: r.id, data: r.toJson());
      _log.log(
        action: LogAction.eklendi,
        entityType: 'maintenance',
        entityId: r.id,
        entityName: r.maintenanceType,
      );
    } catch (e) {
      state = state.where((x) => x.id != r.id).toList();
      rethrow;
    }
  }

  Future<void> update(MaintenanceRecordModel r) async {
    state = state.map((x) => x.id == r.id ? r : x).toList();
    try {
      await _firestore.update(farmId: _farmId, collection: 'maintenanceRecords', docId: r.id, data: r.toJson());
      _log.log(
        action: LogAction.guncellendi,
        entityType: 'maintenance',
        entityId: r.id,
        entityName: r.maintenanceType,
      );
    } catch (_) { rethrow; }
  }

  Future<void> delete(String id) async {
    final existing = state.firstWhere((r) => r.id == id, orElse: () => state.first);
    final name = state.any((r) => r.id == id) ? existing.maintenanceType : id;
    await _firestore.delete(farmId: _farmId, collection: 'maintenanceRecords', docId: id);
    _log.log(
      action: LogAction.silindi,
      entityType: 'maintenance',
      entityId: id,
      entityName: name,
    );
  }

  Future<void> deleteByVehicle(String vehicleId) async {
    final toDelete = state.where((r) => r.vehicleId == vehicleId).toList();
    for (final r in toDelete) {
      await _firestore.delete(farmId: _farmId, collection: 'maintenanceRecords', docId: r.id);
    }
  }
}

// ── Providers ─────────────────────────────────────────────

final vehiclesNotifierProvider =
    StateNotifierProvider<VehiclesNotifier, List<VehicleModel>>((ref) {
  final farmId = ref.watch(activeFarmIdProvider) ?? '';
  final firestore = ref.watch(firestoreServiceProvider);
  final log = ref.watch(activityLogServiceProvider);
  return VehiclesNotifier(firestore, farmId, log);
});

final fuelNotifierProvider =
    StateNotifierProvider<FuelNotifier, List<FuelRecordModel>>((ref) {
  final farmId = ref.watch(activeFarmIdProvider) ?? '';
  final firestore = ref.watch(firestoreServiceProvider);
  final log = ref.watch(activityLogServiceProvider);
  return FuelNotifier(firestore, farmId, log);
});

final maintenanceNotifierProvider =
    StateNotifierProvider<MaintenanceNotifier, List<MaintenanceRecordModel>>((ref) {
  final farmId = ref.watch(activeFarmIdProvider) ?? '';
  final firestore = ref.watch(firestoreServiceProvider);
  final log = ref.watch(activityLogServiceProvider);
  return MaintenanceNotifier(firestore, farmId, log);
});

final vehiclesProvider = Provider.family<List<VehicleModel>, String>(
  (ref, farmId) => ref.watch(vehiclesNotifierProvider),
);

final vehicleDetailProvider = Provider.family<VehicleModel?, String>(
  (ref, id) {
    try { return ref.watch(vehiclesNotifierProvider).firstWhere((v) => v.id == id); }
    catch (_) { return null; }
  },
);

final fuelRecordsProvider = Provider.family<List<FuelRecordModel>, String>(
  (ref, vehicleId) =>
      ref.watch(fuelNotifierProvider).where((f) => f.vehicleId == vehicleId).toList(),
);

final maintenanceRecordsProvider =
    Provider.family<List<MaintenanceRecordModel>, String>(
  (ref, vehicleId) =>
      ref.watch(maintenanceNotifierProvider).where((m) => m.vehicleId == vehicleId).toList(),
);

final monthlyFuelCostProvider = Provider.family<double, String>(
  (ref, farmId) {
    final now = DateTime.now();
    return ref.watch(fuelNotifierProvider).fold(0.0, (sum, f) {
      if (f.date.year == now.year && f.date.month == now.month) return sum + f.totalCost;
      return sum;
    });
  },
);

// ── Helpers ───────────────────────────────────────────────

VehicleModel createVehicle({
  required String userId,
  required String type, required String brand, required String model,
  int? year, String? plate, String? chassisNo, String? engineNo,
  int? enginePower, int? engineCC, String? fuelType,
  double? currentKm, double? workingHours,
  VehicleStatus status = VehicleStatus.active, String? notes, String? photoUrl,
}) => VehicleModel(
  id: _uuid.v4(), farmId: userId, type: type, brand: brand, model: model,
  year: year, plate: plate, chassisNo: chassisNo, engineNo: engineNo,
  enginePower: enginePower, engineCC: engineCC, fuelType: fuelType,
  currentKm: currentKm, workingHours: workingHours,
  status: status, notes: notes, photoUrl: photoUrl,
  createdAt: DateTime.now(), updatedAt: DateTime.now(),
);

FuelRecordModel createFuelRecord({
  required String vehicleId, required DateTime date,
  required double liters, required double pricePerLiter,
  double? currentKm, String? notes,
}) => FuelRecordModel(
  id: _uuid.v4(), vehicleId: vehicleId, date: date,
  liters: liters, pricePerLiter: pricePerLiter,
  totalCost: liters * pricePerLiter,
  currentKm: currentKm, notes: notes,
);

MaintenanceRecordModel createMaintenanceRecord({
  required String vehicleId, required String maintenanceType,
  required DateTime maintenanceDate, DateTime? nextMaintenanceDate,
  double? cost, String? serviceProvider, String? notes,
}) => MaintenanceRecordModel(
  id: _uuid.v4(), vehicleId: vehicleId, maintenanceType: maintenanceType,
  maintenanceDate: maintenanceDate, nextMaintenanceDate: nextMaintenanceDate,
  cost: cost, serviceProvider: serviceProvider, notes: notes,
);
