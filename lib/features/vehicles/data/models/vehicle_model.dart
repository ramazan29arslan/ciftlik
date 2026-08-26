import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/vehicle.dart';

DateTime _parseDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.parse(v);
  return DateTime.now();
}

class VehicleModel extends Vehicle {
  const VehicleModel({
    required super.id,
    required super.farmId,
    required super.type,
    required super.brand,
    required super.model,
    super.year,
    super.plate,
    super.chassisNo,
    super.engineNo,
    super.enginePower,
    super.engineCC,
    super.fuelType,
    super.currentKm,
    super.workingHours,
    super.status,
    super.photoUrl,
    super.notes,
    required super.createdAt,
    required super.updatedAt,
  });

  factory VehicleModel.fromFirestore(Map<String, dynamic> json, String id) {
    return VehicleModel(
      id: id,
      farmId: (json['farmId'] ?? json['farm_id'] ?? '') as String,
      type: json['type'] as String,
      brand: json['brand'] as String,
      model: json['model'] as String,
      year: json['year'] as int?,
      plate: (json['plate']) as String?,
      chassisNo: (json['chassisNo'] ?? json['chassis_no']) as String?,
      engineNo: (json['engineNo'] ?? json['engine_no']) as String?,
      enginePower: json['enginePower'] as int? ?? json['engine_power'] as int?,
      engineCC: json['engineCC'] as int? ?? json['engine_cc'] as int?,
      fuelType: (json['fuelType'] ?? json['fuel_type']) as String?,
      currentKm: ((json['currentKm'] ?? json['current_km']) as num?)?.toDouble(),
      workingHours: ((json['workingHours'] ?? json['working_hours']) as num?)?.toDouble(),
      status: VehicleStatus.values.firstWhere(
        (e) => e.name == (json['status'] ?? 'active'),
        orElse: () => VehicleStatus.active,
      ),
      photoUrl: (json['photoUrl'] ?? json['photo_url']) as String?,
      notes: json['notes'] as String?,
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'farmId': farmId,
        'type': type,
        'brand': brand,
        'model': model,
        'year': year,
        'plate': plate,
        'chassisNo': chassisNo,
        'engineNo': engineNo,
        'enginePower': enginePower,
        'engineCC': engineCC,
        'fuelType': fuelType,
        'currentKm': currentKm,
        'workingHours': workingHours,
        'status': status.name,
        'photoUrl': photoUrl,
        'notes': notes,
      };

  VehicleModel copyWith({
    String? id, String? farmId, String? type, String? brand, String? model,
    int? year, String? plate, String? chassisNo, String? engineNo,
    int? enginePower, int? engineCC, String? fuelType,
    double? currentKm, double? workingHours, VehicleStatus? status,
    String? photoUrl, String? notes, DateTime? createdAt, DateTime? updatedAt,
  }) => VehicleModel(
    id: id ?? this.id, farmId: farmId ?? this.farmId,
    type: type ?? this.type, brand: brand ?? this.brand, model: model ?? this.model,
    year: year ?? this.year, plate: plate ?? this.plate,
    chassisNo: chassisNo ?? this.chassisNo, engineNo: engineNo ?? this.engineNo,
    enginePower: enginePower ?? this.enginePower, engineCC: engineCC ?? this.engineCC,
    fuelType: fuelType ?? this.fuelType,
    currentKm: currentKm ?? this.currentKm, workingHours: workingHours ?? this.workingHours,
    status: status ?? this.status, photoUrl: photoUrl ?? this.photoUrl,
    notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
  );
}

class FuelRecordModel extends FuelRecord {
  const FuelRecordModel({
    required super.id, required super.vehicleId, required super.date,
    required super.liters, required super.pricePerLiter, required super.totalCost,
    super.currentKm, super.receiptPhotoUrl, super.notes,
  });

  factory FuelRecordModel.fromFirestore(Map<String, dynamic> json, String id) =>
      FuelRecordModel(
        id: id,
        vehicleId: (json['vehicleId'] ?? json['vehicle_id']) as String,
        date: _parseDate(json['date']),
        liters: (json['liters'] as num).toDouble(),
        pricePerLiter: ((json['pricePerLiter'] ?? json['price_per_liter']) as num).toDouble(),
        totalCost: ((json['totalCost'] ?? json['total_cost']) as num).toDouble(),
        currentKm: ((json['currentKm'] ?? json['current_km']) as num?)?.toDouble(),
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'vehicleId': vehicleId,
        'date': date.toIso8601String(),
        'liters': liters,
        'pricePerLiter': pricePerLiter,
        'totalCost': totalCost,
        'currentKm': currentKm,
        'notes': notes,
      };

  FuelRecordModel copyWith({
    DateTime? date,
    double? liters,
    double? pricePerLiter,
    double? totalCost,
    double? currentKm,
    String? notes,
    bool clearCurrentKm = false,
    bool clearNotes = false,
  }) => FuelRecordModel(
    id: id, vehicleId: vehicleId,
    date: date ?? this.date,
    liters: liters ?? this.liters,
    pricePerLiter: pricePerLiter ?? this.pricePerLiter,
    totalCost: totalCost ?? this.totalCost,
    currentKm: clearCurrentKm ? null : (currentKm ?? this.currentKm),
    notes: clearNotes ? null : (notes ?? this.notes),
  );
}

class MaintenanceRecordModel extends MaintenanceRecord {
  const MaintenanceRecordModel({
    required super.id, required super.vehicleId, required super.maintenanceType,
    required super.maintenanceDate, super.nextMaintenanceDate,
    super.cost, super.serviceProvider, super.notes,
  });

  factory MaintenanceRecordModel.fromFirestore(Map<String, dynamic> json, String id) =>
      MaintenanceRecordModel(
        id: id,
        vehicleId: (json['vehicleId'] ?? json['vehicle_id']) as String,
        maintenanceType: (json['maintenanceType'] ?? json['maintenance_type']) as String,
        maintenanceDate: _parseDate(json['maintenanceDate'] ?? json['maintenance_date']),
        nextMaintenanceDate: json['nextMaintenanceDate'] != null
            ? _parseDate(json['nextMaintenanceDate'])
            : json['next_maintenance_date'] != null
                ? _parseDate(json['next_maintenance_date'])
                : null,
        cost: (json['cost'] as num?)?.toDouble(),
        serviceProvider: (json['serviceProvider'] ?? json['service_provider']) as String?,
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'vehicleId': vehicleId,
        'maintenanceType': maintenanceType,
        'maintenanceDate': maintenanceDate.toIso8601String(),
        'nextMaintenanceDate': nextMaintenanceDate?.toIso8601String(),
        'cost': cost,
        'serviceProvider': serviceProvider,
        'notes': notes,
      };
}
