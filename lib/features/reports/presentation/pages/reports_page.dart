import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../animals/presentation/providers/animals_provider.dart';
import '../../../animals/domain/entities/animal.dart';
import '../../../vehicles/presentation/providers/vehicles_provider.dart';
import '../../../stock/presentation/providers/stock_provider.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'Bu Ay';
  final _periods = ['Bu Hafta', 'Bu Ay', 'Son 3 Ay', 'Bu Yıl'];

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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Raporlar'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Hayvanlar'),
            Tab(text: 'Araçlar'),
            Tab(text: 'Stok'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _periods.map((p) {
                  final selected = _selectedPeriod == p;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPeriod = p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(p,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: selected ? AppColors.white : AppColors.textSecondary,
                            )),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _AnimalReport(period: _selectedPeriod),
                _VehicleReport(period: _selectedPeriod),
                _StockReport(period: _selectedPeriod),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hayvan Raporu ─────────────────────────────────────────
class _AnimalReport extends ConsumerWidget {
  final String period;
  const _AnimalReport({required this.period});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animals = ref.watch(animalsNotifierProvider);
    final vaccinations = ref.watch(vaccinationsNotifierProvider);
    final milkRecords = ref.watch(milkRecordsNotifierProvider);

    final activeAnimals = animals.where((a) => a.status == AnimalStatus.active).toList();
    final soldAnimals = animals.where((a) => a.status == AnimalStatus.sold).toList();
    final deadAnimals = animals.where((a) => a.status == AnimalStatus.dead).toList();

    // Tür dağılımı
    final typeMap = <String, int>{};
    for (final a in activeAnimals) {
      typeMap[a.type] = (typeMap[a.type] ?? 0) + 1;
    }

    // Süt toplamı (bu ay)
    final now = DateTime.now();
    final monthlyMilk = milkRecords
        .where((r) => r.date.year == now.year && r.date.month == now.month)
        .fold(0.0, (sum, r) => sum + r.totalAmount);

    // Yaklaşan aşılar
    final upcomingVax = vaccinations.where((v) {
      if (v.nextVaccinationDate == null) return false;
      final diff = v.nextVaccinationDate!.difference(now).inDays;
      return diff >= 0 && diff <= 30;
    }).length;

    final typeColors = [
      AppColors.animalColor, AppColors.vehicleColor, AppColors.stockColor,
      AppColors.warning, AppColors.info, AppColors.secondary,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Özet kartlar
          Row(
            children: [
              Expanded(child: _SummaryCard(label: 'Toplam', value: animals.length.toString(), icon: Icons.pets_rounded, color: AppColors.animalColor)),
              const SizedBox(width: 10),
              Expanded(child: _SummaryCard(label: 'Aktif', value: activeAnimals.length.toString(), icon: Icons.check_circle_rounded, color: AppColors.success)),
              const SizedBox(width: 10),
              Expanded(child: _SummaryCard(label: 'Satılan', value: soldAnimals.length.toString(), icon: Icons.sell_rounded, color: AppColors.info)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _SummaryCard(label: 'Aylık Süt', value: '${monthlyMilk.toStringAsFixed(0)} L', icon: Icons.water_drop_rounded, color: AppColors.info)),
              const SizedBox(width: 10),
              Expanded(child: _SummaryCard(label: 'Yaklaşan Aşı', value: upcomingVax.toString(), icon: Icons.vaccines_rounded, color: AppColors.warning)),
              const SizedBox(width: 10),
              Expanded(child: _SummaryCard(label: 'Kayıp', value: deadAnimals.length.toString(), icon: Icons.remove_circle_rounded, color: AppColors.error)),
            ],
          ),
          const SizedBox(height: 16),

          // Tür dağılımı
          if (typeMap.isNotEmpty) ...[
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tür Dağılımı', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  if (activeAnimals.isNotEmpty)
                    SizedBox(
                      height: 160,
                      child: PieChart(
                        PieChartData(
                          sections: typeMap.entries.toList().asMap().entries.map((entry) {
                            final i = entry.key;
                            final e = entry.value;
                            final pct = e.value / activeAnimals.length;
                            return PieChartSectionData(
                              value: e.value.toDouble(),
                              color: typeColors[i % typeColors.length],
                              title: '${(pct * 100).toStringAsFixed(0)}%',
                              radius: 65,
                              titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                            );
                          }).toList(),
                          sectionsSpace: 2,
                          centerSpaceRadius: 0,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  ...typeMap.entries.toList().asMap().entries.map((entry) {
                    final i = entry.key;
                    final e = entry.value;
                    final color = typeColors[i % typeColors.length];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _BreedRow(
                        label: e.key,
                        count: e.value,
                        total: activeAnimals.length,
                        color: color,
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Cinsiyet dağılımı
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cinsiyet Dağılımı', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _GenderRow(animals: activeAnimals),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _GenderRow extends StatelessWidget {
  final List<dynamic> animals;
  const _GenderRow({required this.animals});

  @override
  Widget build(BuildContext context) {
    final male = animals.where((a) => a.gender?.name == 'male').length;
    final female = animals.where((a) => a.gender?.name == 'female').length;
    final unknown = animals.length - male - female;
    final total = animals.length;
    if (total == 0) return const Text('Veri yok', style: TextStyle(color: AppColors.textTertiary));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BreedRow(label: 'Dişi', count: female, total: total, color: Colors.pink),
        const SizedBox(height: 8),
        _BreedRow(label: 'Erkek', count: male, total: total, color: AppColors.vehicleColor),
        if (unknown > 0) ...[
          const SizedBox(height: 8),
          _BreedRow(label: 'Belirsiz', count: unknown, total: total, color: AppColors.textTertiary),
        ],
      ],
    );
  }
}

// ── Araç Raporu ───────────────────────────────────────────
class _VehicleReport extends ConsumerWidget {
  final String period;
  const _VehicleReport({required this.period});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehiclesNotifierProvider);
    final fuelRecords = ref.watch(fuelNotifierProvider);
    final maintenanceRecords = ref.watch(maintenanceNotifierProvider);

    final now = DateTime.now();
    final totalFuelCost = fuelRecords.fold(0.0, (sum, f) => sum + f.totalCost);
    final totalFuelLiters = fuelRecords.fold(0.0, (sum, f) => sum + f.liters);
    final totalMaintenanceCost = maintenanceRecords.fold(0.0, (sum, m) => sum + (m.cost ?? 0));

    final monthlyFuel = fuelRecords
        .where((f) => f.date.year == now.year && f.date.month == now.month)
        .fold(0.0, (sum, f) => sum + f.totalCost);

    // Araç bazlı yakıt
    final vehicleFuelMap = <String, double>{};
    for (final f in fuelRecords) {
      vehicleFuelMap[f.vehicleId] = (vehicleFuelMap[f.vehicleId] ?? 0) + f.totalCost;
    }

    // Durum dağılımı
    final statusMap = <String, int>{};
    for (final v in vehicles) {
      statusMap[v.statusLabel] = (statusMap[v.statusLabel] ?? 0) + 1;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _SummaryCard(label: 'Toplam Araç', value: vehicles.length.toString(), icon: Icons.agriculture_rounded, color: AppColors.vehicleColor)),
              const SizedBox(width: 10),
              Expanded(child: _SummaryCard(label: 'Aylık Yakıt', value: CurrencyUtils.formatCompact(monthlyFuel), icon: Icons.local_gas_station_rounded, color: AppColors.warning)),
              const SizedBox(width: 10),
              Expanded(child: _SummaryCard(label: 'Toplam Bakım', value: CurrencyUtils.formatCompact(totalMaintenanceCost), icon: Icons.build_rounded, color: AppColors.secondary)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _SummaryCard(label: 'Toplam Yakıt', value: CurrencyUtils.formatCompact(totalFuelCost), icon: Icons.payments_rounded, color: AppColors.error)),
              const SizedBox(width: 10),
              Expanded(child: _SummaryCard(label: 'Toplam Litre', value: '${totalFuelLiters.toStringAsFixed(0)} L', icon: Icons.opacity_rounded, color: AppColors.info)),
              const SizedBox(width: 10),
              Expanded(child: _SummaryCard(label: 'Bakım Sayısı', value: maintenanceRecords.length.toString(), icon: Icons.engineering_rounded, color: AppColors.primaryMedium)),
            ],
          ),
          const SizedBox(height: 16),

          // Araç bazlı yakıt
          if (vehicleFuelMap.isNotEmpty)
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Araç Bazlı Yakıt Gideri', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  ...vehicleFuelMap.entries.map((entry) {
                    final vehicle = vehicles.where((v) => v.id == entry.key).firstOrNull;
                    final label = vehicle?.displayName ?? entry.key;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _BreedRow(
                        label: label,
                        count: entry.value.toInt(),
                        total: totalFuelCost.toInt(),
                        color: AppColors.vehicleColor,
                        isCurrency: true,
                      ),
                    );
                  }),
                ],
              ),
            ),
          const SizedBox(height: 12),

          // Durum dağılımı
          if (statusMap.isNotEmpty)
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Araç Durumu', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  ...statusMap.entries.map((e) {
                    Color color;
                    switch (e.key) {
                      case 'Aktif': color = AppColors.success; break;
                      case 'Bakımda': color = AppColors.warning; break;
                      case 'Arızalı': color = AppColors.error; break;
                      default: color = AppColors.textSecondary;
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13))),
                          Text('${e.value} araç', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Stok Raporu ───────────────────────────────────────────
class _StockReport extends ConsumerWidget {
  final String period;
  const _StockReport({required this.period});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(stockNotifierProvider);
    final movements = ref.watch(stockMovementsNotifierProvider);

    final lowStock = items.where((s) => s.isLowStock).toList();
    final outOfStock = items.where((s) => s.isOutOfStock).toList();

    // Kategori dağılımı
    final categoryMap = <String, int>{};
    for (final item in items) {
      categoryMap[item.category] = (categoryMap[item.category] ?? 0) + 1;
    }

    // Toplam stok değeri
    double totalValue = 0;
    for (final item in items) {
      if (item.unitPrice != null) {
        totalValue += item.currentQuantity * item.unitPrice!;
      }
    }

    // Son hareketler
    final recentMovements = movements.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final lastMovements = recentMovements.take(5).toList();

    final categoryColors = [
      AppColors.animalColor, AppColors.vehicleColor, AppColors.stockColor,
      AppColors.warning, AppColors.info, AppColors.secondary, AppColors.error,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _SummaryCard(label: 'Toplam Kalem', value: items.length.toString(), icon: Icons.inventory_2_rounded, color: AppColors.stockColor)),
              const SizedBox(width: 10),
              Expanded(child: _SummaryCard(label: 'Düşük Stok', value: lowStock.length.toString(), icon: Icons.warning_rounded, color: AppColors.warning)),
              const SizedBox(width: 10),
              Expanded(child: _SummaryCard(label: 'Tükenen', value: outOfStock.length.toString(), icon: Icons.remove_shopping_cart_rounded, color: AppColors.error)),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Toplam Stok Değeri', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text(CurrencyUtils.format(totalValue), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Kategori dağılımı
          if (categoryMap.isNotEmpty)
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Kategori Dağılımı', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  ...categoryMap.entries.toList().asMap().entries.map((entry) {
                    final i = entry.key;
                    final e = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _BreedRow(
                        label: e.key,
                        count: e.value,
                        total: items.length,
                        color: categoryColors[i % categoryColors.length],
                      ),
                    );
                  }),
                ],
              ),
            ),
          const SizedBox(height: 12),

          // Düşük stok uyarıları
          if (lowStock.isNotEmpty)
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_rounded, color: AppColors.warning, size: 18),
                      const SizedBox(width: 6),
                      const Text('Düşük Stok Uyarıları', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...lowStock.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(child: Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                        Text('${item.currentQuantity} / ${item.minimumQuantity} ${item.unit}',
                            style: TextStyle(fontSize: 12, color: item.isOutOfStock ? AppColors.error : AppColors.warning, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          const SizedBox(height: 12),

          // Son hareketler
          if (lastMovements.isNotEmpty)
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Son Hareketler', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  ...lastMovements.map((m) {
                    final item = items.where((s) => s.id == m.stockItemId).firstOrNull;
                    final isIn = m.type.name == 'incoming';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(isIn ? Icons.add_circle_rounded : Icons.remove_circle_rounded,
                              color: isIn ? AppColors.success : AppColors.error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(item?.name ?? '-', style: const TextStyle(fontSize: 13))),
                          Text('${isIn ? '+' : '-'}${m.quantity} ${item?.unit ?? ''}',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                  color: isIn ? AppColors.success : AppColors.error)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Ortak Widget'lar ──────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _BreedRow extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;
  final bool isCurrency;
  const _BreedRow({required this.label, required this.count, required this.total, required this.color, this.isCurrency = false});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
            Text(
              isCurrency ? CurrencyUtils.format(count.toDouble()) : count.toString(),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            backgroundColor: AppColors.borderLight,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}
