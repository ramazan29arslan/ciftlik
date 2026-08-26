import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/app_announcement.dart';

final appAnnouncementsProvider = StreamProvider<List<AppAnnouncement>>((ref) {
  return FirebaseFirestore.instance
      .collection('app_announcements')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .handleError((_) {/* permission-denied veya diğer Firestore hatalarını yoksay */})
      .map((snap) => snap.docs
          .map((d) => AppAnnouncement.fromFirestore(
              Map<String, dynamic>.from(d.data()), d.id))
          .toList());
});

final announcementsLastSeenProvider = StateProvider<DateTime?>((ref) => null);

final unreadAnnouncementsCountProvider = Provider<int>((ref) {
  final announcements = ref.watch(appAnnouncementsProvider).value ?? [];
  final lastSeen = ref.watch(announcementsLastSeenProvider);
  if (lastSeen == null) return announcements.length;
  return announcements
      .where((a) => a.createdAt.isAfter(lastSeen))
      .length;
});

Future<void> loadAnnouncementsLastSeen(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString('announcements_last_seen');
  if (stored != null) {
    ref.read(announcementsLastSeenProvider.notifier).state =
        DateTime.tryParse(stored);
  }
}

Future<void> markAnnouncementsAsSeen(WidgetRef ref) async {
  final now = DateTime.now();
  ref.read(announcementsLastSeenProvider.notifier).state = now;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('announcements_last_seen', now.toIso8601String());
}
