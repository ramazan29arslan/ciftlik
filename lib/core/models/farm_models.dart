import 'package:cloud_firestore/cloud_firestore.dart';

enum FarmRole { owner, admin, member, viewer }

extension FarmRoleLabel on FarmRole {
  String get label {
    switch (this) {
      case FarmRole.owner: return 'Sahip';
      case FarmRole.admin: return 'Yönetici';
      case FarmRole.member: return 'Üye';
      case FarmRole.viewer: return 'Görüntüleyici';
    }
  }

  bool get canWrite => this != FarmRole.viewer;
  bool get canManageMembers => this == FarmRole.owner || this == FarmRole.admin;
}

class FarmInfo {
  final String id;
  final String name;
  final String ownerId;
  final DateTime createdAt;

  const FarmInfo({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.createdAt,
  });

  factory FarmInfo.fromFirestore(Map<String, dynamic> data, String id) {
    return FarmInfo(
      id: id,
      name: data['name'] as String,
      ownerId: data['ownerId'] as String,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class FarmMember {
  final String userId;
  final String displayName;
  final String email;
  final FarmRole role;
  final DateTime joinedAt;

  const FarmMember({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.role,
    required this.joinedAt,
  });

  factory FarmMember.fromFirestore(Map<String, dynamic> data, String userId) {
    return FarmMember(
      userId: userId,
      displayName: data['displayName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: FarmRole.values.firstWhere(
        (r) => r.name == (data['role'] ?? 'member'),
        orElse: () => FarmRole.member,
      ),
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class UserProfile {
  final String userId;
  final String? displayName;
  final String? email;
  final String? activeFarmId;
  final List<String> farmIds;
  final bool isSuperAdmin;

  const UserProfile({
    required this.userId,
    this.displayName,
    this.email,
    this.activeFarmId,
    this.farmIds = const [],
    this.isSuperAdmin = false,
  });

  factory UserProfile.fromFirestore(Map<String, dynamic> data, String userId) {
    return UserProfile(
      userId: userId,
      displayName: data['displayName'] as String?,
      email: data['email'] as String?,
      activeFarmId: data['activeFarmId'] as String?,
      farmIds: List<String>.from(data['farmIds'] ?? []),
      isSuperAdmin: data['isSuperAdmin'] as bool? ?? false,
    );
  }
}

class FarmInvite {
  final String code;
  final String farmId;
  final String farmName;
  final String createdBy;
  final FarmRole role;
  final int usedCount;
  final int? maxUses;
  final DateTime? expiresAt;
  final String status;
  final DateTime createdAt;

  const FarmInvite({
    required this.code,
    required this.farmId,
    required this.farmName,
    required this.createdBy,
    required this.role,
    required this.usedCount,
    this.maxUses,
    this.expiresAt,
    required this.status,
    required this.createdAt,
  });

  bool get isActive {
    if (status != 'active') return false;
    if (maxUses != null && usedCount >= maxUses!) return false;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return false;
    return true;
  }

  factory FarmInvite.fromFirestore(Map<String, dynamic> data, String code) {
    return FarmInvite(
      code: code,
      farmId: data['farmId'] as String,
      farmName: data['farmName'] as String? ?? '',
      createdBy: data['createdBy'] as String,
      role: FarmRole.values.firstWhere(
        (r) => r.name == (data['role'] ?? 'member'),
        orElse: () => FarmRole.member,
      ),
      usedCount: data['usedCount'] as int? ?? 0,
      maxUses: data['maxUses'] as int?,
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      status: data['status'] as String? ?? 'active',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class MultiFarmRequest {
  final String id;
  final String userId;
  final String userEmail;
  final String userName;
  final String farmId;
  final String farmName;
  final FarmRole role;
  final String status; // pending | approved | rejected
  final DateTime requestedAt;
  final String? inviteCode;

  const MultiFarmRequest({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.farmId,
    required this.farmName,
    required this.role,
    required this.status,
    required this.requestedAt,
    this.inviteCode,
  });

  factory MultiFarmRequest.fromFirestore(Map<String, dynamic> data, String id) {
    return MultiFarmRequest(
      id: id,
      userId: data['userId'] as String,
      userEmail: data['userEmail'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      farmId: data['farmId'] as String,
      farmName: data['farmName'] as String? ?? '',
      role: FarmRole.values.firstWhere(
        (r) => r.name == (data['role'] ?? 'member'),
        orElse: () => FarmRole.member,
      ),
      status: data['status'] as String? ?? 'pending',
      requestedAt: (data['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      inviteCode: data['inviteCode'] as String?,
    );
  }
}

class MultiFarmRequestedException implements Exception {
  final String message;
  const MultiFarmRequestedException(this.message);
  @override
  String toString() => message;
}
