import 'package:equatable/equatable.dart';

enum AnimalStatus { active, sold, dead, transferred }

enum AnimalGender { male, female }

enum InseminationType { artificial, natural }

// Gebelik süreleri (gün) - hayvan türüne göre
int gestationDays(String animalType) {
  switch (animalType) {
    case 'Sığır': return 283;
    case 'Manda': return 310;
    case 'Koyun': return 147;
    case 'Keçi': return 150;
    case 'At': return 337;
    case 'Domuz': return 115;
    case 'Deve': return 400;
    default: return 280;
  }
}

class Animal extends Equatable {
  final String id;
  final String farmId;
  final String tagNumber;
  final String? name;
  final String type;
  final String? breed;
  final DateTime? birthDate;
  final AnimalGender? gender;
  final AnimalStatus status;
  final String? motherId;
  final String? fatherId;
  final String? photoUrl;
  final double? weight;
  final String? notes;
  // Tohumlama
  final InseminationType? inseminationType;
  final DateTime? inseminationDate;
  final String? inseminationMateId;   // Doğal: erkek hayvan id veya '__other__'
  final String? inseminationVet;      // Suni: veteriner adı
  final String? semenBrand;           // Suni: tohumun markası/kodu
  final String? otherMateName;        // Doğal-Diğer: erkek hayvan adı
  final String? otherMateAge;         // Doğal-Diğer: erkek hayvan yaşı
  final String? otherMateOwner;       // Doğal-Diğer: sahibi
  final String? buyerEmail;    // Satış: alıcının e-posta adresi (opsiyonel)
  final DateTime? saleDate;    // Satış tarihi
  final DateTime createdAt;
  final DateTime updatedAt;

  const Animal({
    required this.id,
    required this.farmId,
    required this.tagNumber,
    this.name,
    required this.type,
    this.breed,
    this.birthDate,
    this.gender,
    this.status = AnimalStatus.active,
    this.motherId,
    this.fatherId,
    this.photoUrl,
    this.weight,
    this.notes,
    this.inseminationType,
    this.inseminationDate,
    this.inseminationMateId,
    this.inseminationVet,
    this.semenBrand,
    this.otherMateName,
    this.otherMateAge,
    this.otherMateOwner,
    this.buyerEmail,
    this.saleDate,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Tahmini doğum tarihi — tohumlama tarihine gebelik süresi eklenerek hesaplanır
  DateTime? get expectedBirthDate {
    if (inseminationDate == null) return null;
    return inseminationDate!.add(Duration(days: gestationDays(type)));
  }

  /// Dişi memeli mi? (tohumlama takibi yapılabilir)
  bool get isFemaleBreedingMammal =>
      gender == AnimalGender.female &&
      ['Sığır', 'Koyun', 'Keçi', 'At', 'Domuz', 'Manda', 'Deve'].contains(type);

  String get displayName => name ?? tagNumber;

  String get statusLabel {
    switch (status) {
      case AnimalStatus.active:
        return 'Aktif';
      case AnimalStatus.sold:
        return 'Satıldı';
      case AnimalStatus.dead:
        return 'Öldü';
      case AnimalStatus.transferred:
        return 'Satıldı';
    }
  }

  String get genderLabel {
    switch (gender) {
      case AnimalGender.male:
        return 'Erkek';
      case AnimalGender.female:
        return 'Dişi';
      case null:
        return '-';
    }
  }

  @override
  List<Object?> get props => [
        id, farmId, tagNumber, name, type, breed,
        birthDate, gender, status, motherId, fatherId,
        photoUrl, weight, notes,
        inseminationType, inseminationDate, inseminationMateId,
        inseminationVet, semenBrand,
        otherMateName, otherMateAge, otherMateOwner,
        buyerEmail, saleDate,
        createdAt, updatedAt,
      ];
}

class AnimalVaccination extends Equatable {
  final String id;
  final String animalId;
  final String vaccineName;
  final DateTime vaccinationDate;
  final DateTime? nextVaccinationDate;
  final String? veterinarian;
  final String? notes;
  final double? cost;

  const AnimalVaccination({
    required this.id,
    required this.animalId,
    required this.vaccineName,
    required this.vaccinationDate,
    this.nextVaccinationDate,
    this.veterinarian,
    this.notes,
    this.cost,
  });

  @override
  List<Object?> get props => [id, animalId, vaccineName, vaccinationDate];
}

class AnimalPregnancy extends Equatable {
  final String id;
  final String animalId;
  final DateTime matingDate;
  final DateTime? expectedBirthDate;
  final DateTime? actualBirthDate;
  final int? offspringCount;
  final String? notes;
  final bool isActive;

  const AnimalPregnancy({
    required this.id,
    required this.animalId,
    required this.matingDate,
    this.expectedBirthDate,
    this.actualBirthDate,
    this.offspringCount,
    this.notes,
    this.isActive = true,
  });

  @override
  List<Object?> get props => [id, animalId, matingDate];
}

class MilkRecord extends Equatable {
  final String id;
  final String animalId;
  final DateTime date;
  final double morningAmount;
  final double eveningAmount;
  final String? notes;

  const MilkRecord({
    required this.id,
    required this.animalId,
    required this.date,
    required this.morningAmount,
    required this.eveningAmount,
    this.notes,
  });

  double get totalAmount => morningAmount + eveningAmount;

  @override
  List<Object?> get props => [id, animalId, date];
}
