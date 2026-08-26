import 'package:equatable/equatable.dart';

enum VehicleStatus { active, maintenance, broken, sold }

class Vehicle extends Equatable {
  final String id;
  final String farmId;
  final String type;
  final String brand;
  final String model;
  final int? year;
  final String? plate;
  final String? chassisNo;
  final String? engineNo;
  final int? enginePower; // HP
  final int? engineCC;    // cc
  final String? fuelType;
  final double? currentKm;
  final double? workingHours;
  final VehicleStatus status;
  final String? photoUrl;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Vehicle({
    required this.id,
    required this.farmId,
    required this.type,
    required this.brand,
    required this.model,
    this.year,
    this.plate,
    this.chassisNo,
    this.engineNo,
    this.enginePower,
    this.engineCC,
    this.fuelType,
    this.currentKm,
    this.workingHours,
    this.status = VehicleStatus.active,
    this.photoUrl,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  String get displayName => '$brand $model';

  String get statusLabel {
    switch (status) {
      case VehicleStatus.active: return 'Aktif';
      case VehicleStatus.maintenance: return 'Bakımda';
      case VehicleStatus.broken: return 'Arızalı';
      case VehicleStatus.sold: return 'Satıldı';
    }
  }

  @override
  List<Object?> get props => [id, farmId, type, brand, model, plate];
}

class FuelRecord extends Equatable {
  final String id;
  final String vehicleId;
  final DateTime date;
  final double liters;
  final double pricePerLiter;
  final double totalCost;
  final double? currentKm;
  final String? receiptPhotoUrl;
  final String? notes;

  const FuelRecord({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.liters,
    required this.pricePerLiter,
    required this.totalCost,
    this.currentKm,
    this.receiptPhotoUrl,
    this.notes,
  });

  @override
  List<Object?> get props => [id, vehicleId, date];
}

class MaintenanceRecord extends Equatable {
  final String id;
  final String vehicleId;
  final String maintenanceType;
  final DateTime maintenanceDate;
  final DateTime? nextMaintenanceDate;
  final double? cost;
  final String? serviceProvider;
  final String? notes;

  const MaintenanceRecord({
    required this.id,
    required this.vehicleId,
    required this.maintenanceType,
    required this.maintenanceDate,
    this.nextMaintenanceDate,
    this.cost,
    this.serviceProvider,
    this.notes,
  });

  @override
  List<Object?> get props => [id, vehicleId, maintenanceDate];
}
