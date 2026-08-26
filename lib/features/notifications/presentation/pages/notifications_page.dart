import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../domain/entities/app_notification.dart';
import '../providers/notifications_provider.dart';
import '../../../vehicles/presentation/pages/vehicle_detail_page.dart'
    show showMaintenanceCompleteSheet;
import '../../../vehicles/presentation/providers/vehicles_provider.dart'
    show vehiclesNotifierProvider, maintenanceNotifierProvider;

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final unreadCount = notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Bildirimler'),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
      body: notifications.isEmpty
          ? const AppEmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Bildirim yok',
              subtitle: 'Aşı, stok ve bakım hatırlatmaları burada görünür',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final n = notifications[index];
                return _NotificationCard(
                  notification: n,
                  onTap: () => _handleTap(context, ref, n),
                );
              },
            ),
    );
  }

  void _handleTap(BuildContext context, WidgetRef ref, AppNotification n) {
    if (n.entityType == 'maintenance' && n.entityId != null) {
      final records = ref.read(maintenanceNotifierProvider);
      final record = records.where((m) => m.id == n.entityId).firstOrNull;
      if (record != null) {
        final vehicles = ref.read(vehiclesNotifierProvider);
        final vehicle = vehicles.where((v) => v.id == record.vehicleId).firstOrNull;
        final label = vehicle?.plate ?? '${vehicle?.brand ?? ''} ${vehicle?.model ?? ''}'.trim();
        showMaintenanceCompleteSheet(context, ref, record, label);
      } else if (n.farmId != null) {
        context.push('${AppRoutes.vehicles}/detail/${n.farmId}');
      }
    } else if (n.entityType == 'animal' && n.entityId != null) {
      context.push('${AppRoutes.animals}/detail/${n.entityId}');
    } else if (n.entityType == 'vehicle' && n.entityId != null) {
      context.push('${AppRoutes.vehicles}/detail/${n.entityId}');
    } else if (n.entityType == 'stock' && n.entityId != null) {
      context.push('${AppRoutes.stock}/detail/${n.entityId}');
    }
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback? onTap;
  const _NotificationCard({required this.notification, this.onTap});

  Color get _typeColor {
    switch (notification.type) {
      case NotificationType.vaccination: return AppColors.warning;
      case NotificationType.insurance: return AppColors.info;
      case NotificationType.maintenance: return AppColors.secondary;
      case NotificationType.lowStock: return AppColors.error;
      case NotificationType.inspection: return AppColors.vehicleColor;
      case NotificationType.pregnancy: return AppColors.animalColor;
      case NotificationType.general: return AppColors.textSecondary;
    }
  }

  IconData get _typeIcon {
    switch (notification.type) {
      case NotificationType.vaccination: return Icons.vaccines_rounded;
      case NotificationType.insurance: return Icons.security_rounded;
      case NotificationType.maintenance: return Icons.build_rounded;
      case NotificationType.lowStock: return Icons.inventory_2_rounded;
      case NotificationType.inspection: return Icons.fact_check_rounded;
      case NotificationType.pregnancy: return Icons.child_care_rounded;
      case NotificationType.general: return Icons.notifications_rounded;
    }
  }

  Color get _priorityBadgeColor {
    switch (notification.priority) {
      case NotificationPriority.critical: return AppColors.error;
      case NotificationPriority.high: return AppColors.warning;
      case NotificationPriority.medium: return AppColors.info;
      case NotificationPriority.low: return AppColors.textTertiary;
    }
  }

  String get _priorityLabel {
    switch (notification.priority) {
      case NotificationPriority.critical: return 'Kritik';
      case NotificationPriority.high: return 'Yüksek';
      case NotificationPriority.medium: return 'Orta';
      case NotificationPriority.low: return 'Düşük';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_typeIcon, color: _typeColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _priorityBadgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _priorityLabel,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _priorityBadgeColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.body,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 6),
                Text(
                  AppDateUtils.formatRelative(notification.scheduledAt),
                  style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
