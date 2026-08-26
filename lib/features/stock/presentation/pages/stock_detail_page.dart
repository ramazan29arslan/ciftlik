import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../data/models/stock_model.dart';
import '../providers/stock_provider.dart';

class StockDetailPage extends ConsumerStatefulWidget {
  final String stockId;
  const StockDetailPage({super.key, required this.stockId});

  @override
  ConsumerState<StockDetailPage> createState() => _StockDetailPageState();
}

class _StockDetailPageState extends ConsumerState<StockDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = ref.watch(stockItemDetailProvider(widget.stockId));

    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Stok Detayı')),
        body: const AppEmptyState(icon: Icons.inventory_2_rounded, title: 'Stok kalemi bulunamadı'),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(item.name),
        actions: [
          IconButton(icon: const Icon(Icons.edit_rounded), onPressed: () => _showEditItemSheet(context, item)),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: item.isLowStock ? AppColors.warningLight : AppColors.primarySurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      Text(item.category, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${item.currentQuantity} ${item.unit}',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700,
                            color: item.isLowStock ? AppColors.warning : AppColors.primary)),
                    if (item.isLowStock) AppBadge.warning('Düşük Stok'),
                  ],
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            tabs: const [Tab(text: 'Hareketler'), Tab(text: 'Bilgiler')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _MovementsTab(stockItemId: item.id),
                _InfoTab(item: item),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showMovementSheet(context, item.id, item.name, item.unit),
        icon: const Icon(Icons.swap_vert_rounded),
        label: const Text('Hareket Ekle'),
      ),
    );
  }

  void _showEditItemSheet(BuildContext context, StockItemModel item) {
    final nameCtrl     = TextEditingController(text: item.name);
    final categoryCtrl = TextEditingController(text: item.category);
    final unitCtrl     = TextEditingController(text: item.unit);
    final minQtyCtrl   = TextEditingController(text: item.minimumQuantity.toString());
    final priceCtrl    = TextEditingController(text: item.unitPrice?.toString() ?? '');
    final supplierCtrl = TextEditingController(text: item.supplier ?? '');
    final notesCtrl    = TextEditingController(text: item.notes ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Stok Kalemi Düzenle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'İsim *', prefixIcon: Icon(Icons.inventory_2_rounded))),
              const SizedBox(height: 12),
              TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Kategori', prefixIcon: Icon(Icons.category_rounded))),
              const SizedBox(height: 12),
              TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'Birim (kg, litre, adet...)', prefixIcon: Icon(Icons.straighten_rounded))),
              const SizedBox(height: 12),
              TextField(controller: minQtyCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Minimum Stok', prefixIcon: Icon(Icons.warning_amber_rounded))),
              const SizedBox(height: 12),
              TextField(controller: priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Birim Fiyat (₺)', prefixIcon: Icon(Icons.payments_rounded))),
              const SizedBox(height: 12),
              TextField(controller: supplierCtrl, decoration: const InputDecoration(labelText: 'Tedarikçi', prefixIcon: Icon(Icons.store_rounded))),
              const SizedBox(height: 12),
              TextField(controller: notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Notlar', alignLabelWithHint: true)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final updated = item.copyWith(
                      name: name,
                      category: categoryCtrl.text.trim().isEmpty ? item.category : categoryCtrl.text.trim(),
                      unit: unitCtrl.text.trim().isEmpty ? item.unit : unitCtrl.text.trim(),
                      minimumQuantity: double.tryParse(minQtyCtrl.text) ?? item.minimumQuantity,
                      unitPrice: priceCtrl.text.trim().isEmpty ? null : double.tryParse(priceCtrl.text),
                      supplier: supplierCtrl.text.trim().isEmpty ? null : supplierCtrl.text.trim(),
                      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                    );
                    ref.read(stockNotifierProvider.notifier).update(updated);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Stok kalemi güncellendi'), backgroundColor: AppColors.success),
                    );
                  },
                  child: const Text('Güncelle'),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      nameCtrl.dispose(); categoryCtrl.dispose(); unitCtrl.dispose();
      minQtyCtrl.dispose(); priceCtrl.dispose(); supplierCtrl.dispose(); notesCtrl.dispose();
    });
  }

  void _showMovementSheet(BuildContext context, String id, String name, String unit) {
    final qtyCtrl = TextEditingController();
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
              children: [
                Text('$name — Hareket', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
                            Icon(Icons.add_rounded, color: isIncoming ? AppColors.success : AppColors.textSecondary),
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
                            Icon(Icons.remove_rounded, color: !isIncoming ? AppColors.error : AppColors.textSecondary),
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
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  decoration: InputDecoration(labelText: 'Miktar ($unit)'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      final qty = double.tryParse(qtyCtrl.text);
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
}

class _MovementsTab extends ConsumerWidget {
  final String stockItemId;
  const _MovementsTab({required this.stockItemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movements = ref.watch(stockMovementsProvider(stockItemId));
    if (movements.isEmpty) {
      return const AppEmptyState(icon: Icons.swap_vert_rounded, title: 'Hareket kaydı yok');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: movements.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final m = movements[index];
        final isIncoming = m.type.name == 'incoming';
        return AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: isIncoming ? AppColors.successLight : AppColors.errorLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(isIncoming ? Icons.add_rounded : Icons.remove_rounded,
                    color: isIncoming ? AppColors.success : AppColors.error, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.typeLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(AppDateUtils.formatDate(m.date), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    if (m.reason != null) Text(m.reason!, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                  ],
                ),
              ),
              Text('${isIncoming ? '+' : '-'}${m.quantity}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                      color: isIncoming ? AppColors.success : AppColors.error)),
            ],
          ),
        );
      },
    );
  }
}

class _InfoTab extends StatelessWidget {
  final dynamic item;
  const _InfoTab({required this.item});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: AppCard(
        child: Column(
          children: [
            _Row(label: 'Kategori', value: item.category),
            _Row(label: 'Birim', value: item.unit),
            _Row(label: 'Mevcut Miktar', value: '${item.currentQuantity} ${item.unit}'),
            _Row(label: 'Min. Miktar', value: '${item.minimumQuantity} ${item.unit}'),
            if (item.unitPrice != null) _Row(label: 'Birim Fiyat', value: '₺${item.unitPrice}'),
            if (item.supplier != null) _Row(label: 'Tedarikçi', value: item.supplier!),
            _Row(label: 'Eklenme', value: AppDateUtils.formatDate(item.createdAt), isLast: true),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;
  const _Row({required this.label, required this.value, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
              Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary), textAlign: TextAlign.right)),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, color: AppColors.divider),
      ],
    );
  }
}
