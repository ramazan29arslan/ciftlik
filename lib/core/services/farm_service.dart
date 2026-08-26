import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/farm_models.dart';

class FarmService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Koleksiyon yolları ─────────────────────────────────
  DocumentReference _farmDoc(String farmId) =>
      _db.collection('farms').doc(farmId);
  CollectionReference _members(String farmId) =>
      _farmDoc(farmId).collection('members');

  // ── Çiftlik oluştur ────────────────────────────────────
  Future<String> createFarm({
    required String name,
    required String ownerId,
    required String ownerEmail,
    required String ownerName,
  }) async {
    final farmRef = _db.collection('farms').doc();
    final farmId = farmRef.id;
    final batch = _db.batch();

    batch.set(farmRef, {
      'name': name.trim(),
      'ownerId': ownerId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(_members(farmId).doc(ownerId), {
      'role': FarmRole.owner.name,
      'displayName': ownerName,
      'email': ownerEmail,
      'joinedAt': FieldValue.serverTimestamp(),
      'addedBy': ownerId,
    });

    batch.set(
      _db.collection('userProfiles').doc(ownerId),
      {
        'activeFarmId': farmId,
        'farmIds': FieldValue.arrayUnion([farmId]),
        'displayName': ownerName,
        'email': ownerEmail,
      },
      SetOptions(merge: true),
    );

    await batch.commit();
    return farmId;
  }

  // ── Davet kodu oluştur ─────────────────────────────────
  Future<String> createInviteCode({
    required String farmId,
    required String farmName,
    required String createdBy,
    FarmRole role = FarmRole.member,
    int? maxUses,
    DateTime? expiresAt,
  }) async {
    final code = _generateCode();
    await _db.collection('farmInvites').doc(code).set({
      'farmId': farmId,
      'farmName': farmName,
      'createdBy': createdBy,
      'role': role.name,
      'usedCount': 0,
      'maxUses': maxUses,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  // ── Davet kodu ile katıl ───────────────────────────────
  Future<void> joinWithCode({
    required String code,
    required String userId,
    required String userEmail,
    required String displayName,
  }) async {
    final inviteDoc = await _db.collection('farmInvites').doc(code.trim().toUpperCase()).get();
    if (!inviteDoc.exists) throw Exception('Geçersiz davet kodu');

    final invite = FarmInvite.fromFirestore(inviteDoc.data()!, inviteDoc.id);
    if (!invite.isActive) throw Exception('Bu davet kodu artık geçerli değil');

    // Kullanıcının zaten üyesi olup olmadığını kontrol et
    final memberDoc = await _members(invite.farmId).doc(userId).get();
    if (memberDoc.exists) throw Exception('Bu çiftliğe zaten üyesiniz');

    // Kullanıcının kaç çiftliği var?
    final profileDoc = await _db.collection('userProfiles').doc(userId).get();
    final farmIds = List<String>.from(profileDoc.data()?['farmIds'] ?? []);

    if (farmIds.isNotEmpty) {
      // Birden fazla çiftlik → süper admin onayı gerekli
      await _db.collection('multiFarmRequests').add({
        'userId': userId,
        'userEmail': userEmail,
        'userName': displayName,
        'farmId': invite.farmId,
        'farmName': invite.farmName,
        'inviteCode': code.trim().toUpperCase(),
        'role': invite.role.name,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });
      throw MultiFarmRequestedException(
        'Birden fazla çiftliğe katılmak için admin onayı bekleniyor. '
        'Onaylandığında bildirim alacaksınız.',
      );
    }

    await _addUserToFarm(
      farmId: invite.farmId,
      userId: userId,
      userEmail: userEmail,
      displayName: displayName,
      role: invite.role,
      addedBy: invite.createdBy,
      makeActive: true,
    );

    await inviteDoc.reference.update({'usedCount': FieldValue.increment(1)});
  }

  // ── Üye ekle (doğrudan — onay sonrası kullanılır) ──────
  Future<void> _addUserToFarm({
    required String farmId,
    required String userId,
    required String userEmail,
    required String displayName,
    required FarmRole role,
    required String addedBy,
    bool makeActive = false,
  }) async {
    final batch = _db.batch();

    batch.set(_members(farmId).doc(userId), {
      'role': role.name,
      'displayName': displayName,
      'email': userEmail,
      'joinedAt': FieldValue.serverTimestamp(),
      'addedBy': addedBy,
    });

    final profileUpdate = <String, dynamic>{
      'farmIds': FieldValue.arrayUnion([farmId]),
      'displayName': displayName,
      'email': userEmail,
    };
    if (makeActive) profileUpdate['activeFarmId'] = farmId;

    batch.set(
      _db.collection('userProfiles').doc(userId),
      profileUpdate,
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  // ── Süper admin: isteği onayla ─────────────────────────
  Future<void> approveMultiFarmRequest(String requestId) async {
    final reqDoc = await _db.collection('multiFarmRequests').doc(requestId).get();
    if (!reqDoc.exists) throw Exception('İstek bulunamadı');

    final req = MultiFarmRequest.fromFirestore(reqDoc.data()!, reqDoc.id);
    if (req.status != 'pending') throw Exception('Bu istek zaten işlenmiş');

    await _addUserToFarm(
      farmId: req.farmId,
      userId: req.userId,
      userEmail: req.userEmail,
      displayName: req.userName,
      role: req.role,
      addedBy: 'superAdmin',
      makeActive: false,
    );

    if (req.inviteCode != null) {
      await _db
          .collection('farmInvites')
          .doc(req.inviteCode)
          .update({'usedCount': FieldValue.increment(1)});
    }

    await reqDoc.reference.update({
      'status': 'approved',
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Süper admin: isteği reddet ─────────────────────────
  Future<void> rejectMultiFarmRequest(String requestId) async {
    await _db.collection('multiFarmRequests').doc(requestId).update({
      'status': 'rejected',
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Üye rolünü değiştir ────────────────────────────────
  Future<void> updateMemberRole(String farmId, String userId, FarmRole role) async {
    await _members(farmId).doc(userId).update({'role': role.name});
  }

  // ── Üyeyi çıkar ───────────────────────────────────────
  Future<void> removeMember(String farmId, String userId) async {
    final batch = _db.batch();
    batch.delete(_members(farmId).doc(userId));
    batch.set(
      _db.collection('userProfiles').doc(userId),
      {'farmIds': FieldValue.arrayRemove([farmId])},
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  // ── Çiftlikten ayrıl (kendi isteğiyle) ────────────────
  Future<void> leaveFarm(String userId, String farmId) async {
    final batch = _db.batch();
    batch.delete(_members(farmId).doc(userId));
    batch.set(
      _db.collection('userProfiles').doc(userId),
      {
        'farmIds': FieldValue.arrayRemove([farmId]),
        'activeFarmId': FieldValue.delete(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  // ── Aktif çiftliği değiştir ────────────────────────────
  Future<void> setActiveFarm(String userId, String farmId) async {
    await _db.collection('userProfiles').doc(userId).update({'activeFarmId': farmId});
  }

  // ── Çiftliği tamamen sil (sadece sahip) ───────────────
  Future<void> deleteFarm(String farmId, String ownerId) async {
    // 1. Tüm üyeleri getir ve profillerini güncelle
    final membersSnap = await _members(farmId).get();
    final memberIds = membersSnap.docs.map((d) => d.id).toList();

    // Her üyenin profilinden bu çiftliği kaldır
    for (final memberId in memberIds) {
      await _db.collection('userProfiles').doc(memberId).set(
        {
          'farmIds': FieldValue.arrayRemove([farmId]),
          'activeFarmId': FieldValue.delete(),
        },
        SetOptions(merge: true),
      );
    }

    // 2. Tüm üye dökümanlarını sil
    final memberBatch = _db.batch();
    for (final doc in membersSnap.docs) {
      memberBatch.delete(doc.reference);
    }
    await memberBatch.commit();

    // 3. Bu çiftliğe ait davet kodlarını iptal et
    final invitesSnap = await _db
        .collection('farmInvites')
        .where('farmId', isEqualTo: farmId)
        .get();
    if (invitesSnap.docs.isNotEmpty) {
      final inviteBatch = _db.batch();
      for (final doc in invitesSnap.docs) {
        inviteBatch.delete(doc.reference);
      }
      await inviteBatch.commit();
    }

    // 4. Çiftlik dökümanını sil
    await _farmDoc(farmId).delete();
  }

  // ── Davet kodunu iptal et ──────────────────────────────
  Future<void> deactivateInvite(String code) async {
    await _db.collection('farmInvites').doc(code).update({'status': 'expired'});
  }

  // ── Çiftlik adını güncelle ─────────────────────────────
  Future<void> renameFarm(String farmId, String newName) async {
    await _farmDoc(farmId).update({'name': newName.trim()});
    // Davet kodlarındaki farmName'i de güncelle
    final invitesSnap = await _db
        .collection('farmInvites')
        .where('farmId', isEqualTo: farmId)
        .where('status', isEqualTo: 'active')
        .get();
    if (invitesSnap.docs.isNotEmpty) {
      final batch = _db.batch();
      for (final doc in invitesSnap.docs) {
        batch.update(doc.reference, {'farmName': newName.trim()});
      }
      await batch.commit();
    }
  }

  // ── Streamler ──────────────────────────────────────────
  Stream<UserProfile?> userProfileStream(String userId) {
    return _db.collection('userProfiles').doc(userId).snapshots().map(
      (snap) => snap.exists ? UserProfile.fromFirestore(snap.data()!, snap.id) : null,
    );
  }

  // Silme / geçiş sırasında izin hatalarını sessizce null'a çevir
  Stream<FarmInfo?> farmStream(String farmId) async* {
    try {
      await for (final snap in _farmDoc(farmId).snapshots()) {
        yield snap.exists
            ? FarmInfo.fromFirestore(snap.data()! as Map<String, dynamic>, snap.id)
            : null;
      }
    } catch (_) {
      yield null;
    }
  }

  Stream<List<FarmMember>> farmMembersStream(String farmId) async* {
    try {
      await for (final snap in _members(farmId).snapshots()) {
        yield snap.docs
            .map((d) => FarmMember.fromFirestore(d.data() as Map<String, dynamic>, d.id))
            .toList();
      }
    } catch (_) {
      yield <FarmMember>[];
    }
  }

  Stream<List<FarmInvite>> farmInvitesStream(String farmId) async* {
    try {
      await for (final snap in _db
          .collection('farmInvites')
          .where('farmId', isEqualTo: farmId)
          .where('status', isEqualTo: 'active')
          .snapshots()) {
        yield snap.docs.map((d) => FarmInvite.fromFirestore(d.data(), d.id)).toList();
      }
    } catch (_) {
      yield <FarmInvite>[];
    }
  }

  Stream<List<MultiFarmRequest>> pendingRequestsStream() {
    return _db
        .collection('multiFarmRequests')
        .where('status', isEqualTo: 'pending')
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => MultiFarmRequest.fromFirestore(d.data(), d.id))
            .toList());
  }

  Future<List<FarmInfo>> getUserFarms(List<String> farmIds) async {
    if (farmIds.isEmpty) return [];
    final docs = await Future.wait(
      farmIds.map((id) => _farmDoc(id).get()),
    );
    return docs
        .where((d) => d.exists)
        .map((d) => FarmInfo.fromFirestore(d.data()! as Map<String, dynamic>, d.id))
        .toList();
  }

  // ── Yardımcı ───────────────────────────────────────────
  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
