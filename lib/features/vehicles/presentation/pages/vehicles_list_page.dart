import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_search_bar.dart';
import '../../domain/entities/vehicle.dart';
import '../providers/vehicles_provider.dart';
import '../../../../core/utils/vehicle_icon_helper.dart';

const _demoFarmId = 'demo';

class VehiclesListPage extends ConsumerWidget {
  const VehiclesListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehiclesProvider(_demoFarmId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Araç & Makineler')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/vehicles/add'),
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: AppSearchBar(hint: 'Araç ara...'),
          ),
          Expanded(
            child: vehicles.isEmpty
                ? AppEmptyState(
                    icon: Icons.agriculture_rounded,
                    title: 'Araç bulunamadı',
                    subtitle: 'Yeni araç eklemek için + butonuna dokunun',
                    actionLabel: 'Araç Ekle',
                    onAction: () => context.go('/vehicles/add'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: vehicles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final v = vehicles[index];
                      return _VehicleCard(
                        vehicle: v,
                        onTap: () => context.go('/vehicles/detail/${v.id}'),
                        onDelete: () => _confirmDelete(context, ref, v.id, v.displayName),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aracı Sil'),
        content: Text('$name silinecek. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          TextButton(
            onPressed: () {
              ref.read(vehiclesNotifierProvider.notifier).delete(id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$name silindi'), backgroundColor: AppColors.error),
              );
            },
            child: const Text('Sil', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final dynamic vehicle;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _VehicleCard({required this.vehicle, required this.onTap, required this.onDelete});

  Color get _statusColor {
    switch (vehicle.status as VehicleStatus) {
      case VehicleStatus.active: return AppColors.success;
      case VehicleStatus.maintenance: return AppColors.warning;
      case VehicleStatus.broken: return AppColors.error;
      case VehicleStatus.sold: return AppColors.info;
    }
  }

  IconData get _typeIcon => VehicleIconHelper.getTypeIcon(vehicle.type as String);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: AppColors.vehicleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(_typeIcon, color: AppColors.vehicleColor, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(vehicle.displayName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                    AppBadge(label: vehicle.statusLabel, color: _statusColor.withOpacity(0.12), textColor: _statusColor),
                  ],
                ),
                const SizedBox(height: 4),
                Text(vehicle.type, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (vehicle.plate != null) ...[
                      const Icon(Icons.credit_card_rounded, size: 12, color: AppColors.textTertiary),
                      const SizedBox(width: 3),
                      Text(vehicle.plate!, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                      const SizedBox(width: 10),
                    ],
                    if (vehicle.currentKm != null) ...[
                      const Icon(Icons.speed_rounded, size: 12, color: AppColors.textTertiary),
                      const SizedBox(width: 3),
                      Text('${vehicle.currentKm!.toStringAsFixed(0)} km', style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textTertiary, size: 20),
            onSelected: (v) {
              if (v == 'edit') context.go('/vehicles/edit/${vehicle.id}');
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 18), SizedBox(width: 8), Text('Düzenle')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, size: 18, color: AppColors.error), SizedBox(width: 8), Text('Sil', style: TextStyle(color: AppColors.error))])),
            ],
          ),
        ],
      ),
    );
  }
}
