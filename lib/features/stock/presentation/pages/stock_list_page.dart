import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_search_bar.dart';
import '../providers/stock_provider.dart';
import '../../../../core/di/providers.dart';

const _demoFarmId = 'demo';

class StockListPage extends ConsumerWidget {
  const StockListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(stockItemsProvider(_demoFarmId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Stok Yönetimi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddStockSheet(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: AppSearchBar(hint: 'Stok ara...', showFilter: true),
          ),
          Expanded(
            child: items.isEmpty
                ? const AppEmptyState(
                    icon: Icons.inventory_2_rounded,
                    title: 'Stok bulunamadı',
                    subtitle: 'Yem, ilaç, ekipman gibi stok kalemleri ekleyin',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _StockCard(
                        item: item,
                        onTap: () => context.go('/stock/detail/${item.id}'),
                        onDelete: () => _confirmDelete(context, ref, item.id, item.name),
                        onAddMovement: () => _showMovementSheet(context, ref, item.id, item.name, item.unit),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddStockSheet(context, ref),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stok Kalemi Sil'),
        content: Text('$name silinecek. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          TextButton(
            onPressed: () {
              ref.read(stockNotifierProvider.notifier).delete(id);
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

  void _showMovementSheet(BuildContext context, WidgetRef ref, String id, String name, String unit) {
    final qtyController = TextEditingController();
    bool isIncoming = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$name — Hareket Ekle', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => isIncoming = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isIncoming ? AppColors.successLight : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isIncoming ? AppColors.success : AppColors.border),
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.add_rounded, color: isIncoming ? AppColors.success : AppColors.textSecondary, size: 18),
                            const SizedBox(width: 6),
                            Text('Giriş', style: TextStyle(fontWeight: FontWeight.w600, color: isIncoming ? AppColors.success : AppColors.textSecondary)),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => isIncoming = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !isIncoming ? AppColors.errorLight : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: !isIncoming ? AppColors.error : AppColors.border),
                          ),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.remove_rounded, color: !isIncoming ? AppColors.error : AppColors.textSecondary, size: 18),
                            const SizedBox(width: 6),
                            Text('Çıkış', style: TextStyle(fontWeight: FontWeight.w600, color: !isIncoming ? AppColors.error : AppColors.textSecondary)),
                          ]),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: qtyController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  decoration: InputDecoration(labelText: 'Miktar ($unit)', prefixIcon: const Icon(Icons.numbers_rounded)),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      final qty = double.tryParse(qtyController.text);
                      if (qty == null || qty <= 0) return;
                      if (isIncoming) {
                        ref.read(stockNotifierProvider.notifier).addQuantity(id, qty);
                      } else {
                        ref.read(stockNotifierProvider.notifier).removeQuantity(id, qty);
                      }
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${isIncoming ? '+' : '-'}$qty $unit kaydedildi'),
                          backgroundColor: isIncoming ? AppColors.success : AppColors.warning,
                        ),
                      );
                    },
                    child: const Text('Kaydet'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddStockSheet(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final minQtyController = TextEditingController();
    final priceController = TextEditingController();
    String selectedCategory = 'Yem';
    String selectedUnit = 'kg';
    final units = ['kg', 'gram', 'litre', 'ml', 'adet', 'doz', 'balya', 'ton', 'kutu', 'çuval', 'paket'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Stok Kalemi Ekle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Ürün Adı *', prefixIcon: Icon(Icons.inventory_2_rounded))),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: AppConstants.stockCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => selectedCategory = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedUnit,
                  decoration: const InputDecoration(labelText: 'Birim'),
                  items: units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                  onChanged: (v) => setState(() => selectedUnit = v!),
                ),
                const SizedBox(height: 12),
                TextField(controller: minQtyController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Min. Stok ($selectedUnit)', prefixIcon: const Icon(Icons.warning_rounded))),
                const SizedBox(height: 12),
                TextField(controller: priceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Birim Fiyat (₺)', prefixIcon: Icon(Icons.payments_rounded))),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      if (nameController.text.trim().isEmpty) return;
                      final userId = ref.read(currentUserIdProvider) ?? 'anonymous';
                      final item = createStockItem(
                        userId: userId,
                        name: nameController.text.trim(),
                        category: selectedCategory,
                        unit: selectedUnit,
                        minimumQuantity: double.tryParse(minQtyController.text) ?? 0,
                        unitPrice: double.tryParse(priceController.text),
                      );
                      ref.read(stockNotifierProvider.notifier).add(item);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${item.name} eklendi'), backgroundColor: AppColors.success),
                      );
                    },
                    child: const Text('Kaydet'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StockCard extends StatelessWidget {
  final dynamic item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onAddMovement;
  const _StockCard({required this.item, required this.onTap, required this.onDelete, required this.onAddMovement});

  @override
  Widget build(BuildContext context) {
    final isLow = item.isLowStock as bool;
    final isOut = item.isOutOfStock as bool;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: isOut ? AppColors.errorLight : isLow ? AppColors.warningLight : AppColors.primarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.inventory_2_rounded, color: isOut ? AppColors.error : isLow ? AppColors.warning : AppColors.primaryMedium, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(item.name as String, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                    if (isOut) AppBadge.error('Tükendi')
                    else if (isLow) AppBadge.warning('Düşük'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(item.category as String, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('${item.currentQuantity} ${item.unit}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                            color: isOut ? AppColors.error : isLow ? AppColors.warning : AppColors.textPrimary)),
                    Text(' / min ${item.minimumQuantity} ${item.unit}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textTertiary, size: 20),
            onSelected: (v) {
              if (v == 'movement') onAddMovement();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'movement', child: Row(children: [Icon(Icons.swap_vert_rounded, size: 18), SizedBox(width: 8), Text('Hareket Ekle')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, size: 18, color: AppColors.error), SizedBox(width: 8), Text('Sil', style: TextStyle(color: AppColors.error))])),
            ],
          ),
        ],
      ),
    );
  }
}
