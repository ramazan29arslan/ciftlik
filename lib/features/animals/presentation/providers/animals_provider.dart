import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/animal_model.dart';
import '../../domain/entities/animal.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/activity_log_service.dart';
import '../../../../core/models/activity_log_model.dart';
import '../../../farms/presentation/providers/farm_provider.dart';

const _uuid = Uuid();

// ── Firestore-backed Notifiers ─────────────────────────────

class AnimalsNotifier extends StateNotifier<List<AnimalModel>> {
  final FirestoreService _firestore;
  final String _farmId;
  final ActivityLogService _log;
  StreamSubscription<List<AnimalModel>>? _sub;

  AnimalsNotifier(this._firestore, this._farmId, this._log) : super([]) {
    if (_farmId.isEmpty) return;
    _sub = _firestore
        .stream<AnimalModel>(
          farmId: _farmId,
          collection: 'animals',
          fromFirestore: AnimalModel.fromFirestore,
        )
        .listen((list) => state = list);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> add(AnimalModel animal) async {
    state = [...state, animal];
    try {
      await _firestore.set(
        farmId: _farmId,
        collection: 'animals',
        docId: animal.id,
        data: animal.toJson(),
      );
      _log.log(
        action: LogAction.eklendi,
        entityType: 'animal',
        entityId: animal.id,
        entityName: animal.name ?? animal.tagNumber,
      );
    } catch (e) {
      state = state.where((a) => a.id != animal.id).toList();
      rethrow;
    }
  }

  Future<void> update(AnimalModel animal) async {
    state = state.map((a) => a.id == animal.id ? animal : a).toList();
    try {
      await _firestore.update(
        farmId: _farmId,
        collection: 'animals',
        docId: animal.id,
        data: animal.toJson(),
      );
      _log.log(
        action: LogAction.guncellendi,
        entityType: 'animal',
        entityId: animal.id,
        entityName: animal.name ?? animal.tagNumber,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    final existing = state.firstWhere((a) => a.id == id, orElse: () => state.first);
    final name = state.any((a) => a.id == id) ? (existing.name ?? existing.tagNumber) : id;
    await _firestore.delete(
      farmId: _farmId,
      collection: 'animals',
      docId: id,
    );
    _log.log(
      action: LogAction.silindi,
      entityType: 'animal',
      entityId: id,
      entityName: name,
    );
  }

  AnimalModel? getById(String id) {
    try {
      return state.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }
}

class VaccinationsNotifier extends StateNotifier<List<AnimalVaccinationModel>> {
  final FirestoreService _firestore;
  final String _farmId;
  final ActivityLogService _log;
  StreamSubscription<List<AnimalVaccinationModel>>? _sub;

  VaccinationsNotifier(this._firestore, this._farmId, this._log) : super([]) {
    if (_farmId.isEmpty) return;
    _sub = _firestore
        .stream<AnimalVaccinationModel>(
          farmId: _farmId,
          collection: 'vaccinations',
          fromFirestore: (data, id) =>
              AnimalVaccinationModel.fromJson({...data, 'id': id}),
        )
        .listen((list) => state = list);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> add(AnimalVaccinationModel v) async {
    state = [...state, v];
    try {
      await _firestore.set(farmId: _farmId, collection: 'vaccinations', docId: v.id, data: v.toJson());
      _log.log(
        action: LogAction.eklendi,
        entityType: 'vaccination',
        entityId: v.id,
        entityName: v.vaccineName,
        details: 'Hayvan: ${v.animalId}',
      );
    } catch (e) {
      state = state.where((x) => x.id != v.id).toList();
      rethrow;
    }
  }

  Future<void> update(AnimalVaccinationModel v) async {
    state = state.map((x) => x.id == v.id ? v : x).toList();
    await _firestore.update(farmId: _farmId, collection: 'vaccinations', docId: v.id, data: v.toJson());
  }

  Future<void> delete(String id) => _firestore.delete(
        farmId: _farmId,
        collection: 'vaccinations',
        docId: id,
      );

  Future<void> deleteByAnimal(String animalId) async {
    final toDelete = state.where((v) => v.animalId == animalId).toList();
    for (final v in toDelete) {
      await _firestore.delete(
          farmId: _farmId, collection: 'vaccinations', docId: v.id);
    }
  }

  List<AnimalVaccinationModel> forAnimal(String animalId) =>
      state.where((v) => v.animalId == animalId).toList();
}

class MilkRecordsNotifier extends StateNotifier<List<MilkRecordModel>> {
  final FirestoreService _firestore;
  final String _farmId;
  final ActivityLogService _log;
  StreamSubscription<List<MilkRecordModel>>? _sub;

  MilkRecordsNotifier(this._firestore, this._farmId, this._log) : super([]) {
    if (_farmId.isEmpty) return;
    _sub = _firestore
        .stream<MilkRecordModel>(
          farmId: _farmId,
          collection: 'milkRecords',
          fromFirestore: (data, id) =>
              MilkRecordModel.fromJson({...data, 'id': id}),
        )
        .listen((list) => state = list);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> add(MilkRecordModel r) async {
    state = [...state, r];
    try {
      await _firestore.set(farmId: _farmId, collection: 'milkRecords', docId: r.id, data: r.toJson());
      _log.log(
        action: LogAction.eklendi,
        entityType: 'milkRecord',
        entityId: r.id,
        entityName: 'Süt Kaydı',
        details: '${r.totalAmount.toStringAsFixed(1)} L',
      );
    } catch (e) {
      state = state.where((x) => x.id != r.id).toList();
      rethrow;
    }
  }

  Future<void> update(MilkRecordModel r) async {
    state = state.map((x) => x.id == r.id ? r : x).toList();
    await _firestore.update(farmId: _farmId, collection: 'milkRecords', docId: r.id, data: r.toJson());
  }

  Future<void> delete(String id) => _firestore.delete(
        farmId: _farmId,
        collection: 'milkRecords',
        docId: id,
      );

  Future<void> deleteByAnimal(String animalId) async {
    final toDelete = state.where((r) => r.animalId == animalId).toList();
    for (final r in toDelete) {
      await _firestore.delete(
          farmId: _farmId, collection: 'milkRecords', docId: r.id);
    }
  }

  List<MilkRecordModel> forAnimal(String animalId) =>
      state.where((r) => r.animalId == animalId).toList();
}

// ── Providers ─────────────────────────────────────────────

final animalsNotifierProvider =
    StateNotifierProvider<AnimalsNotifier, List<AnimalModel>>((ref) {
  final farmId = ref.watch(activeFarmIdProvider) ?? '';
  final firestore = ref.watch(firestoreServiceProvider);
  final log = ref.watch(activityLogServiceProvider);
  return AnimalsNotifier(firestore, farmId, log);
});

final vaccinationsNotifierProvider =
    StateNotifierProvider<VaccinationsNotifier, List<AnimalVaccinationModel>>(
        (ref) {
  final farmId = ref.watch(activeFarmIdProvider) ?? '';
  final firestore = ref.watch(firestoreServiceProvider);
  final log = ref.watch(activityLogServiceProvider);
  return VaccinationsNotifier(firestore, farmId, log);
});

final milkRecordsNotifierProvider =
    StateNotifierProvider<MilkRecordsNotifier, List<MilkRecordModel>>((ref) {
  final farmId = ref.watch(activeFarmIdProvider) ?? '';
  final firestore = ref.watch(firestoreServiceProvider);
  final log = ref.watch(activityLogServiceProvider);
  return MilkRecordsNotifier(firestore, farmId, log);
});

final animalsProvider = Provider.family<List<AnimalModel>, String>(
  (ref, farmId) => ref.watch(animalsNotifierProvider),
);

final animalDetailProvider = Provider.family<AnimalModel?, String>(
  (ref, id) {
    final animals = ref.watch(animalsNotifierProvider);
    try {
      return animals.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  },
);

final animalVaccinationsProvider =
    Provider.family<List<AnimalVaccinationModel>, String>(
  (ref, animalId) {
    final all = ref.watch(vaccinationsNotifierProvider);
    return all.where((v) => v.animalId == animalId).toList();
  },
);

final milkRecordsProvider = Provider.family<List<MilkRecordModel>, String>(
  (ref, animalId) {
    final all = ref.watch(milkRecordsNotifierProvider);
    return all.where((r) => r.animalId == animalId).toList();
  },
);

final animalCountProvider = Provider.family<int, String>(
  (ref, farmId) => ref
      .watch(animalsNotifierProvider)
      .where((a) => a.status == AnimalStatus.active)
      .length,
);

final upcomingVaccinationsProvider =
    Provider.family<List<AnimalVaccinationModel>, String>(
  (ref, farmId) {
    final now = DateTime.now();
    final future = now.add(const Duration(days: 30));
    return ref.watch(vaccinationsNotifierProvider).where((v) {
      if (v.nextVaccinationDate != null) {
        return v.nextVaccinationDate!.isAfter(now) &&
            v.nextVaccinationDate!.isBefore(future);
      }
      return false;
    }).toList();
  },
);

final totalNotificationCountProvider =
    Provider.family<int, String>((ref, farmId) {
  return ref.watch(upcomingVaccinationsProvider(farmId)).length;
});

// ── Filter ────────────────────────────────────────────────

class AnimalsFilter {
  final String? type;
  final AnimalStatus? status;
  final AnimalGender? gender;
  final String? ageRange; // '0-1', '1-3', '3-7', '7+'
  final String? searchQuery;
  const AnimalsFilter({this.type, this.status, this.gender, this.ageRange, this.searchQuery});
  AnimalsFilter copyWith({
    String? type, AnimalStatus? status, AnimalGender? gender,
    String? ageRange, String? searchQuery,
  }) => AnimalsFilter(
    type: type ?? this.type,
    status: status ?? this.status,
    gender: gender ?? this.gender,
    ageRange: ageRange ?? this.ageRange,
    searchQuery: searchQuery ?? this.searchQuery,
  );

  bool get hasActiveFilters => type != null || status != null || gender != null || ageRange != null;
}

final animalsFilterProvider =
    StateProvider<AnimalsFilter>((ref) => const AnimalsFilter());

final filteredAnimalsProvider =
    Provider.family<List<AnimalModel>, String>((ref, farmId) {
  final animals = ref.watch(animalsNotifierProvider);
  final filter = ref.watch(animalsFilterProvider);
  var filtered = animals;
  if (filter.type != null)
    filtered = filtered.where((a) => a.type == filter.type).toList();
  if (filter.status != null)
    filtered = filtered.where((a) => a.status == filter.status).toList();
  if (filter.gender != null)
    filtered = filtered.where((a) => a.gender == filter.gender).toList();
  if (filter.ageRange != null) {
    filtered = filtered.where((a) {
      if (a.birthDate == null) return false;
      final ageYears = DateTime.now().difference(a.birthDate!).inDays / 365.25;
      switch (filter.ageRange) {
        case '0-1': return ageYears < 1;
        case '1-3': return ageYears >= 1 && ageYears < 3;
        case '3-7': return ageYears >= 3 && ageYears < 7;
        case '7+':  return ageYears >= 7;
        default: return true;
      }
    }).toList();
  }
  if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
    final q = filter.searchQuery!.toLowerCase();
    filtered = filtered
        .where((a) =>
            a.tagNumber.toLowerCase().contains(q) ||
            (a.name?.toLowerCase().contains(q) ?? false) ||
            a.type.toLowerCase().contains(q))
        .toList();
  }
  return filtered;
});

// ── Helper ────────────────────────────────────────────────

AnimalModel createAnimal({
  required String tagNumber,
  String? name,
  required String type,
  String? breed,
  DateTime? birthDate,
  AnimalGender? gender,
  AnimalStatus status = AnimalStatus.active,
  double? weight,
  String? notes,
  String? photoUrl,
  String? motherId,
  String? fatherId,
  InseminationType? inseminationType,
  DateTime? inseminationDate,
  String? inseminationMateId,
  String? buyerEmail,
  required String userId,
  String? animalId,
}) =>
    AnimalModel(
      id: animalId ?? _uuid.v4(),
      farmId: userId,
      tagNumber: tagNumber,
      name: name,
      type: type,
      breed: breed,
      birthDate: birthDate,
      gender: gender,
      status: status,
      weight: weight,
      notes: notes,
      photoUrl: photoUrl,
      motherId: motherId,
      fatherId: fatherId,
      inseminationType: inseminationType,
      inseminationDate: inseminationDate,
      inseminationMateId: inseminationMateId,
      buyerEmail: buyerEmail,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
