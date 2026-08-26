import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/activity_log_service.dart';
import '../../../../core/models/activity_log_model.dart';
import '../../../farms/presentation/providers/farm_provider.dart';

const _uuid = Uuid();

DateTime _parseDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.parse(v);
  return DateTime.now();
}

DateTime? _parseDateNullable(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.parse(v);
  return null;
}

/// Tek bir hasat ürün kalemi (tahıl, saman, vb.)
class YieldEntry {
  final String productName; // 'Tahıl', 'Saman', 'Diğer' veya özel
  final double amount;
  final String unit; // kg, ton, teneke, rölmörk, balya, çuval, adet...

  const YieldEntry({
    required this.productName,
    required this.amount,
    required this.unit,
  });

  factory YieldEntry.fromJson(Map<String, dynamic> json) => YieldEntry(
        productName: json['productName'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        unit: json['unit'] as String? ?? 'kg',
      );

  Map<String, dynamic> toJson() => {
        'productName': productName,
        'amount': amount,
        'unit': unit,
      };

  YieldEntry copyWith({String? productName, double? amount, String? unit}) =>
      YieldEntry(
        productName: productName ?? this.productName,
        amount: amount ?? this.amount,
        unit: unit ?? this.unit,
      );

  /// Görüntüleme metni: "Buğday Samanı — 3 rölmörk"
  String get displayText => '$productName — ${_formatAmount(amount)} $unit';

  static String _formatAmount(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}

class CropRecord {
  final String id;
  final String cropName;
  final DateTime plantedDate;
  final DateTime? harvestDate;
  /// Yeni çoklu verim listesi
  final List<YieldEntry> yields;
  /// Geriye dönük uyumluluk için eski alan
  final double? harvestAmount;
  final String harvestUnit;
  final String? notes;

  const CropRecord({
    required this.id,
    required this.cropName,
    required this.plantedDate,
    this.harvestDate,
    this.yields = const [],
    this.harvestAmount,
    this.harvestUnit = 'kg',
    this.notes,
  });

  factory CropRecord.fromJson(Map<String, dynamic> json) {
    // Eski kayıtlar için geriye dönük uyumluluk
    final yieldsRaw = json['yields'] as List?;
    List<YieldEntry> yields = [];
    if (yieldsRaw != null) {
      yields = yieldsRaw
          .whereType<Map<String, dynamic>>()
          .map(YieldEntry.fromJson)
          .toList();
    } else if (json['harvestAmount'] != null) {
      // Eski format → yields listesine dönüştür
      yields = [
        YieldEntry(
          productName: json['cropName'] as String? ?? 'Ürün',
          amount: (json['harvestAmount'] as num).toDouble(),
          unit: json['harvestUnit'] as String? ?? 'kg',
        )
      ];
    }
    return CropRecord(
      id: json['id'] as String,
      cropName: json['cropName'] as String,
      plantedDate: _parseDate(json['plantedDate']),
      harvestDate: _parseDateNullable(json['harvestDate']),
      yields: yields,
      harvestAmount: (json['harvestAmount'] as num?)?.toDouble(),
      harvestUnit: (json['harvestUnit'] as String?) ?? 'kg',
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'cropName': cropName,
        'plantedDate': plantedDate.toIso8601String(),
        'harvestDate': harvestDate?.toIso8601String(),
        'yields': yields.map((y) => y.toJson()).toList(),
        'harvestAmount': harvestAmount,
        'harvestUnit': harvestUnit,
        'notes': notes,
      };

  CropRecord copyWith({
    String? cropName,
    DateTime? plantedDate,
    DateTime? harvestDate,
    List<YieldEntry>? yields,
    double? harvestAmount,
    String? harvestUnit,
    String? notes,
    bool clearHarvestDate = false,
  }) =>
      CropRecord(
        id: id,
        cropName: cropName ?? this.cropName,
        plantedDate: plantedDate ?? this.plantedDate,
        harvestDate: clearHarvestDate ? null : (harvestDate ?? this.harvestDate),
        yields: yields ?? this.yields,
        harvestAmount: harvestAmount ?? this.harvestAmount,
        harvestUnit: harvestUnit ?? this.harvestUnit,
        notes: notes ?? this.notes,
      );

  /// Toplam ürün özetini döndürür
  String get yieldSummary {
    if (yields.isEmpty && harvestAmount != null) {
      return '$harvestAmount $harvestUnit';
    }
    return yields.map((y) => y.displayText).join('\n');
  }
}

class FieldData {
  final String id;
  final String farmId;
  final String name;
  final String? location;
  final double? areaM2;
  final String? tapuNo;
  final bool isPlanted;
  final String? currentCropName;
  final DateTime? currentPlantDate;
  final List<CropRecord> cropHistory;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FieldData({
    required this.id,
    required this.farmId,
    required this.name,
    this.location,
    this.areaM2,
    this.tapuNo,
    this.isPlanted = false,
    this.currentCropName,
    this.currentPlantDate,
    this.cropHistory = const [],
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  double? get areaDonum => areaM2 != null ? areaM2! / 1000 : null;
  double? get areaHektar => areaM2 != null ? areaM2! / 10000 : null;

  CropRecord? get lastHarvested {
    final harvested = cropHistory.where((h) => h.harvestDate != null).toList();
    if (harvested.isEmpty) return null;
    harvested.sort((a, b) => b.harvestDate!.compareTo(a.harvestDate!));
    return harvested.first;
  }

  int? get daysSinceLastHarvest {
    final last = lastHarvested;
    if (last == null) return null;
    return DateTime.now().difference(last.harvestDate!).inDays;
  }

  factory FieldData.fromFirestore(Map<String, dynamic> json, String id) {
    final historyRaw = json['cropHistory'];
    final history = <CropRecord>[];
    if (historyRaw is List) {
      for (final item in historyRaw) {
        if (item is Map<String, dynamic>) {
          history.add(CropRecord.fromJson(item));
        }
      }
    }
    return FieldData(
      id: id,
      farmId: (json['farmId'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      location: json['location'] as String?,
      areaM2: (json['areaM2'] as num?)?.toDouble(),
      tapuNo: json['tapuNo'] as String?,
      isPlanted: (json['isPlanted'] as bool?) ?? false,
      currentCropName: json['currentCropName'] as String?,
      currentPlantDate: _parseDateNullable(json['currentPlantDate']),
      cropHistory: history,
      notes: json['notes'] as String?,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'farmId': farmId,
        'name': name,
        'location': location,
        'areaM2': areaM2,
        'tapuNo': tapuNo,
        'isPlanted': isPlanted,
        'currentCropName': currentCropName,
        'currentPlantDate': currentPlantDate?.toIso8601String(),
        'cropHistory': cropHistory.map((r) => r.toJson()).toList(),
        'notes': notes,
      };

  FieldData copyWith({
    String? name,
    String? location,
    double? areaM2,
    String? tapuNo,
    bool? isPlanted,
    String? currentCropName,
    DateTime? currentPlantDate,
    List<CropRecord>? cropHistory,
    String? notes,
    bool clearLocation = false,
    bool clearAreaM2 = false,
    bool clearTapuNo = false,
    bool clearCurrentCropName = false,
    bool clearCurrentPlantDate = false,
    bool clearNotes = false,
  }) =>
      FieldData(
        id: id,
        farmId: farmId,
        name: name ?? this.name,
        location: clearLocation ? null : (location ?? this.location),
        areaM2: clearAreaM2 ? null : (areaM2 ?? this.areaM2),
        tapuNo: clearTapuNo ? null : (tapuNo ?? this.tapuNo),
        isPlanted: isPlanted ?? this.isPlanted,
        currentCropName: clearCurrentCropName ? null : (currentCropName ?? this.currentCropName),
        currentPlantDate: clearCurrentPlantDate ? null : (currentPlantDate ?? this.currentPlantDate),
        cropHistory: cropHistory ?? this.cropHistory,
        notes: clearNotes ? null : (notes ?? this.notes),
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}

class FieldsNotifier extends StateNotifier<List<FieldData>> {
  final FirestoreService _firestore;
  final String _farmId;
  final ActivityLogService _log;
  StreamSubscription<List<FieldData>>? _sub;

  FieldsNotifier(this._firestore, this._farmId, this._log) : super([]) {
    if (_farmId.isEmpty) return;
    _sub = _firestore
        .stream<FieldData>(
          farmId: _farmId,
          collection: 'fields',
          fromFirestore: FieldData.fromFirestore,
        )
        .listen((list) => state = list);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> add(FieldData f) async {
    await _firestore.set(
      farmId: _farmId,
      collection: 'fields',
      docId: f.id,
      data: f.toJson(),
    );
    _log.log(
      action: LogAction.eklendi,
      entityType: 'field',
      entityId: f.id,
      entityName: f.name,
    );
  }

  Future<void> update(FieldData f) async {
    await _firestore.update(
      farmId: _farmId,
      collection: 'fields',
      docId: f.id,
      data: f.toJson(),
    );
    _log.log(
      action: LogAction.guncellendi,
      entityType: 'field',
      entityId: f.id,
      entityName: f.name,
    );
  }

  Future<void> delete(String id) async {
    final existing = state.where((f) => f.id == id).firstOrNull;
    final name = existing?.name ?? id;
    await _firestore.delete(farmId: _farmId, collection: 'fields', docId: id);
    _log.log(
      action: LogAction.silindi,
      entityType: 'field',
      entityId: id,
      entityName: name,
    );
  }

  FieldData? getById(String id) {
    try {
      return state.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }
}

final fieldsNotifierProvider =
    StateNotifierProvider<FieldsNotifier, List<FieldData>>((ref) {
  final farmId = ref.watch(activeFarmIdProvider) ?? '';
  final firestore = ref.watch(firestoreServiceProvider);
  final log = ref.watch(activityLogServiceProvider);
  return FieldsNotifier(firestore, farmId, log);
});

final fieldsProvider = Provider<List<FieldData>>(
  (ref) => ref.watch(fieldsNotifierProvider),
);

FieldData createField({
  required String farmId,
  required String name,
  String? location,
  double? areaM2,
  String? tapuNo,
  String? notes,
}) =>
    FieldData(
      id: _uuid.v4(),
      farmId: farmId,
      name: name,
      location: location,
      areaM2: areaM2,
      tapuNo: tapuNo,
      notes: notes,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
