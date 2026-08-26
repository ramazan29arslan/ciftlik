import 'package:cloud_firestore/cloud_firestore.dart';

class AppAnnouncement {
  final String id;
  final String title;
  final String body;
  final String type; // 'update', 'fix', 'announcement'
  final String? version;
  final DateTime createdAt;

  const AppAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.version,
    required this.createdAt,
  });

  factory AppAnnouncement.fromFirestore(Map<String, dynamic> data, String id) {
    DateTime ts;
    final raw = data['createdAt'];
    if (raw is Timestamp) {
      ts = raw.toDate();
    } else if (raw is String) {
      ts = DateTime.tryParse(raw) ?? DateTime.now();
    } else {
      ts = DateTime.now();
    }
    return AppAnnouncement(
      id: id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      type: data['type'] as String? ?? 'announcement',
      version: data['version'] as String?,
      createdAt: ts,
    );
  }

  String get typeLabel {
    switch (type) {
      case 'update':
        return 'Güncelleme';
      case 'fix':
        return 'Düzeltme';
      default:
        return 'Duyuru';
    }
  }

  String get typeEmoji {
    switch (type) {
      case 'update':
        return '🚀';
      case 'fix':
        return '🔧';
      default:
        return '📢';
    }
  }
}
