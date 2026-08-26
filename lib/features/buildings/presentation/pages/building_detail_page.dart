import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../farms/presentation/providers/farm_provider.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/activity_log_widget.dart';
import '../providers/buildings_provider.dart';
import '../../../../core/models/document_model.dart';
import '../../../documents/presentation/widgets/entity_documents_section.dart';

class BuildingDetailPage extends ConsumerStatefulWidget {
  final String buildingId;
  const BuildingDetailPage({super.key, required this.buildingId});

  @override
  ConsumerState<BuildingDetailPage> createState() => _BuildingDetailPageState();
}

class _BuildingDetailPageState extends ConsumerState<BuildingDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const double _electricityRate = 3.5;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final building = ref.watch(buildingsNotifierProvider)
        .where((b) => b.id == widget.buildingId)
        .firstOrNull;
    final devices = building?.devices ?? const [];
    final totalKwh = devices.fold<double>(0.0, (sum, d) {
      final watt = d['watt'] as double;
      final hours = d['hours'] as double;
      final days = d['days'] as int;
      return sum + (watt / 1000) * hours * days;
    });
    final estimatedBill = totalKwh * _electricityRate;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: AppColors.buildingColor,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: Colors.white),
                onPressed: () => context.go('/buildings/edit/${widget.buildingId}'),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF795548), Color(0xFF8D6E63)],
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
                          child: const Icon(Icons.home_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                building?.name ?? 'Yapı',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                              Text(
                                building?.area != null
                                    ? '${building!.type} • ${building.area} m²'
                                    : (building?.type ?? ''),
                                style: const TextStyle(fontSize: 13, color: Colors.white70),
                              ),
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
                  Tab(text: 'Cihazlar'),
                  Tab(text: 'Enerji'),
                  Tab(text: 'Bilgiler'),
                  Tab(text: 'Log'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _DevicesTab(
              devices: devices,
              electricityRate: _electricityRate,
              onDelete: (index) async {
                final b = ref.read(buildingsNotifierProvider.notifier).getById(widget.buildingId);
                if (b != null) {
                  final updated = List<Map<String, dynamic>>.from(b.devices)..removeAt(index);
                  await ref.read(buildingsNotifierProvider.notifier).update(b.copyWith(devices: updated));
                }
              },
            ),
            _EnergyTab(
              devices: devices,
              totalKwh: totalKwh,
              estimatedBill: estimatedBill,
              electricityRate: _electricityRate,
            ),
            _InfoTab(building: building, buildingId: widget.buildingId),
            _LogTab(buildingId: widget.buildingId),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context, building),
        backgroundColor: AppColors.buildingColor,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  static const _buildingDocs = [
    DocType.depremSigortasi,
    DocType.yanginSigortasi,
    DocType.tapu,
    DocType.vekaletname,
    DocType.sozlesme,
    DocType.diger,
  ];

  void _showAddSheet(BuildContext context, dynamic building) {
    showModalBottomSheet(
      context: rootNavigatorKey.currentContext ?? context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ekle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _SheetItem(
              icon: Icons.electrical_services_rounded,
              label: 'Cihaz Ekle',
              color: AppColors.energyColor,
              onTap: () { Navigator.pop(ctx); _showAddDeviceSheet(context); },
            ),
            _SheetItem(
              icon: Icons.description_rounded,
              label: 'Belge Ekle',
              color: AppColors.info,
              onTap: () {
                Navigator.pop(ctx);
                showDocumentAddForm(
                  rootNavigatorKey.currentContext ?? context, ref,
                  entityId: building?.id ?? '',
                  entityType: EntityType.building,
                  entityName: building?.name ?? '',
                  availableDocTypes: _buildingDocs,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDeviceSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final wattCtrl = TextEditingController();
    final hoursCtrl = TextEditingController();
    final daysCtrl = TextEditingController(text: '30');

    showModalBottomSheet(
      context: rootNavigatorKey.currentContext ?? context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Cihaz Ekle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Cihaz Adı *', prefixIcon: Icon(Icons.devices_rounded))),
              const SizedBox(height: 12),
              TextField(controller: wattCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Güç (Watt) *', suffixText: 'W', prefixIcon: Icon(Icons.bolt_rounded))),
              const SizedBox(height: 12),
              TextField(controller: hoursCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Günlük Kullanım *', suffixText: 'saat', prefixIcon: Icon(Icons.timer_rounded))),
              const SizedBox(height: 12),
              TextField(controller: daysCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Aylık Çalışma Günü', suffixText: 'gün', prefixIcon: Icon(Icons.calendar_month_rounded))),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final watt = double.tryParse(wattCtrl.text);
                    final hours = double.tryParse(hoursCtrl.text);
                    if (watt == null || hours == null) return;
                    final b = ref.read(buildingsNotifierProvider.notifier).getById(widget.buildingId);
                    if (b != null) {
                      final newDevice = {
                        'name': nameCtrl.text.trim(),
                        'watt': watt,
                        'hours': hours,
                        'days': int.tryParse(daysCtrl.text) ?? 30,
                      };
                      await ref.read(buildingsNotifierProvider.notifier).update(
                        b.copyWith(devices: [...b.devices, newDevice]),
                      );
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${nameCtrl.text.trim()} eklendi'), backgroundColor: AppColors.success),
                      );
                    }
                  },
                  child: const Text('Kaydet'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogTab extends ConsumerWidget {
  final String buildingId;
  const _LogTab({required this.buildingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logService = ref.read(activityLogServiceProvider);
    return ActivityLogWidget(logService: logService, entityId: buildingId);
  }
}

class _DevicesTab extends StatelessWidget {
  final List<Map<String, dynamic>> devices;
  final double electricityRate;
  final void Function(int) onDelete;

  const _DevicesTab({required this.devices, required this.electricityRate, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return const AppEmptyState(
        icon: Icons.electrical_services_rounded,
        title: 'Cihaz bulunamadı',
        subtitle: 'Cihaz eklemek için + butonuna dokunun',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: devices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final d = devices[index];
        final watt = d['watt'] as double;
        final hours = d['hours'] as double;
        final days = d['days'] as int;
        final monthlyKwh = (watt / 1000) * hours * days;
        final monthlyBill = monthlyKwh * electricityRate;
        return AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.energyColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.electrical_services_rounded, color: AppColors.energyColor, size: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d['name'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text('${watt.toStringAsFixed(0)}W • ${hours}h/gün • $days gün/ay', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${monthlyKwh.toStringAsFixed(1)} kWh', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.energyColor)),
                Text(CurrencyUtils.format(monthlyBill), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ]),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Cihazı Sil'),
                    content: Text('${d['name']} silinecek?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                      TextButton(onPressed: () { onDelete(index); Navigator.pop(ctx); }, child: const Text('Sil', style: TextStyle(color: AppColors.error))),
                    ],
                  ),
                ),
                child: const Icon(Icons.delete_outline_rounded, color: AppColors.textTertiary, size: 18),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EnergyTab extends StatelessWidget {
  final List<Map<String, dynamic>> devices;
  final double totalKwh;
  final double estimatedBill;
  final double electricityRate;

  const _EnergyTab({required this.devices, required this.totalKwh, required this.estimatedBill, required this.electricityRate});

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return const AppEmptyState(icon: Icons.bolt_rounded, title: 'Cihaz yok', subtitle: 'Enerji hesabı için önce cihaz ekleyin');
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: AppCard(padding: const EdgeInsets.all(16), child: Column(children: [
                const Icon(Icons.bolt_rounded, color: AppColors.energyColor, size: 28),
                const SizedBox(height: 8),
                Text('${totalKwh.toStringAsFixed(0)} kWh', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.energyColor)),
                const Text('Aylık Tüketim', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ]))),
              const SizedBox(width: 12),
              Expanded(child: AppCard(padding: const EdgeInsets.all(16), child: Column(children: [
                const Icon(Icons.receipt_rounded, color: AppColors.warning, size: 28),
                const SizedBox(height: 8),
                Text(CurrencyUtils.format(estimatedBill), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.warning)),
                const Text('Tahmini Fatura', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ]))),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(padding: const EdgeInsets.all(14), child: Row(children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.info, size: 18),
            const SizedBox(width: 10),
            Text('Birim fiyat: ₺$electricityRate/kWh', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ])),
          const SizedBox(height: 16),
          const Align(alignment: Alignment.centerLeft, child: Text('Cihaz Bazlı Tüketim', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
          const SizedBox(height: 12),
          ...devices.map((d) {
            final watt = d['watt'] as double;
            final hours = d['hours'] as double;
            final days = d['days'] as int;
            final monthlyKwh = (watt / 1000) * hours * days;
            final pct = totalKwh > 0 ? monthlyKwh / totalKwh : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(d['name'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                  Text('${monthlyKwh.toStringAsFixed(1)} kWh', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.energyColor)),
                ]),
                const SizedBox(height: 8),
                ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct.clamp(0.0, 1.0), backgroundColor: AppColors.borderLight, valueColor: const AlwaysStoppedAnimation<Color>(AppColors.energyColor), minHeight: 6)),
                const SizedBox(height: 4),
                Text('${(pct * 100).toStringAsFixed(1)}% toplam tüketim', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              ])),
            );
          }),
        ],
      ),
    );
  }
}

class _InfoTab extends StatelessWidget {
  final dynamic building;
  final String buildingId;
  const _InfoTab({required this.building, required this.buildingId});

  static const _buildingDocs = [
    DocType.depremSigortasi,
    DocType.yanginSigortasi,
    DocType.tapu,
    DocType.vekaletname,
    DocType.sozlesme,
    DocType.diger,
  ];

  @override
  Widget build(BuildContext context) {
    if (building == null) return const AppEmptyState(icon: Icons.home_work_rounded, title: 'Bilgi yok');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          AppCard(
            child: Column(children: [
              _Row(label: 'Yapı Adı', value: building.name),
              _Row(label: 'Tür', value: building.type),
              _Row(label: 'Alan', value: building.area != null ? '${building.area} m²' : '-'),
              _Row(label: 'Notlar', value: building.notes ?? '-', isLast: true),
            ]),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: EntityDocumentsSection(
              entityId: buildingId,
              entityType: EntityType.building,
              entityName: building.name ?? '',
              availableDocTypes: _buildingDocs,
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label; final String value; final bool isLast;
  const _Row({required this.label, required this.value, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary), textAlign: TextAlign.right)),
        ]),
      ),
      if (!isLast) const Divider(height: 1, color: AppColors.divider),
    ]);
  }
}

class _SheetItem extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _SheetItem({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
    title: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
    onTap: onTap,
  );
}
