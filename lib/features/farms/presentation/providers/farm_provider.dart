import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/farm_models.dart';
import '../../../../core/services/farm_service.dart';
import '../../../../core/services/activity_log_service.dart';
import '../../../../core/di/providers.dart';

final farmServiceProvider = Provider<FarmService>((ref) => FarmService());

// ── Kullanıcı profili (Firestore'dan stream) ───────────
final userProfileStreamProvider = StreamProvider<UserProfile?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();
  return ref.watch(farmServiceProvider).userProfileStream(userId);
});

// ── Aktif çiftlik ID'si ────────────────────────────────
// activeFarmId varsa onu, yoksa kişisel veri alanı olarak userId'yi kullan
final activeFarmIdProvider = Provider<String?>((ref) {
  final profile = ref.watch(userProfileStreamProvider).value;
  final userId = ref.watch(currentUserIdProvider);
  return profile?.activeFarmId ?? userId;
});

// ── Süper admin mi? ────────────────────────────────────
final isSuperAdminProvider = Provider<bool>((ref) {
  return ref.watch(userProfileStreamProvider).value?.isSuperAdmin ?? false;
});

// ── Aktif çiftlik bilgisi ──────────────────────────────
// NOT: activeFarmIdProvider bazen userId döndürür (kişisel mod).
// Gerçek farm dökümanı sadece activeFarmId varsa okunur.
// Yoksa Stream.value(null) → no-farm view gösterilir, hata olmaz.
final activeFarmProvider = StreamProvider<FarmInfo?>((ref) {
  final profile = ref.watch(userProfileStreamProvider).value;
  final farmId = profile?.activeFarmId; // null → çiftlik yok
  if (farmId == null) return Stream.value(null);
  return ref.watch(farmServiceProvider).farmStream(farmId);
});

// ── Kullanıcının tüm çiftlikleri ──────────────────────
final userFarmsProvider = FutureProvider<List<FarmInfo>>((ref) {
  final profile = ref.watch(userProfileStreamProvider).value;
  if (profile == null || profile.farmIds.isEmpty) return Future.value([]);
  return ref.watch(farmServiceProvider).getUserFarms(profile.farmIds);
});

// ── Aktif çiftliğin üyeleri ────────────────────────────
final farmMembersProvider = StreamProvider<List<FarmMember>>((ref) {
  final farmId = ref.watch(activeFarmIdProvider);
  if (farmId == null) return const Stream.empty();
  return ref.watch(farmServiceProvider).farmMembersStream(farmId);
});

// ── Aktif çiftliğin davet kodları ─────────────────────
final farmInvitesProvider = StreamProvider<List<FarmInvite>>((ref) {
  final farmId = ref.watch(activeFarmIdProvider);
  if (farmId == null) return const Stream.empty();
  return ref.watch(farmServiceProvider).farmInvitesStream(farmId);
});

// ── Bekleyen çok-çiftlik istekleri (sadece süper admin) ─
final pendingRequestsProvider = StreamProvider<List<MultiFarmRequest>>((ref) {
  final isAdmin = ref.watch(isSuperAdminProvider);
  if (!isAdmin) return const Stream.empty();
  return ref.watch(farmServiceProvider).pendingRequestsStream();
});

// ── Mevcut kullanıcının aktif çiftlikteki rolü ─────────
final myFarmRoleProvider = Provider<FarmRole?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final members = ref.watch(farmMembersProvider).value ?? [];
  try {
    return members.firstWhere((m) => m.userId == userId).role;
  } catch (_) {
    return null;
  }
});

// ── Aktivite Log Servisi ───────────────────────────────
final activityLogServiceProvider = Provider<ActivityLogService>((ref) {
  final farmId = ref.watch(activeFarmIdProvider) ?? '';
  final user = ref.watch(currentUserProvider);
  return ActivityLogService(
    farmId: farmId,
    userId: user?.uid ?? '',
    userName: user?.displayName ?? user?.email ?? 'Kullanıcı',
  );
});
