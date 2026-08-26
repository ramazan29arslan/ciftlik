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

class BuildingData {
  final String id;
  final String name;
  final String type;
  final double? area;
  final int? constructionYear;
  final String? notes;
  final String? photoUrl;
  final List<Map<String, dynamic>> devices;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BuildingData({
    required this.id,
    required this.name,
    required this.type,
    this.area,
    this.constructionYear,
    this.notes,
    this.photoUrl,
    this.devices = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory BuildingData.fromFirestore(Map<String, dynamic> json, String id) {
    return BuildingData(
      id: id,
      name: json['name'] as String,
      type: json['type'] as String,
      area: (json['area'] as num?)?.toDouble(),
      constructionYear: json['constructionYear'] as int?,
      notes: json['notes'] as String?,
      photoUrl: json['photoUrl'] as String?,
      devices: (json['devices'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'area': area,
        'constructionYear': constructionYear,
        'notes': notes,
        'photoUrl': photoUrl,
        'devices': devices,
      };

  BuildingData copyWith({
    String? name, String? type, double? area,
    int? constructionYear, String? notes, String? photoUrl,
    List<Map<String, dynamic>>? devices,
  }) => BuildingData(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    area: area ?? this.area,
    constructionYear: constructionYear ?? this.constructionYear,
    notes: notes ?? this.notes,
    photoUrl: photoUrl ?? this.photoUrl,
    devices: devices ?? this.devices,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}

class BuildingsNotifier extends StateNotifier<List<BuildingData>> {
  final FirestoreService _firestore;
  final String _farmId;
  final ActivityLogService _log;
  StreamSubscription<List<BuildingData>>? _sub;

  BuildingsNotifier(this._firestore, this._farmId, this._log) : super([]) {
    if (_farmId.isEmpty) return;
    _sub = _firestore
        .stream<BuildingData>(
          farmId: _farmId,
          collection: 'buildings',
          fromFirestore: BuildingData.fromFirestore,
        )
        .listen((list) => state = list);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> add(BuildingData b) async {
    await _firestore.set(farmId: _farmId, collection: 'buildings', docId: b.id, data: b.toJson());
    _log.log(
      action: LogAction.eklendi,
      entityType: 'building',
      entityId: b.id,
      entityName: b.name,
    );
  }

  Future<void> update(BuildingData b) async {
    await _firestore.update(farmId: _farmId, collection: 'buildings', docId: b.id, data: b.toJson());
    _log.log(
      action: LogAction.guncellendi,
      entityType: 'building',
      entityId: b.id,
      entityName: b.name,
    );
  }

  Future<void> delete(String id) async {
    final existing = state.firstWhere((b) => b.id == id, orElse: () => state.first);
    final name = state.any((b) => b.id == id) ? existing.name : id;
    await _firestore.delete(farmId: _farmId, collection: 'buildings', docId: id);
    _log.log(
      action: LogAction.silindi,
      entityType: 'building',
      entityId: id,
      entityName: name,
    );
  }

  BuildingData? getById(String id) {
    try { return state.firstWhere((b) => b.id == id); } catch (_) { return null; }
  }
}

final buildingsNotifierProvider =
    StateNotifierProvider<BuildingsNotifier, List<BuildingData>>((ref) {
  final farmId = ref.watch(activeFarmIdProvider) ?? '';
  final firestore = ref.watch(firestoreServiceProvider);
  final log = ref.watch(activityLogServiceProvider);
  return BuildingsNotifier(firestore, farmId, log);
});

final buildingsProvider = Provider<List<BuildingData>>(
  (ref) => ref.watch(buildingsNotifierProvider),
);

BuildingData createBuilding({
  required String name,
  required String type,
  double? area,
  int? constructionYear,
  String? notes,
  String? photoUrl,
}) => BuildingData(
  id: _uuid.v4(),
  name: name,
  type: type,
  area: area,
  constructionYear: constructionYear,
  notes: notes,
  photoUrl: photoUrl,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);
