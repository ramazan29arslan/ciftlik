import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../core/models/document_model.dart';
import '../../../documents/presentation/widgets/entity_documents_section.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../../../farms/presentation/providers/farm_provider.dart';
import '../providers/fields_provider.dart';

// ── Birim tanımları ───────────────────────────────────────
const Map<String, List<String>> kProductUnits = {
  'Tahıl':   ['kg', 'ton', 'teneke', 'çuval'],
  'Saman':   ['römork', 'balya', 'ton', 'kg'],
  'Diğer':   ['kg', 'ton', 'adet', 'litre', 'balya', 'römork'],
};

const List<String> kProductTypes = ['Tahıl', 'Saman', 'Diğer'];

List<String> unitsFor(String productName) {
  for (final key in kProductUnits.keys) {
    if (productName.startsWith(key) || productName == key) return kProductUnits[key]!;
  }
  return kProductUnits['Diğer']!;
}

class FieldDetailPage extends ConsumerStatefulWidget {
  final String fieldId;
  const FieldDetailPage({super.key, required this.fieldId});

  @override
  ConsumerState<FieldDetailPage> createState() => _FieldDetailPageState();
}

class _FieldDetailPageState extends ConsumerState<FieldDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // State'i izliyoruz; `.notifier` izlemek degisikliklerde yeniden cizim
    // tetiklemedigi icin ekim/hasat kayitlari ancak sayfaya tekrar
    // girildiginde gorunuyordu.
    final field = ref
        .watch(fieldsNotifierProvider)
        .where((f) => f.id == widget.fieldId)
        .firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: AppColors.primary,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: Colors.white),
                onPressed: () => context.go('/fields/edit/${widget.fieldId}'),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                    child: Row(
                      children: [
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.crop_landscape_rounded,
                              color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(field?.name ?? 'Tarla',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                              if (field?.location != null && field!.location!.isNotEmpty)
                                Text(field.location!,
                                    style: const TextStyle(fontSize: 13, color: Colors.white70)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.white,
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Genel'),
                  Tab(text: 'Geçmiş'),
                  Tab(text: 'Yıllık Verim'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _GeneralTab(field: field),
            _HistoryTab(
              field: field,
              onEditHarvest: (r) => _showHarvestEditSheet(field, r),
              onEditPlanting: (r) => _showPlantingEditSheet(field, r),
            ),
            _YearlyYieldTab(field: field),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(field),
        backgroundColor: const Color(0xFF2E7D32),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  // ── + bottom sheet ────────────────────────────────────────
  void _showAddSheet(FieldData? field) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Kayıt Ekle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _SheetItem(
              icon: Icons.grass_rounded,
              label: field?.isPlanted == true ? 'Ekim Kaydı (Tarla Ekili)' : 'Ekim Kaydı',
              color: field?.isPlanted == true ? AppColors.textTertiary : AppColors.success,
              onTap: () {
                Navigator.pop(ctx);
                if (field?.isPlanted == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tarla zaten ekili. Önce hasat kaydı girin.'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }
                Future.microtask(() => _showPlantingSheet(field));
              },
            ),
            _SheetItem(icon: Icons.agriculture_rounded, label: 'Hasat Kaydı', color: AppColors.warning, onTap: () {
              Navigator.pop(ctx);
              Future.microtask(() => _showHarvestSheet(field));
            }),
          ],
        ),
      ),
    );
  }

  // ── Ekim formu ────────────────────────────────────────────
  void _showPlantingSheet(FieldData? field) {
    if (field == null) return;
    final cropCtrl  = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                const Center(child: Text('Ekim Kaydı', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                const SizedBox(height: 20),
                TextField(
                  controller: cropCtrl,
                  decoration: const InputDecoration(labelText: 'Ürün Adı *', hintText: 'Buğday, Arpa, Mısır...', prefixIcon: Icon(Icons.grass_rounded)),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime.now());
                    if (d != null) setS(() => selectedDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Text('Ekim Tarihi: ${selectedDate.day}.${selectedDate.month}.${selectedDate.year}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(controller: notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Notlar', alignLabelWithHint: true)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () {
                      final crop = cropCtrl.text.trim();
                      if (crop.isEmpty) return;
                      final newRecord = CropRecord(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        cropName: crop,
                        plantedDate: selectedDate,
                        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                      );
                      ref.read(fieldsNotifierProvider.notifier).update(
                        field.copyWith(
                          isPlanted: true,
                          currentCropName: crop,
                          currentPlantDate: selectedDate,
                          cropHistory: [...field.cropHistory, newRecord],
                        ),
                      );
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ekim kaydı eklendi'), backgroundColor: AppColors.success),
                      );
                    },
                    child: const Text('Kaydet', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      cropCtrl.dispose();
      notesCtrl.dispose();
    });
  }

  // ── Hasat formu ───────────────────────────────────────────
  void _showHarvestSheet(FieldData? field, {CropRecord? existingRecord}) {
    if (field == null) return;
    _openHarvestForm(field, existingRecord: existingRecord);
  }

  // ── Hasat ürünlerini stoğa otomatik ekle ─────────────────
  void _addYieldsToStock(List<YieldEntry> yields) {
    final stockItems = ref.read(stockNotifierProvider);
    final farmId = ref.read(activeFarmIdProvider) ?? '';

    for (final y in yields) {
      if (y.amount <= 0) continue;
      final name = y.productName.trim();
      if (name.isEmpty) continue;

      // Aynı isimde stok var mı? (büyük/küçük harf duyarsız)
      final existing = stockItems.where(
        (s) => s.name.toLowerCase() == name.toLowerCase() && s.unit == y.unit,
      ).firstOrNull;

      if (existing != null) {
        // Mevcut stoğa ekle
        ref.read(stockNotifierProvider.notifier).addQuantity(existing.id, y.amount);
      } else {
        // Yeni stok kalemi oluştur
        final newItem = createStockItem(
          userId: farmId,
          name: name,
          category: 'Hasat',
          unit: y.unit,
          currentQuantity: y.amount,
          minimumQuantity: 0,
        );
        ref.read(stockNotifierProvider.notifier).add(newItem);
      }
    }
  }

  void _showHarvestEditSheet(FieldData? field, CropRecord record) {
    if (field == null) return;
    _openHarvestForm(field, existingRecord: record, isEdit: true);
  }

  // ── Ekim kaydı düzenleme ──────────────────────────────────
  void _showPlantingEditSheet(FieldData? field, CropRecord record) {
    if (field == null) return;
    final cropCtrl  = TextEditingController(text: record.cropName);
    final notesCtrl = TextEditingController(text: record.notes ?? '');
    DateTime selectedDate = record.plantedDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                const Center(child: Text('Ekim Kaydını Düzenle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                const SizedBox(height: 20),
                TextField(
                  controller: cropCtrl,
                  decoration: const InputDecoration(labelText: 'Ürün Adı *', hintText: 'Buğday, Arpa, Mısır...', prefixIcon: Icon(Icons.grass_rounded)),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime.now());
                    if (d != null) setS(() => selectedDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Text('Ekim Tarihi: ${selectedDate.day}.${selectedDate.month}.${selectedDate.year}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(controller: notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Notlar', alignLabelWithHint: true)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () {
                      final crop = cropCtrl.text.trim();
                      if (crop.isEmpty) return;
                      // Geçmiş listesindeki kaydı güncelle
                      final updatedHistory = field.cropHistory.map((r) {
                        if (r.id != record.id) return r;
                        return r.copyWith(
                          cropName: crop,
                          plantedDate: selectedDate,
                          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                        );
                      }).toList();
                      // Eğer bu mevcut ekili ürünse, FieldData'yı da güncelle
                      final isCurrentCrop = field.isPlanted && record.harvestDate == null;
                      ref.read(fieldsNotifierProvider.notifier).update(
                        field.copyWith(
                          currentCropName: isCurrentCrop ? crop : null,
                          currentPlantDate: isCurrentCrop ? selectedDate : null,
                          cropHistory: updatedHistory,
                        ),
                      );
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ekim kaydı güncellendi'), backgroundColor: AppColors.success),
                      );
                    },
                    child: const Text('Güncelle', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      cropCtrl.dispose();
      notesCtrl.dispose();
    });
  }

  void _openHarvestForm(FieldData field, {CropRecord? existingRecord, bool isEdit = false}) {
    DateTime selectedDate = existingRecord?.harvestDate ?? DateTime.now();
    final notesCtrl = TextEditingController(text: existingRecord?.notes ?? '');

    // Mevcut yields'i kopyala veya boş başla
    final yieldRows = <_YieldRow>[];
    if (existingRecord != null && existingRecord.yields.isNotEmpty) {
      for (final y in existingRecord.yields) {
        yieldRows.add(_YieldRow(
          nameCtrl: TextEditingController(text: y.productName),
          amountCtrl: TextEditingController(text: _fmtAmount(y.amount)),
          unit: y.unit,
          productType: _guessType(y.productName),
        ));
      }
    } else if (existingRecord?.harvestAmount != null) {
      yieldRows.add(_YieldRow(
        nameCtrl: TextEditingController(text: existingRecord!.cropName),
        amountCtrl: TextEditingController(text: _fmtAmount(existingRecord.harvestAmount!)),
        unit: existingRecord.harvestUnit,
        productType: 'Tahıl',
      ));
    } else {
      // Varsayılan: Tahıl + Saman satırları (bir hasatta ikisi birden olabilir)
      yieldRows.add(_YieldRow(
        nameCtrl: TextEditingController(text: existingRecord?.cropName ?? field.currentCropName ?? ''),
        amountCtrl: TextEditingController(),
        unit: 'kg',
        productType: 'Tahıl',
      ));
      yieldRows.add(_YieldRow(
        nameCtrl: TextEditingController(text: 'Saman'),
        amountCtrl: TextEditingController(),
        unit: 'römork',
        productType: 'Saman',
      ));
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Center(child: Text(isEdit ? 'Hasat Kaydını Düzenle' : 'Hasat Kaydı',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                const SizedBox(height: 20),

                // ── Hasat tarihi ─────────────────────────
                GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime.now());
                    if (d != null) setS(() => selectedDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.divider)),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_rounded, color: AppColors.warning, size: 20),
                      const SizedBox(width: 12),
                      Text('Hasat Tarihi: ${selectedDate.day}.${selectedDate.month}.${selectedDate.year}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Ürün kalemleri ───────────────────────
                Row(children: [
                  const Text('Verim Kalemleri', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setS(() => yieldRows.add(_YieldRow(
                      nameCtrl: TextEditingController(),
                      amountCtrl: TextEditingController(),
                      unit: 'kg',
                      productType: 'Tahıl',
                    ))),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Ekle'),
                  ),
                ]),
                const SizedBox(height: 8),

                ...List.generate(yieldRows.length, (i) {
                  final row = yieldRows[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          // Ürün tipi seçimi
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: row.productType,
                              decoration: const InputDecoration(labelText: 'Ürün Tipi', isDense: true),
                              items: kProductTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                              onChanged: (v) => setS(() {
                                row.productType = v!;
                                row.unit = kProductUnits[v]!.first;
                                if (v != 'Diğer') row.nameCtrl.text = v;
                              }),
                            ),
                          ),
                          if (yieldRows.length > 1) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_rounded, color: AppColors.error, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setS(() => yieldRows.removeAt(i)),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 8),
                        // Ürün adı (tipi Diğer ise özel giriş)
                        TextField(
                          controller: row.nameCtrl,
                          decoration: InputDecoration(
                            labelText: row.productType == 'Diğer' ? 'Ürün Adı' : 'Ürün Adı (opsiyonel)',
                            isDense: true,
                            hintText: row.productType == 'Diğer' ? 'Örn: Nohut, Mercimek...' : row.productType,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          // Miktar
                          Expanded(
                            child: TextField(
                              controller: row.amountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Miktar *', isDense: true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Birim dropdown
                          SizedBox(
                            width: 110,
                            child: DropdownButtonFormField<String>(
                              value: kProductUnits[row.productType]!.contains(row.unit)
                                  ? row.unit
                                  : kProductUnits[row.productType]!.first,
                              decoration: const InputDecoration(labelText: 'Birim', isDense: true),
                              items: kProductUnits[row.productType]!
                                  .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                                  .toList(),
                              onChanged: (v) => setS(() => row.unit = v!),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 12),
                TextField(controller: notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Notlar', alignLabelWithHint: true)),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      // Dolu kalemleri topla
                      final yields = yieldRows.where((r) => r.amountCtrl.text.trim().isNotEmpty).map((r) {
                        final name = r.nameCtrl.text.trim().isEmpty ? r.productType : r.nameCtrl.text.trim();
                        return YieldEntry(
                          productName: name,
                          amount: double.tryParse(r.amountCtrl.text.trim()) ?? 0,
                          unit: r.unit,
                        );
                      }).toList();

                      final updatedHistory = List<CropRecord>.from(field.cropHistory);

                      if (isEdit && existingRecord != null) {
                        // Mevcut kaydı güncelle
                        final idx = updatedHistory.indexWhere((r) => r.id == existingRecord.id);
                        if (idx != -1) {
                          updatedHistory[idx] = updatedHistory[idx].copyWith(
                            harvestDate: selectedDate,
                            yields: yields,
                            notes: notesCtrl.text.trim().isEmpty ? updatedHistory[idx].notes : notesCtrl.text.trim(),
                          );
                        }
                      } else {
                        // Mevcut ekilmiş kayda hasat bilgisi ekle
                        final lastIdx = updatedHistory.lastIndexWhere((r) => r.harvestDate == null);
                        if (lastIdx != -1) {
                          updatedHistory[lastIdx] = updatedHistory[lastIdx].copyWith(
                            harvestDate: selectedDate,
                            yields: yields,
                            notes: notesCtrl.text.trim().isEmpty ? updatedHistory[lastIdx].notes : notesCtrl.text.trim(),
                          );
                        } else {
                          // Bağımsız hasat kaydı (ekim kaydı olmadan)
                          updatedHistory.add(CropRecord(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            cropName: yieldRows.first.nameCtrl.text.trim().isEmpty
                                ? (field.currentCropName ?? 'Ürün')
                                : yieldRows.first.nameCtrl.text.trim(),
                            plantedDate: selectedDate,
                            harvestDate: selectedDate,
                            yields: yields,
                            notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                          ));
                        }
                      }

                      ref.read(fieldsNotifierProvider.notifier).update(
                        field.copyWith(
                          isPlanted: false,
                          clearCurrentCropName: true,
                          clearCurrentPlantDate: true,
                          cropHistory: updatedHistory,
                        ),
                      );

                      // ── Hasat ürünlerini stoğa otomatik ekle ──
                      if (!isEdit && yields.isNotEmpty) {
                        _addYieldsToStock(yields);
                      }

                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Hasat kaydedildi ve stoğa eklendi'), backgroundColor: AppColors.warning),
                      );
                    },
                    child: const Text('Kaydet', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      notesCtrl.dispose();
      for (final r in yieldRows) {
        r.nameCtrl.dispose();
        r.amountCtrl.dispose();
      }
    });
  }
}

// ── Yardımcı sınıf ────────────────────────────────────────
class _YieldRow {
  TextEditingController nameCtrl;
  TextEditingController amountCtrl;
  String unit;
  String productType;
  _YieldRow({required this.nameCtrl, required this.amountCtrl, required this.unit, required this.productType});
}

String _fmtAmount(double v) => v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

String _guessType(String name) {
  final n = name.toLowerCase();
  if (n.contains('saman') || n.contains('ot') || n.contains('kuru')) return 'Saman';
  if (n.contains('sap')) return 'Sap';
  if (['tahıl','buğday','arpa','mısır','çavdar','yulaf','tritikale','pirinç'].any((t) => n.contains(t))) return 'Tahıl';
  return 'Diğer';
}

// ── Genel Tab ─────────────────────────────────────────────
class _GeneralTab extends StatelessWidget {
  final FieldData? field;
  const _GeneralTab({required this.field});

  @override
  Widget build(BuildContext context) {
    if (field == null) {
      return const AppEmptyState(icon: Icons.crop_landscape_rounded, title: 'Tarla bulunamadı');
    }
    final f = field!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (f.areaM2 != null) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CardHeader(icon: Icons.square_foot_rounded, title: 'Alan Bilgileri', color: AppColors.primary),
                  _InfoRow(label: 'Metrekare', value: '${f.areaM2!.toStringAsFixed(0)} m²'),
                  _InfoRow(label: 'Dönüm', value: f.areaDonum != null ? '${f.areaDonum!.toStringAsFixed(3)} dönüm' : '-'),
                  _InfoRow(label: 'Hektar', value: f.areaHektar != null ? '${f.areaHektar!.toStringAsFixed(4)} ha' : '-', isLast: true),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (f.tapuNo != null && f.tapuNo!.isNotEmpty) ...[
            AppCard(
              child: Column(
                children: [
                  _CardHeader(icon: Icons.description_rounded, title: 'Tapu Bilgisi', color: AppColors.info),
                  _InfoRow(label: 'Parsel No', value: f.tapuNo!, isLast: true),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          AppCard(
            child: Column(
              children: [
                _CardHeader(
                  icon: Icons.grass_rounded,
                  title: 'Ekim Durumu',
                  color: f.isPlanted ? AppColors.success : AppColors.textTertiary,
                  trailing: _PlantedBadge(isPlanted: f.isPlanted),
                ),
                _InfoRow(label: 'Durum', value: f.isPlanted ? 'Ekili' : 'Boş'),
                if (f.currentCropName != null) _InfoRow(label: 'Ürün', value: f.currentCropName!),
                _InfoRow(
                  label: 'Ekim Tarihi',
                  value: f.currentPlantDate != null ? AppDateUtils.formatDate(f.currentPlantDate) : '-',
                  isLast: true,
                ),
              ],
            ),
          ),
          if (f.lastHarvested != null) ...[
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                children: [
                  _CardHeader(icon: Icons.agriculture_rounded, title: 'Son Hasat', color: AppColors.warning),
                  _InfoRow(label: 'Ürün', value: f.lastHarvested!.cropName),
                  _InfoRow(
                    label: 'Hasat Tarihi',
                    value: AppDateUtils.formatDate(f.lastHarvested!.harvestDate),
                    isLast: f.lastHarvested!.yields.isEmpty && f.lastHarvested!.harvestAmount == null,
                  ),
                  // Verim kalemleri
                  if (f.lastHarvested!.yields.isNotEmpty) ...[
                    ...f.lastHarvested!.yields.asMap().entries.map((e) => _InfoRow(
                      label: e.value.productName,
                      value: '${_fmtAmount(e.value.amount)} ${e.value.unit}',
                      isLast: e.key == f.lastHarvested!.yields.length - 1,
                    )),
                  ] else if (f.lastHarvested!.harvestAmount != null)
                    _InfoRow(label: 'Miktar', value: '${f.lastHarvested!.harvestAmount} ${f.lastHarvested!.harvestUnit}', isLast: true),
                ],
              ),
            ),
          ],
          if (f.notes != null && f.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                children: [
                  _CardHeader(icon: Icons.notes_rounded, title: 'Notlar', color: AppColors.textSecondary),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Align(alignment: Alignment.centerLeft,
                        child: Text(f.notes!, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5))),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          // ── Tapu ve belgeler ──────────────────────────────
          AppCard(
            child: EntityDocumentsSection(
              entityId: f.id,
              entityType: EntityType.field,
              entityName: f.name,
              availableDocTypes: const [
                DocType.tapu,
                DocType.vekaletname,
                DocType.sozlesme,
                DocType.diger,
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ── Geçmiş Tab ────────────────────────────────────────────
class _HistoryTab extends StatelessWidget {
  final FieldData? field;
  final void Function(CropRecord) onEditHarvest;
  final void Function(CropRecord) onEditPlanting;
  const _HistoryTab({required this.field, required this.onEditHarvest, required this.onEditPlanting});

  @override
  Widget build(BuildContext context) {
    if (field == null) {
      return const AppEmptyState(icon: Icons.history_rounded, title: 'Geçmiş bulunamadı');
    }
    final history = List<CropRecord>.from(field!.cropHistory)
      ..sort((a, b) => b.plantedDate.compareTo(a.plantedDate));

    if (history.isEmpty) {
      return const AppEmptyState(
        icon: Icons.history_rounded,
        title: 'Geçmiş kayıt yok',
        subtitle: 'Ekim ve hasat kayıtları burada görünecek',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _CropHistoryCard(
        record: history[i],
        onEditHarvest: () => onEditHarvest(history[i]),
        onEditPlanting: () => onEditPlanting(history[i]),
      ),
    );
  }
}

// ── Yıllık Verim Tab ──────────────────────────────────────
class _YearlyYieldTab extends StatelessWidget {
  final FieldData? field;
  const _YearlyYieldTab({required this.field});

  @override
  Widget build(BuildContext context) {
    if (field == null || field!.cropHistory.isEmpty) {
      return const AppEmptyState(
        icon: Icons.bar_chart_rounded,
        title: 'Verim verisi yok',
        subtitle: 'Hasat kaydı ekledikçe yıllık veriler burada görünecek',
      );
    }

    // Hasat edilmiş kayıtları yıla göre grupla
    final harvested = field!.cropHistory.where((r) => r.harvestDate != null).toList();
    if (harvested.isEmpty) {
      return const AppEmptyState(icon: Icons.bar_chart_rounded, title: 'Henüz hasat kaydı yok');
    }

    final Map<int, List<CropRecord>> byYear = {};
    for (final r in harvested) {
      final y = r.harvestDate!.year;
      byYear.putIfAbsent(y, () => []).add(r);
    }
    final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: years.map((year) {
        final records = byYear[year]!;

        // Ürün bazlı toplamlar
        final Map<String, Map<String, double>> totals = {}; // productName -> unit -> amount
        for (final r in records) {
          if (r.yields.isNotEmpty) {
            for (final y in r.yields) {
              totals.putIfAbsent(y.productName, () => {});
              totals[y.productName]![y.unit] = (totals[y.productName]![y.unit] ?? 0) + y.amount;
            }
          } else if (r.harvestAmount != null) {
            totals.putIfAbsent(r.cropName, () => {});
            totals[r.cropName]![r.harvestUnit] = (totals[r.cropName]![r.harvestUnit] ?? 0) + r.harvestAmount!;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Yıl başlığı
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$year', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                const SizedBox(width: 10),
                Text('${records.length} hasat kaydı', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ]),
            ),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Toplam verimler
                  if (totals.isNotEmpty) ...[
                    const Text('Toplam Verim', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 10),
                    ...totals.entries.expand((entry) => entry.value.entries.map((u) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: _productColor(entry.key).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(_productIcon(entry.key), color: _productColor(entry.key), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                        Text('${_fmtAmount(u.value)} ${u.key}',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _productColor(entry.key))),
                      ]),
                    ))),
                    const Divider(height: 16, color: AppColors.divider),
                  ],
                  // Ekim detayları
                  const Text('Ekim Detayları', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  ...records.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      const Icon(Icons.circle, size: 6, color: AppColors.textTertiary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(r.cropName, style: const TextStyle(fontSize: 13))),
                      Text(AppDateUtils.formatDate(r.harvestDate),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ]),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  Color _productColor(String name) {
    final t = _guessType(name);
    if (t == 'Tahıl') return AppColors.warning;
    if (t == 'Saman' || t == 'Sap') return Colors.brown;
    return AppColors.primary;
  }

  IconData _productIcon(String name) {
    final t = _guessType(name);
    if (t == 'Tahıl') return Icons.grain_rounded;
    if (t == 'Saman' || t == 'Sap') return Icons.grass_rounded;
    return Icons.agriculture_rounded;
  }
}

// ── Geçmiş kart ───────────────────────────────────────────
class _CropHistoryCard extends StatelessWidget {
  final CropRecord record;
  final VoidCallback onEditHarvest;
  final VoidCallback onEditPlanting;
  const _CropHistoryCard({required this.record, required this.onEditHarvest, required this.onEditPlanting});

  @override
  Widget build(BuildContext context) {
    final harvested = record.harvestDate != null;
    final hasYields = record.yields.isNotEmpty;
    final hasOldAmount = record.harvestAmount != null;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: harvested ? AppColors.warning.withOpacity(0.12) : AppColors.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                harvested ? Icons.agriculture_rounded : Icons.grass_rounded,
                color: harvested ? AppColors.warning : AppColors.success,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(record.cropName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Text('Ekildi: ${AppDateUtils.formatDate(record.plantedDate)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ]),
            ),
            _HarvestStatusBadge(harvested: harvested),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onEditPlanting,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_rounded, size: 14, color: AppColors.primary),
              ),
            ),
          ]),
          if (harvested) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 10),
            // Hasat tarihi
            Row(children: [
              const Icon(Icons.event_rounded, size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 6),
              Text('Hasat: ${AppDateUtils.formatDate(record.harvestDate)}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const Spacer(),
              GestureDetector(
                onTap: onEditHarvest,
                child: const Row(children: [
                  Icon(Icons.edit_rounded, size: 14, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text('Düzenle', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                ]),
              ),
            ]),
            // Verim kalemleri
            if (hasYields) ...[
              const SizedBox(height: 8),
              ...record.yields.map((y) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: _yieldColor(y.productName), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(y.productName, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const Spacer(),
                  Text('${_fmtAmount(y.amount)} ${y.unit}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _yieldColor(y.productName))),
                ]),
              )),
            ] else if (hasOldAmount) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.scale_rounded, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 6),
                Text('${record.harvestAmount} ${record.harvestUnit}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.warning)),
              ]),
            ],
          ],
          if (record.notes != null && record.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(record.notes!, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }

  Color _yieldColor(String name) {
    final t = _guessType(name);
    if (t == 'Tahıl') return AppColors.warning;
    if (t == 'Saman' || t == 'Sap') return Colors.brown;
    return AppColors.primary;
  }
}

// ── Yardımcı widget'lar ───────────────────────────────────
class _CardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Widget? trailing;
  const _CardHeader({required this.icon, required this.title, required this.color, this.trailing});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          if (trailing != null) ...[const Spacer(), trailing!],
        ]),
      ),
      const Divider(height: 1, color: AppColors.divider),
    ],
  );
}

class _HarvestStatusBadge extends StatelessWidget {
  final bool harvested;
  const _HarvestStatusBadge({required this.harvested});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: harvested ? AppColors.warning.withOpacity(0.12) : AppColors.success.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      harvested ? 'Hasat Edildi' : 'Tarlada Büyüyor',
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
          color: harvested ? AppColors.warning : AppColors.success),
    ),
  );
}

class _PlantedBadge extends StatelessWidget {
  final bool isPlanted;
  const _PlantedBadge({required this.isPlanted});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: isPlanted ? AppColors.success.withOpacity(0.12) : AppColors.textTertiary.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(isPlanted ? 'Ekili' : 'Boş',
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
          color: isPlanted ? AppColors.success : AppColors.textSecondary)),
  );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;
  const _InfoRow({required this.label, required this.value, this.isLast = false});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), textAlign: TextAlign.right)),
        ]),
      ),
      if (!isLast) const Divider(height: 1, color: AppColors.divider),
    ],
  );
}

class _SheetItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SheetItem({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(width: 40, height: 40,
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20)),
    title: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
    onTap: onTap,
  );
}
