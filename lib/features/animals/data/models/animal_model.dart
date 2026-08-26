import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/animal.dart';

DateTime _parseDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.parse(value);
  return DateTime.now();
}

class AnimalModel extends Animal {
  const AnimalModel({
    required super.id,
    required super.farmId,
    required super.tagNumber,
    super.name,
    required super.type,
    super.breed,
    super.birthDate,
    super.gender,
    super.status,
    super.motherId,
    super.fatherId,
    super.photoUrl,
    super.weight,
    super.notes,
    super.inseminationType,
    super.inseminationDate,
    super.inseminationMateId,
    super.inseminationVet,
    super.semenBrand,
    super.otherMateName,
    super.otherMateAge,
    super.otherMateOwner,
    super.buyerEmail,
    super.saleDate,
    required super.createdAt,
    required super.updatedAt,
  });

  factory AnimalModel.fromFirestore(Map<String, dynamic> data, String id) {
    return AnimalModel.fromJson({...data, 'id': id});
  }

  factory AnimalModel.fromJson(Map<String, dynamic> json) {
    return AnimalModel(
      id: json['id'] as String? ?? '',
      farmId: (json['farmId'] ?? json['farm_id'] ?? '') as String,
      tagNumber: (json['tagNumber'] ?? json['tag_number']) as String,
      name: json['name'] as String?,
      type: json['type'] as String,
      breed: json['breed'] as String?,
      birthDate: json['birthDate'] != null
          ? _parseDate(json['birthDate'])
          : json['birth_date'] != null
              ? _parseDate(json['birth_date'])
              : null,
      gender: json['gender'] != null
          ? AnimalGender.values.firstWhere(
              (e) => e.name == json['gender'],
              orElse: () => AnimalGender.female,
            )
          : null,
      status: AnimalStatus.values.firstWhere(
        (e) => e.name == (json['status'] ?? 'active'),
        orElse: () => AnimalStatus.active,
      ),
      motherId: (json['motherId'] ?? json['mother_id']) as String?,
      fatherId: (json['fatherId'] ?? json['father_id']) as String?,
      photoUrl: (json['photoUrl'] ?? json['photo_url']) as String?,
      weight: (json['weight'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      inseminationType: json['inseminationType'] != null
          ? InseminationType.values.firstWhere(
              (e) => e.name == json['inseminationType'],
              orElse: () => InseminationType.artificial,
            )
          : null,
      inseminationDate: json['inseminationDate'] != null
          ? _parseDate(json['inseminationDate'])
          : null,
      inseminationMateId: json['inseminationMateId'] as String?,
      inseminationVet: json['inseminationVet'] as String?,
      semenBrand: json['semenBrand'] as String?,
      otherMateName: json['otherMateName'] as String?,
      otherMateAge: json['otherMateAge'] as String?,
      otherMateOwner: json['otherMateOwner'] as String?,
      buyerEmail: json['buyerEmail'] as String?,
      saleDate: json['saleDate'] != null ? _parseDate(json['saleDate']) : null,
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'farmId': farmId,
      'tagNumber': tagNumber,
      'name': name,
      'type': type,
      'breed': breed,
      'birthDate': birthDate?.toIso8601String(),
      'gender': gender?.name,
      'status': status.name,
      'motherId': motherId,
      'fatherId': fatherId,
      'photoUrl': photoUrl,
      'weight': weight,
      'notes': notes,
      'inseminationType': inseminationType?.name,
      'inseminationDate': inseminationDate?.toIso8601String(),
      'inseminationMateId': inseminationMateId,
      'inseminationVet': inseminationVet,
      'semenBrand': semenBrand,
      'otherMateName': otherMateName,
      'otherMateAge': otherMateAge,
      'otherMateOwner': otherMateOwner,
      'buyerEmail': buyerEmail,
      'saleDate': saleDate?.toIso8601String(),
    };
  }

  AnimalModel copyWith({
    String? id,
    String? farmId,
    String? tagNumber,
    String? name,
    String? type,
    String? breed,
    DateTime? birthDate,
    AnimalGender? gender,
    AnimalStatus? status,
    String? motherId,
    String? fatherId,
    String? photoUrl,
    double? weight,
    String? notes,
    InseminationType? inseminationType,
    DateTime? inseminationDate,
    String? inseminationMateId,
    String? inseminationVet,
    String? semenBrand,
    String? otherMateName,
    String? otherMateAge,
    String? otherMateOwner,
    String? buyerEmail,
    DateTime? saleDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    // clearXxx flags for nullable fields
    bool clearMotherId = false,
    bool clearFatherId = false,
    bool clearInsemination = false,
    bool clearNotes = false,
    bool clearBuyerEmail = false,
    bool clearSaleDate = false,
  }) {
    return AnimalModel(
      id: id ?? this.id,
      farmId: farmId ?? this.farmId,
      tagNumber: tagNumber ?? this.tagNumber,
      name: name ?? this.name,
      type: type ?? this.type,
      breed: breed ?? this.breed,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      status: status ?? this.status,
      motherId: clearMotherId ? null : (motherId ?? this.motherId),
      fatherId: clearFatherId ? null : (fatherId ?? this.fatherId),
      photoUrl: photoUrl ?? this.photoUrl,
      weight: weight ?? this.weight,
      notes: clearNotes ? null : (notes ?? this.notes),
      buyerEmail: clearBuyerEmail ? null : (buyerEmail ?? this.buyerEmail),
      saleDate: clearSaleDate ? null : (saleDate ?? this.saleDate),
      inseminationType: clearInsemination ? null : (inseminationType ?? this.inseminationType),
      inseminationDate: clearInsemination ? null : (inseminationDate ?? this.inseminationDate),
      inseminationMateId: clearInsemination ? null : (inseminationMateId ?? this.inseminationMateId),
      inseminationVet: clearInsemination ? null : (inseminationVet ?? this.inseminationVet),
      semenBrand: clearInsemination ? null : (semenBrand ?? this.semenBrand),
      otherMateName: clearInsemination ? null : (otherMateName ?? this.otherMateName),
      otherMateAge: clearInsemination ? null : (otherMateAge ?? this.otherMateAge),
      otherMateOwner: clearInsemination ? null : (otherMateOwner ?? this.otherMateOwner),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AnimalVaccinationModel extends AnimalVaccination {
  const AnimalVaccinationModel({
    required super.id,
    required super.animalId,
    required super.vaccineName,
    required super.vaccinationDate,
    super.nextVaccinationDate,
    super.veterinarian,
    super.notes,
    super.cost,
  });

  factory AnimalVaccinationModel.fromJson(Map<String, dynamic> json) {
    return AnimalVaccinationModel(
      id: json['id'] as String? ?? '',
      animalId: (json['animalId'] ?? json['animal_id']) as String,
      vaccineName: (json['vaccineName'] ?? json['vaccine_name']) as String,
      vaccinationDate:
          _parseDate(json['vaccinationDate'] ?? json['vaccination_date']),
      nextVaccinationDate: json['nextVaccinationDate'] != null
          ? _parseDate(json['nextVaccinationDate'])
          : json['next_vaccination_date'] != null
              ? _parseDate(json['next_vaccination_date'])
              : null,
      veterinarian: json['veterinarian'] as String?,
      notes: json['notes'] as String?,
      cost: (json['cost'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'animalId': animalId,
        'vaccineName': vaccineName,
        'vaccinationDate': vaccinationDate.toIso8601String(),
        'nextVaccinationDate': nextVaccinationDate?.toIso8601String(),
        'veterinarian': veterinarian,
        'notes': notes,
        'cost': cost,
      };

  AnimalVaccinationModel copyWith({
    String? vaccineName,
    DateTime? vaccinationDate,
    DateTime? nextVaccinationDate,
    String? veterinarian,
    String? notes,
    double? cost,
    bool clearNextDate = false,
    bool clearVeterinarian = false,
    bool clearCost = false,
  }) => AnimalVaccinationModel(
    id: id, animalId: animalId,
    vaccineName: vaccineName ?? this.vaccineName,
    vaccinationDate: vaccinationDate ?? this.vaccinationDate,
    nextVaccinationDate: clearNextDate ? null : (nextVaccinationDate ?? this.nextVaccinationDate),
    veterinarian: clearVeterinarian ? null : (veterinarian ?? this.veterinarian),
    notes: notes ?? this.notes,
    cost: clearCost ? null : (cost ?? this.cost),
  );
}

class MilkRecordModel extends MilkRecord {
  const MilkRecordModel({
    required super.id,
    required super.animalId,
    required super.date,
    required super.morningAmount,
    required super.eveningAmount,
    super.notes,
  });

  factory MilkRecordModel.fromJson(Map<String, dynamic> json) {
    return MilkRecordModel(
      id: json['id'] as String? ?? '',
      animalId: (json['animalId'] ?? json['animal_id']) as String,
      date: _parseDate(json['date']),
      morningAmount:
          ((json['morningAmount'] ?? json['morning_amount']) as num).toDouble(),
      eveningAmount:
          ((json['eveningAmount'] ?? json['evening_amount']) as num).toDouble(),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'animalId': animalId,
        'date': date.toIso8601String(),
        'morningAmount': morningAmount,
        'eveningAmount': eveningAmount,
        'notes': notes,
      };

  MilkRecordModel copyWith({
    DateTime? date,
    double? morningAmount,
    double? eveningAmount,
    String? notes,
  }) => MilkRecordModel(
    id: id, animalId: animalId,
    date: date ?? this.date,
    morningAmount: morningAmount ?? this.morningAmount,
    eveningAmount: eveningAmount ?? this.eveningAmount,
    notes: notes ?? this.notes,
  );
}
