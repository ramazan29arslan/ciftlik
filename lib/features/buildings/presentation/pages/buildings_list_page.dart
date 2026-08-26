import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../providers/buildings_provider.dart';

class BuildingsListPage extends ConsumerWidget {
  const BuildingsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buildings = ref.watch(buildingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Yapılar')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/buildings/add'),
        child: const Icon(Icons.add_rounded),
      ),
      body: buildings.isEmpty
          ? AppEmptyState(
              icon: Icons.home_work_rounded,
              title: 'Yapı bulunamadı',
              subtitle: 'Ahır, depo, samanlık gibi yapıları ekleyin',
              actionLabel: 'Yapı Ekle',
              onAction: () => context.go('/buildings/add'),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: buildings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final b = buildings[index];
                return _BuildingCard(
                  building: b,
                  onTap: () => context.go('/buildings/detail/${b.id}'),
                  onDelete: () => _confirmDelete(context, ref, b.id, b.name),
                );
              },
            ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yapıyı Sil'),
        content: Text('$name silinecek. Emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              ref.read(buildingsNotifierProvider.notifier).delete(id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$name silindi'),
                  backgroundColor: AppColors.error,
                ),
              );
            },
            child: const Text('Sil', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _BuildingCard extends StatelessWidget {
  final BuildingData building;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _BuildingCard({
    required this.building,
    required this.onTap,
    required this.onDelete,
  });

  IconData get _icon {
    switch (building.type) {
      case 'Ahır': return Icons.home_rounded;
      case 'Samanlık': return Icons.warehouse_rounded;
      case 'Depo': return Icons.inventory_2_rounded;
      case 'Sağımhane': return Icons.water_drop_rounded;
      case 'Kümes': return Icons.egg_rounded;
      case 'Sera': return Icons.grass_rounded;
      case 'Atölye': return Icons.build_rounded;
      default: return Icons.home_work_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: AppColors.buildingColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon, color: AppColors.buildingColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(building.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text(building.type,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                if (building.area != null) ...[
                  const SizedBox(height: 3),
                  Text('${building.area} m²',
                      style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textTertiary, size: 20),
            onSelected: (v) {
              if (v == 'edit') context.go('/buildings/edit/${building.id}');
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [
                Icon(Icons.edit_rounded, size: 18), SizedBox(width: 8), Text('Düzenle'),
              ])),
              const PopupMenuItem(value: 'delete', child: Row(children: [
                Icon(Icons.delete_rounded, size: 18, color: AppColors.error),
                SizedBox(width: 8),
                Text('Sil', style: TextStyle(color: AppColors.error)),
              ])),
            ],
          ),
        ],
      ),
    );
  }
}
