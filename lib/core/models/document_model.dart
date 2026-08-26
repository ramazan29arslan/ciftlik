import 'package:cloud_firestore/cloud_firestore.dart';

enum EntityType { vehicle, building, animal, field }

enum DocType {
  muayene,
  trafikSigortasi,
  kasko,
  depremSigortasi,
  yanginSigortasi,
  yapiRuhsati,
  iskan,
  tapu,
  vekaletname,
  sozlesme,
  veterinerRaporu,
  saglikSertifikasi,
  pasaport,
  diger,
}

extension DocTypeLabel on DocType {
  String get label {
    switch (this) {
      case DocType.muayene: return 'Muayene';
      case DocType.trafikSigortasi: return 'Trafik Sigortası';
      case DocType.kasko: return 'Kasko';
      case DocType.depremSigortasi: return 'Deprem Sigortası';
      case DocType.yanginSigortasi: return 'Yangın Sigortası';
      case DocType.yapiRuhsati: return 'Yapı Ruhsatı';
      case DocType.iskan: return 'İskan';
      case DocType.tapu: return 'Tapu';
      case DocType.vekaletname: return 'Vekaletname';
      case DocType.sozlesme: return 'Sözleşme';
      case DocType.veterinerRaporu: return 'Veteriner Raporu';
      case DocType.saglikSertifikasi: return 'Sağlık Sertifikası';
      case DocType.pasaport: return 'Pasaport';
      case DocType.diger: return 'Diğer';
    }
  }
}

extension EntityTypeLabel on EntityType {
  String get label {
    switch (this) {
      case EntityType.vehicle: return 'Araç';
      case EntityType.building: return 'Yapı';
      case EntityType.animal: return 'Hayvan';
      case EntityType.field: return 'Tarla';
    }
  }
}

DateTime _parseDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.parse(v);
  return DateTime.now();
}

class EntityDocument {
  final String id;
  final String farmId;
  final String entityId;
  final EntityType entityType;
  final String entityName;
  final String title;
  final DocType docType;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final String? notes;
  final String? fileUrl;   // Firebase Storage download URL
  final String? fileName;  // original filename
  final DateTime createdAt;
  final DateTime updatedAt;

  const EntityDocument({
    required this.id,
    required this.farmId,
    required this.entityId,
    required this.entityType,
    required this.entityName,
    required this.title,
    required this.docType,
    this.issueDate,
    this.expiryDate,
    this.notes,
    this.fileUrl,
    this.fileName,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isExpired => expiryDate != null && expiryDate!.isBefore(DateTime.now());
  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final diff = expiryDate!.difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= 10;
  }
  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    return expiryDate!.difference(DateTime.now()).inDays;
  }
  bool get hasPdf => fileUrl != null && (fileName?.toLowerCase().endsWith('.pdf') ?? false);

  factory EntityDocument.fromFirestore(Map<String, dynamic> data, String id) {
    return EntityDocument(
      id: id,
      farmId: data['farmId'] as String? ?? '',
      entityId: data['entityId'] as String? ?? '',
      entityType: EntityType.values.firstWhere(
        (e) => e.name == (data['entityType'] as String? ?? ''),
        orElse: () => EntityType.vehicle,
      ),
      entityName: data['entityName'] as String? ?? '',
      title: data['title'] as String? ?? '',
      docType: DocType.values.firstWhere(
        (e) => e.name == (data['docType'] as String? ?? ''),
        orElse: () => DocType.diger,
      ),
      issueDate: data['issueDate'] != null ? _parseDate(data['issueDate']) : null,
      expiryDate: data['expiryDate'] != null ? _parseDate(data['expiryDate']) : null,
      notes: data['notes'] as String?,
      fileUrl: data['fileUrl'] as String?,
      fileName: data['fileName'] as String?,
      createdAt: _parseDate(data['createdAt'] ?? data['updatedAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: _parseDate(data['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
    'farmId': farmId,
    'entityId': entityId,
    'entityType': entityType.name,
    'entityName': entityName,
    'title': title,
    'docType': docType.name,
    'issueDate': issueDate?.toIso8601String(),
    'expiryDate': expiryDate?.toIso8601String(),
    'notes': notes,
    'fileUrl': fileUrl,
    'fileName': fileName,
  };

  EntityDocument copyWith({
    String? title,
    DocType? docType,
    DateTime? issueDate,
    DateTime? expiryDate,
    bool clearIssueDate = false,
    bool clearExpiryDate = false,
    String? notes,
    String? entityName,
    String? fileUrl,
    String? fileName,
    bool clearFile = false,
  }) => EntityDocument(
    id: id,
    farmId: farmId,
    entityId: entityId,
    entityType: entityType,
    entityName: entityName ?? this.entityName,
    title: title ?? this.title,
    docType: docType ?? this.docType,
    issueDate: clearIssueDate ? null : issueDate ?? this.issueDate,
    expiryDate: clearExpiryDate ? null : expiryDate ?? this.expiryDate,
    notes: notes ?? this.notes,
    fileUrl: clearFile ? null : fileUrl ?? this.fileUrl,
    fileName: clearFile ? null : fileName ?? this.fileName,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}
