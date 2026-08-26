import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../animals/presentation/providers/animals_provider.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../../../vehicles/presentation/providers/vehicles_provider.dart';
import '../../domain/entities/app_notification.dart';
import '../../../documents/presentation/providers/documents_provider.dart';

// Gerçek veriden türetilen bildirimler — hardcode yok
final notificationsProvider = Provider<List<AppNotification>>((ref) {
  final now = DateTime.now();
  final notifications = <AppNotification>[];
  final today = DateTime(now.year, now.month, now.day);

  // ── Aşı hatırlatmaları (30 gün içinde) ──────────────────
  try {
    final vaccinations = ref.watch(vaccinationsNotifierProvider);
    final animals = ref.watch(animalsNotifierProvider);

    for (final v in vaccinations) {
      final next = v.nextVaccinationDate;
      if (next == null) continue;
      final nextDay = DateTime(next.year, next.month, next.day);
      final diff = nextDay.difference(today).inDays;
      if (diff < 0 || diff > 30) continue;

      final animal = animals.where((a) => a.id == v.animalId).firstOrNull;
      final animalLabel = animal?.name ?? animal?.tagNumber ?? v.animalId;

      notifications.add(AppNotification(
        id: 'vacc_${v.id}',
        farmId: v.animalId,
        title: diff == 0
            ? 'Bugün Aşı Zamanı'
            : diff <= 3
                ? '$diff gün içinde aşı'
                : 'Yaklaşan Aşı',
        body: diff == 0
            ? '$animalLabel — ${v.vaccineName} aşısı bugün yapılmalı'
            : '$animalLabel — ${v.vaccineName} aşısı $diff gün sonra',
        type: NotificationType.vaccination,
        priority: diff <= 3 ? NotificationPriority.high : NotificationPriority.medium,
        entityId: v.animalId,
        entityType: 'animal',
        scheduledAt: next,
        createdAt: next.subtract(const Duration(days: 30)),
      ));
    }

    // ── Yaklaşan doğumlar (15 gün içinde) ────────────────────
    for (final a in animals) {
      final expected = a.expectedBirthDate;
      if (expected == null) continue;
      final expDay = DateTime(expected.year, expected.month, expected.day);
      final diff = expDay.difference(today).inDays;
      if (diff < 0 || diff > 15) continue;

      notifications.add(AppNotification(
        id: 'birth_${a.id}',
        farmId: a.farmId,
        title: diff == 0 ? 'Bugün Doğum Bekleniyor!' : '$diff Gün İçinde Doğum',
        body: diff == 0
            ? '${a.name ?? a.tagNumber} bugün doğurması bekleniyor'
            : '${a.name ?? a.tagNumber} — tahmini doğum tarihi ${expected.day}.${expected.month}.${expected.year}',
        type: NotificationType.vaccination,
        priority: diff <= 3 ? NotificationPriority.critical : NotificationPriority.high,
        entityId: a.id,
        entityType: 'animal',
        scheduledAt: expected,
        createdAt: expected.subtract(const Duration(days: 15)),
      ));
    }
  } catch (_) { /* hayvan/aşı verisi henüz yüklenmemişse atla */ }

  // ── Düşük stok ───────────────────────────────────────────
  try {
    final lowStock = ref.watch(stockNotifierProvider).where((s) => s.isLowStock).toList();
    for (final item in lowStock) {
      notifications.add(AppNotification(
        id: 'stock_${item.id}',
        farmId: item.farmId,
        title: 'Düşük Stok',
        body: '${item.name}: ${item.currentQuantity.toStringAsFixed(1)} ${item.unit} kaldı (min: ${item.minimumQuantity.toStringAsFixed(1)} ${item.unit})',
        type: NotificationType.lowStock,
        priority: item.currentQuantity == 0
            ? NotificationPriority.critical
            : NotificationPriority.high,
        entityId: item.id,
        entityType: 'stock',
        scheduledAt: item.updatedAt,
        createdAt: item.updatedAt,
      ));
    }
  } catch (_) { /* stok verisi henüz yüklenmemişse atla */ }

  // ── Yaklaşan araç bakımı & arızalı araçlar ───────────────
  try {
    final maintenance = ref.watch(maintenanceNotifierProvider);
    final vehicles = ref.watch(vehiclesNotifierProvider);

    for (final m in maintenance) {
      final next = m.nextMaintenanceDate;
      if (next == null) continue;
      final nextDay = DateTime(next.year, next.month, next.day);
      final diff = nextDay.difference(today).inDays;
      if (diff < 0 || diff > 30) continue;

      final vehicle = vehicles.where((v) => v.id == m.vehicleId).firstOrNull;
      final vehicleLabel = vehicle?.plate ?? '${vehicle?.brand ?? ''} ${vehicle?.model ?? ''}'.trim();

      notifications.add(AppNotification(
        id: 'maint_${m.id}',
        farmId: m.vehicleId,   // vehicleId — navigasyon için saklanıyor
        title: diff == 0 ? 'Bakım Günü' : '$diff Gün İçinde Bakım',
        body: '$vehicleLabel — ${m.maintenanceType}',
        type: NotificationType.maintenance,
        priority: diff <= 3 ? NotificationPriority.high : NotificationPriority.medium,
        entityId: m.id,        // bakım kaydı ID'si
        entityType: 'maintenance',
        scheduledAt: next,
        createdAt: next.subtract(const Duration(days: 30)),
      ));
    }

    final brokenVehicles = vehicles.where((v) => v.status.name == 'broken').toList();
    for (final v in brokenVehicles) {
      final label = v.plate ?? '${v.brand} ${v.model}';
      notifications.add(AppNotification(
        id: 'broken_${v.id}',
        farmId: v.farmId,
        title: 'Arızalı Araç',
        body: '$label arızalı olarak işaretlendi',
        type: NotificationType.maintenance,
        priority: NotificationPriority.high,
        entityId: v.id,
        entityType: 'vehicle',
        scheduledAt: v.updatedAt,
        createdAt: v.updatedAt,
      ));
    }
  } catch (_) { /* araç/bakım verisi henüz yüklenmemişse atla */ }

  // ── Yaklaşan belge bitiş tarihleri (10 gün içinde) ───────
  try {
    final expiringDocs = ref.watch(expiringDocumentsProvider);
    for (final doc in expiringDocs) {
      final days = doc.daysUntilExpiry ?? 0;
      notifications.add(AppNotification(
        id: 'doc_${doc.id}',
        farmId: doc.farmId,
        title: days == 0 ? 'Belge Bugün Bitiyor' : '$days Gün İçinde Belge Bitiyor',
        body: '${doc.entityName} — ${doc.title}',
        type: NotificationType.insurance,
        priority: days <= 3 ? NotificationPriority.high : NotificationPriority.medium,
        entityId: doc.entityId,
        entityType: doc.entityType.name,
        scheduledAt: doc.expiryDate!,
        createdAt: doc.createdAt,
      ));
    }
  } catch (_) { /* belge verisi henüz yüklenmemişse atla */ }

  // En yeni önce sırala
  notifications.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
  return notifications;
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).where((n) => !n.isRead).length;
});
