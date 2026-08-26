import 'package:equatable/equatable.dart';

enum StockMovementType { incoming, outgoing }

class StockItem extends Equatable {
  final String id;
  final String farmId;
  final String name;
  final String category;
  final String unit;
  final double currentQuantity;
  final double minimumQuantity;
  final double? unitPrice;
  final String? supplier;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StockItem({
    required this.id,
    required this.farmId,
    required this.name,
    required this.category,
    required this.unit,
    required this.currentQuantity,
    required this.minimumQuantity,
    this.unitPrice,
    this.supplier,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLowStock => currentQuantity <= minimumQuantity;
  bool get isOutOfStock => currentQuantity <= 0;

  @override
  List<Object?> get props => [id, farmId, name, category];
}

class StockMovement extends Equatable {
  final String id;
  final String stockItemId;
  final StockMovementType type;
  final double quantity;
  final double? unitPrice;
  final double? totalCost;
  final String? reason;
  final String? supplier;
  final DateTime date;
  final String? notes;

  const StockMovement({
    required this.id,
    required this.stockItemId,
    required this.type,
    required this.quantity,
    this.unitPrice,
    this.totalCost,
    this.reason,
    this.supplier,
    required this.date,
    this.notes,
  });

  String get typeLabel =>
      type == StockMovementType.incoming ? 'Giriş' : 'Çıkış';

  @override
  List<Object?> get props => [id, stockItemId, date];
}
