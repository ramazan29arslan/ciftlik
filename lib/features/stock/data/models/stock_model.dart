import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/stock_item.dart';

DateTime _parseDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.parse(v);
  return DateTime.now();
}

class StockItemModel extends StockItem {
  const StockItemModel({
    required super.id,
    required super.farmId,
    required super.name,
    required super.category,
    required super.unit,
    required super.currentQuantity,
    required super.minimumQuantity,
    super.unitPrice,
    super.supplier,
    super.notes,
    required super.createdAt,
    required super.updatedAt,
  });

  factory StockItemModel.fromFirestore(Map<String, dynamic> json, String id) {
    return StockItemModel(
      id: id,
      farmId: (json['farmId'] ?? json['farm_id'] ?? '') as String,
      name: json['name'] as String,
      category: json['category'] as String,
      unit: json['unit'] as String,
      currentQuantity: ((json['currentQuantity'] ?? json['current_quantity']) as num).toDouble(),
      minimumQuantity: ((json['minimumQuantity'] ?? json['minimum_quantity']) as num).toDouble(),
      unitPrice: ((json['unitPrice'] ?? json['unit_price']) as num?)?.toDouble(),
      supplier: json['supplier'] as String?,
      notes: json['notes'] as String?,
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'farmId': farmId,
        'name': name,
        'category': category,
        'unit': unit,
        'currentQuantity': currentQuantity,
        'minimumQuantity': minimumQuantity,
        'unitPrice': unitPrice,
        'supplier': supplier,
        'notes': notes,
      };

  StockItemModel copyWith({
    String? id, String? farmId, String? name, String? category,
    String? unit, double? currentQuantity, double? minimumQuantity,
    double? unitPrice, String? supplier, String? notes,
    DateTime? createdAt, DateTime? updatedAt,
  }) => StockItemModel(
    id: id ?? this.id, farmId: farmId ?? this.farmId,
    name: name ?? this.name, category: category ?? this.category,
    unit: unit ?? this.unit,
    currentQuantity: currentQuantity ?? this.currentQuantity,
    minimumQuantity: minimumQuantity ?? this.minimumQuantity,
    unitPrice: unitPrice ?? this.unitPrice,
    supplier: supplier ?? this.supplier, notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? this.updatedAt,
  );
}

class StockMovementModel extends StockMovement {
  const StockMovementModel({
    required super.id,
    required super.stockItemId,
    required super.type,
    required super.quantity,
    super.unitPrice,
    super.totalCost,
    super.reason,
    super.supplier,
    required super.date,
    super.notes,
  });

  factory StockMovementModel.fromFirestore(Map<String, dynamic> json, String id) {
    return StockMovementModel(
      id: id,
      stockItemId: (json['stockItemId'] ?? json['stock_item_id']) as String,
      type: StockMovementType.values.firstWhere(
        (e) => e.name == (json['type'] ?? 'incoming'),
        orElse: () => StockMovementType.incoming,
      ),
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: ((json['unitPrice'] ?? json['unit_price']) as num?)?.toDouble(),
      totalCost: ((json['totalCost'] ?? json['total_cost']) as num?)?.toDouble(),
      reason: json['reason'] as String?,
      supplier: json['supplier'] as String?,
      date: _parseDate(json['date']),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'stockItemId': stockItemId,
        'type': type.name,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'totalCost': totalCost,
        'reason': reason,
        'supplier': supplier,
        'date': date.toIso8601String(),
        'notes': notes,
      };
}
