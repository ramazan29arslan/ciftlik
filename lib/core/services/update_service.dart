import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// Yama notları — Firestore'daki `appUpdates/{ios|android}` belgesinden gelir.
///
/// Notlar yamanın *içinde* olamaz: kullanıcıya indirmeden önce gösterildikleri
/// için ayrı bir kaynaktan okunmaları gerekir.
class PatchNotes {
  const PatchNotes({
    required this.patchNumber,
    required this.title,
    required this.notes,
  });

  /// Notların ait olduğu yama numarası. `shorebird patch` çıktısındaki
  /// "Published Patch N" sayısıyla aynı olmalı.
  final int patchNumber;

  final String title;
  final List<String> notes;

  static PatchNotes? fromMap(Map<String, dynamic>? data) {
    if (data == null) return null;
    final number = data['patchNumber'];
    if (number is! int) return null;
    return PatchNotes(
      patchNumber: number,
      title: data['title'] as String? ?? 'Yeni güncelleme',
      notes: (data['notes'] as List?)?.whereType<String>().toList() ?? const [],
    );
  }
}

class UpdateService {
  UpdateService({ShorebirdUpdater? updater, FirebaseFirestore? firestore})
      : _updater = updater ?? ShorebirdUpdater(),
        _db = firestore ?? FirebaseFirestore.instance;

  final ShorebirdUpdater _updater;
  final FirebaseFirestore _db;

  /// Debug derlemelerinde ve `shorebird release` ile üretilmemiş yapılarda
  /// false döner — o durumda güncelleme akışı hiç çalıştırılmaz.
  bool get isAvailable => _updater.isAvailable;

  Future<bool> hasUpdate() async {
    if (!_updater.isAvailable) return false;
    return await _updater.checkForUpdate() == UpdateStatus.outdated;
  }

  Future<PatchNotes?> fetchNotes() async {
    final platform = Platform.isIOS ? 'ios' : 'android';
    final doc = await _db.collection('appUpdates').doc(platform).get();
    return PatchNotes.fromMap(doc.data());
  }

  /// Yamayı indirir. İndirme bittiğinde yama *bir sonraki açılışta* devreye
  /// girer — bu çağrı çalışan uygulamayı değiştirmez.
  Future<void> download() => _updater.update();
}

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());
