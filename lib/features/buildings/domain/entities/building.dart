import 'package:equatable/equatable.dart';

class Building extends Equatable {
  final String id;
  final String farmId;
  final String type;
  final String name;
  final double? area;
  final int? constructionYear;
  final String? photoUrl;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Building({
    required this.id,
    required this.farmId,
    required this.type,
    required this.name,
    this.area,
    this.constructionYear,
    this.photoUrl,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id, farmId, name, type];
}

class Device extends Equatable {
  final String id;
  final String buildingId;
  final String name;
  final String? brand;
  final double wattage;
  final double dailyUsageHours;
  final int workingDaysPerMonth;
  final bool isActive;
  final String? notes;

  const Device({
    required this.id,
    required this.buildingId,
    required this.name,
    this.brand,
    required this.wattage,
    required this.dailyUsageHours,
    required this.workingDaysPerMonth,
    this.isActive = true,
    this.notes,
  });

  /// kWh per day
  double get dailyConsumption => (wattage / 1000) * dailyUsageHours;

  /// kWh per month
  double get monthlyConsumption => dailyConsumption * workingDaysPerMonth;

  double monthlyBill(double ratePerKwh) => monthlyConsumption * ratePerKwh;

  @override
  List<Object?> get props => [id, buildingId, name];
}

class EnergyReading extends Equatable {
  final String id;
  final String buildingId;
  final DateTime readingDate;
  final double reading;
  final double? previousReading;
  final double? consumption;
  final double? cost;
  final String? notes;

  const EnergyReading({
    required this.id,
    required this.buildingId,
    required this.readingDate,
    required this.reading,
    this.previousReading,
    this.consumption,
    this.cost,
    this.notes,
  });

  @override
  List<Object?> get props => [id, buildingId, readingDate];
}
