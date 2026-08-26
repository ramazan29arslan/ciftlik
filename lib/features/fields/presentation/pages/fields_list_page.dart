import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../providers/fields_provider.dart';

class FieldsListPage extends ConsumerWidget {
  const FieldsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fields = ref.watch(fieldsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Tarlalar')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/fields/add'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded),
      ),
      body: fields.isEmpty
          ? AppEmptyState(
              icon: Icons.crop_landscape_rounded,
              title: 'Tarla bulunamadı',
              subtitle: 'Çiftliğinizdeki tarlaları ekleyin',
              actionLabel: 'Tarla Ekle',
              onAction: () => context.go('/fields/add'),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: fields.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final f = fields[index];
                return _FieldCard(
                  field: f,
                  onTap: () => context.go('/fields/detail/${f.id}'),
                  onDelete: () => _confirmDelete(context, ref, f.id, f.name),
                );
              },
            ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tarlayı Sil'),
        content: Text('$name silinecek. Emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              ref.read(fieldsNotifierProvider.notifier).delete(id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$name silindi'),
                  backgroundColor: AppColors.error,
                ),
              );
            },
            child: const Text('Sil',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  final FieldData field;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _FieldCard({
    required this.field,
    required this.onTap,
    required this.onDelete,
  });

  String get _areaLabel {
    final m2 = field.areaM2;
    if (m2 == null) return '';
    if (m2 >= 10000) {
      final ha = m2 / 10000;
      return '${ha.toStringAsFixed(2)} ha';
    }
    if (m2 >= 1000) {
      final donum = m2 / 1000;
      return '${donum.toStringAsFixed(2)} dönüm';
    }
    return '${m2.toStringAsFixed(0)} m²';
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.crop_landscape_rounded,
                color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  field.name,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
                if (field.location != null && field.location!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 13, color: AppColors.textTertiary),
                      const SizedBox(width: 3),
                      Text(
                        field.location!,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (_areaLabel.isNotEmpty) ...[
                      Text(
                        _areaLabel,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textTertiary),
                      ),
                      const SizedBox(width: 8),
                    ],
                    _StatusChip(isPlanted: field.isPlanted),
                    if (field.isPlanted &&
                        field.currentCropName != null &&
                        field.currentCropName!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        field.currentCropName!,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textTertiary, size: 20),
            onSelected: (v) {
              if (v == 'edit') context.go('/fields/edit/${field.id}');
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Düzenle'),
                  ])),
              const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_rounded,
                        size: 18, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Sil',
                        style: TextStyle(color: AppColors.error)),
                  ])),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isPlanted;
  const _StatusChip({required this.isPlanted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPlanted
            ? AppColors.success.withOpacity(0.12)
            : AppColors.textTertiary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isPlanted ? 'Ekili' : 'Boş',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isPlanted ? AppColors.success : AppColors.textSecondary,
        ),
      ),
    );
  }
}
