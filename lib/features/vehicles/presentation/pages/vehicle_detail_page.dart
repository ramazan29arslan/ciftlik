import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/di/settings_provider.dart';
import '../../../farms/presentation/providers/farm_provider.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/activity_log_widget.dart';
import '../../domain/entities/vehicle.dart';
import '../../data/models/vehicle_model.dart';
import '../providers/vehicles_provider.dart';
import '../../../../core/utils/vehicle_icon_helper.dart';
import '../../../../core/models/document_model.dart';
import '../../../documents/presentation/widgets/entity_documents_section.dart';

class VehicleDetailPage extends ConsumerWidget {
  final String vehicleId;
  const VehicleDetailPage({super.key, required this.vehicleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(vehicleDetailProvider(vehicleId));
    if (vehicle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Araç Detayı')),
        body: const AppEmptyState(icon: Icons.agriculture_rounded, title: 'Araç bulunamadı'),
      );
    }
    return _VehicleDetailView(vehicle: vehicle);
  }
}

class _VehicleDetailView extends ConsumerStatefulWidget {
  final dynamic vehicle;
  const _VehicleDetailView({required this.vehicle});

  @override
  ConsumerState<_VehicleDetailView> createState() => _VehicleDetailViewState();
}

class _VehicleDetailViewState extends ConsumerState<_VehicleDetailView>
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

  Color get _statusColor {
    switch (widget.vehicle.status as VehicleStatus) {
      case VehicleStatus.active: return AppColors.success;
      case VehicleStatus.maintenance: return AppColors.warning;
      case VehicleStatus.broken: return AppColors.error;
      case VehicleStatus.sold: return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vehicle;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppColors.vehicleColor,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: Colors.white),
                onPressed: () => context.go('/vehicles/edit/${v.id}'),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(VehicleIconHelper.getTypeIcon(v.type as String), color: Colors.white38, size: 40),
                        const SizedBox(height: 8),
                        Text(v.displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _statusColor.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(v.statusLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                            ),
                            const SizedBox(width: 8),
                            Text(v.type, style: const TextStyle(fontSize: 13, color: Colors.white70)),
                            if (v.plate != null) ...[
                              const SizedBox(width: 8),
                              Text('• ${v.plate}', style: const TextStyle(fontSize: 13, color: Colors.white70)),
                            ],
                          ],
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
                  Tab(text: 'Log'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _GeneralTab(vehicle: v),
            _HistoryTab(vehicleId: v.id),
            _LogTab(vehicleId: v.id),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context),
        backgroundColor: AppColors.vehicleColor,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  static const _vehicleDocs = [
    DocType.muayene,
    DocType.trafikSigortasi,
    DocType.kasko,
    DocType.diger,
  ];

  void _showAddSheet(BuildContext context) {
    final v = widget.vehicle;
    final entityName = '${v.plate ?? ''} ${v.brand} ${v.model}'.trim();
    showModalBottomSheet(
      context: rootNavigatorKey.currentContext ?? context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Kayıt Ekle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _SheetItem(icon: Icons.local_gas_station_rounded, label: 'Yakıt Girişi', color: AppColors.vehicleColor, onTap: () { Navigator.pop(ctx); _showFuelSheet(context); }),
            _SheetItem(icon: Icons.build_rounded, label: 'Bakım Kaydı', color: AppColors.warning, onTap: () { Navigator.pop(ctx); _showMaintenanceSheet(context); }),
            _SheetItem(
              icon: Icons.description_rounded,
              label: 'Belge Ekle',
              color: AppColors.info,
              onTap: () {
                Navigator.pop(ctx);
                showDocumentAddForm(
                  rootNavigatorKey.currentContext ?? context, ref,
                  entityId: v.id,
                  entityType: EntityType.vehicle,
                  entityName: entityName,
                  availableDocTypes: _vehicleDocs,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFuelSheet(BuildContext context) {
    final litersCtrl = TextEditingController();
    final kmCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final settings = ref.read(settingsProvider);
    final fuelType = widget.vehicle.fuelType ?? '';
    final pricePerLiter = fuelType == 'Benzin'
        ? settings.benzinPricePerLiter
        : settings.dieselPricePerLiter;
    final priceLabel = fuelType == 'Benzin'
        ? 'Benzin: ₺$pricePerLiter/L (Ayarlardan)'
        : 'Motorin: ₺$pricePerLiter/L (Ayarlardan)';

    showModalBottomSheet(
      context: rootNavigatorKey.currentContext ?? context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Yakıt Girişi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(controller: litersCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Litre *', suffixText: 'L')),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primaryMedium),
                    const SizedBox(width: 8),
                    Text(priceLabel, style: const TextStyle(fontSize: 13, color: AppColors.primaryMedium)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: kmCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Kilometre', suffixText: 'km')),
              const SizedBox(height: 12),
              TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Not')),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    final liters = double.tryParse(litersCtrl.text);
                    if (liters == null) return;
                    final record = createFuelRecord(
                      vehicleId: widget.vehicle.id, date: DateTime.now(),
                      liters: liters, pricePerLiter: pricePerLiter,
                      currentKm: double.tryParse(kmCtrl.text),
                      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                    );
                    ref.read(fuelNotifierProvider.notifier).add(record);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Yakıt kaydı eklendi: $liters L • ₺${(liters * pricePerLiter).toStringAsFixed(2)}'), backgroundColor: AppColors.success),
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
    );
  }

  void _showMaintenanceSheet(BuildContext context, {MaintenanceRecordModel? existing}) {
    final typeCtrl = TextEditingController(text: existing?.maintenanceType ?? '');
    final costCtrl = TextEditingController(text: existing?.cost?.toString() ?? '');
    final providerCtrl = TextEditingController(text: existing?.serviceProvider ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    // Mutable değişkenler için ValueNotifier kullan — StatefulBuilder ile güvenli
    DateTime maintenanceDate = existing?.maintenanceDate ?? DateTime.now();
    DateTime? nextDate = existing?.nextMaintenanceDate;

    showModalBottomSheet(
      context: rootNavigatorKey.currentContext ?? context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(existing != null ? 'Bakım Düzenle' : 'Bakım Kaydı', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: 'Bakım Türü *', prefixIcon: Icon(Icons.build_rounded))),
                const SizedBox(height: 12),
                TextField(controller: costCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Maliyet (₺)', prefixIcon: Icon(Icons.payments_rounded))),
                const SizedBox(height: 12),
                TextField(controller: providerCtrl, decoration: const InputDecoration(labelText: 'Servis / Usta', prefixIcon: Icon(Icons.engineering_rounded))),
                const SizedBox(height: 12),
                // Bakım tarihi — context kullan, ctx değil
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_rounded, color: AppColors.textSecondary),
                  title: Text('Bakım Tarihi: ${maintenanceDate.day}.${maintenanceDate.month}.${maintenanceDate.year}'),
                  trailing: const Icon(Icons.edit_calendar_rounded, size: 18, color: AppColors.textTertiary),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context, // ctx değil, context kullan
                      initialDate: maintenanceDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setModalState(() => maintenanceDate = d);
                  },
                ),
                // Sonraki bakım tarihi
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_rounded, color: AppColors.textSecondary),
                  title: Text(nextDate != null
                      ? 'Sonraki Bakım: ${nextDate!.day}.${nextDate!.month}.${nextDate!.year}'
                      : 'Sonraki Bakım Tarihi (opsiyonel)'),
                  trailing: nextDate != null
                      ? GestureDetector(
                          onTap: () => setModalState(() => nextDate = null),
                          child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textTertiary),
                        )
                      : const Icon(Icons.add_rounded, size: 18, color: AppColors.textTertiary),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context, // ctx değil, context kullan
                      initialDate: nextDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2035),
                    );
                    if (d != null) setModalState(() => nextDate = d);
                  },
                ),
                const SizedBox(height: 12),
                TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Not')),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      if (typeCtrl.text.trim().isEmpty) return;
                      if (existing != null) {
                        // Güncelle
                        final updated = MaintenanceRecordModel(
                          id: existing.id,
                          vehicleId: existing.vehicleId,
                          maintenanceType: typeCtrl.text.trim(),
                          maintenanceDate: maintenanceDate,
                          nextMaintenanceDate: nextDate,
                          cost: double.tryParse(costCtrl.text),
                          serviceProvider: providerCtrl.text.trim().isEmpty ? null : providerCtrl.text.trim(),
                          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                        );
                        ref.read(maintenanceNotifierProvider.notifier).update(updated);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Bakım kaydı güncellendi'), backgroundColor: AppColors.success),
                        );
                      } else {
                        // Yeni ekle
                        final record = createMaintenanceRecord(
                          vehicleId: widget.vehicle.id,
                          maintenanceType: typeCtrl.text.trim(),
                          maintenanceDate: maintenanceDate,
                          nextMaintenanceDate: nextDate,
                          cost: double.tryParse(costCtrl.text),
                          serviceProvider: providerCtrl.text.trim().isEmpty ? null : providerCtrl.text.trim(),
                          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                        );
                        ref.read(maintenanceNotifierProvider.notifier).add(record);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Bakım kaydı eklendi'), backgroundColor: AppColors.success),
                        );
                      }
                    },
                    child: Text(existing != null ? 'Güncelle' : 'Kaydet'),
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

// ── Log Tab ───────────────────────────────────────────────
class _LogTab extends ConsumerWidget {
  final String vehicleId;
  const _LogTab({required this.vehicleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logService = ref.read(activityLogServiceProvider);
    return ActivityLogWidget(logService: logService, entityId: vehicleId);
  }
}

// ── Genel Tab ─────────────────────────────────────────────
class _GeneralTab extends StatelessWidget {
  final dynamic vehicle;
  const _GeneralTab({required this.vehicle});

  static const _vehicleDocs = [
    DocType.muayene,
    DocType.trafikSigortasi,
    DocType.kasko,
    DocType.diger,
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Temel bilgiler
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader('Temel Bilgiler'),
                _InfoRow(label: 'Tür', value: vehicle.type),
                _InfoRow(label: 'Marka', value: vehicle.brand),
                _InfoRow(label: 'Model', value: vehicle.model),
                _InfoRow(label: 'Yıl', value: vehicle.year?.toString() ?? '-'),
                _InfoRow(label: 'Plaka', value: vehicle.plate ?? '-'),
                _InfoRow(label: 'Durum', value: vehicle.statusLabel, isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Teknik bilgiler
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader('Teknik Bilgiler'),
                _InfoRow(label: 'Yakıt Tipi', value: vehicle.fuelType ?? '-'),
                _InfoRow(label: 'Motor Gücü', value: vehicle.enginePower != null ? '${vehicle.enginePower} HP' : '-'),
                _InfoRow(label: 'Motor Hacmi', value: vehicle.engineCC != null ? '${vehicle.engineCC} cc' : '-'),
                _InfoRow(label: 'Motor No', value: vehicle.engineNo ?? '-'),
                _InfoRow(label: 'Şase No', value: vehicle.chassisNo ?? '-', isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Kullanım bilgileri
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader('Kullanım'),
                _InfoRow(label: 'Kilometre', value: vehicle.currentKm != null ? '${vehicle.currentKm!.toStringAsFixed(0)} km' : '-'),
                _InfoRow(label: 'Çalışma Saati', value: vehicle.workingHours != null ? '${vehicle.workingHours!.toStringAsFixed(0)} saat' : '-', isLast: true),
              ],
            ),
          ),
          if (vehicle.notes != null) ...[
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Notlar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Text(vehicle.notes!, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.5)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          AppCard(
            child: EntityDocumentsSection(
              entityId: vehicle.id,
              entityType: EntityType.vehicle,
              entityName: '${vehicle.plate ?? ''} ${vehicle.brand} ${vehicle.model}'.trim(),
              availableDocTypes: _vehicleDocs,
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ── Geçmiş Tab ────────────────────────────────────────────
class _HistoryTab extends ConsumerWidget {
  final String vehicleId;
  const _HistoryTab({required this.vehicleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fuelRecords = ref.watch(fuelRecordsProvider(vehicleId));
    final maintenanceRecords = ref.watch(maintenanceRecordsProvider(vehicleId));

    final allEvents = <_HistoryEvent>[];

    for (final f in fuelRecords) {
      allEvents.add(_HistoryEvent(
        id: f.id,
        date: f.date,
        type: 'fuel',
        title: 'Yakıt Alındı',
        subtitle: '${f.liters} L • ${CurrencyUtils.format(f.totalCost)}',
        icon: Icons.local_gas_station_rounded,
        color: AppColors.vehicleColor,
        extra: f.currentKm != null ? '${f.currentKm!.toStringAsFixed(0)} km' : null,
        notes: f.notes,
        rawRecord: f,
      ));
    }

    for (final m in maintenanceRecords) {
      allEvents.add(_HistoryEvent(
        id: m.id,
        date: m.maintenanceDate,
        type: 'maintenance',
        title: m.maintenanceType,
        subtitle: m.serviceProvider ?? 'Bakım yapıldı',
        icon: Icons.build_rounded,
        color: AppColors.warning,
        extra: m.cost != null ? CurrencyUtils.format(m.cost!) : null,
        nextDate: m.nextMaintenanceDate,
        notes: m.notes,
        rawRecord: m,
      ));
    }

    allEvents.sort((a, b) => b.date.compareTo(a.date));

    if (allEvents.isEmpty) {
      return const AppEmptyState(
        icon: Icons.history_rounded,
        title: 'Geçmiş kaydı yok',
        subtitle: 'Yakıt ve bakım kayıtları burada görünür',
      );
    }

    final upcomingMaintenance = maintenanceRecords.where((m) {
      if (m.nextMaintenanceDate == null) return false;
      final diff = m.nextMaintenanceDate!.difference(DateTime.now()).inDays;
      return diff >= 0 && diff <= 30;
    }).toList();

    return Column(
      children: [
        if (upcomingMaintenance.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_rounded, color: AppColors.warning, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${upcomingMaintenance.length} bakım yaklaşıyor: ${upcomingMaintenance.map((m) => m.maintenanceType).join(', ')}',
                    style: const TextStyle(fontSize: 13, color: AppColors.warning, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: allEvents.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final e = allEvents[index];
              return AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: e.color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                      child: Icon(e.icon, color: e.color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(e.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                              if (e.extra != null)
                                Text(e.extra!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: e.color)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(e.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text(AppDateUtils.formatDate(e.date), style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                          if (e.nextDate != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.event_rounded, size: 12, color: AppColors.textTertiary),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    'Sonraki: ${AppDateUtils.formatDate(e.nextDate)} • ${AppDateUtils.formatDaysUntil(e.nextDate)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppDateUtils.isExpiringSoon(e.nextDate) ? AppColors.warning : AppColors.textTertiary,
                                      fontWeight: AppDateUtils.isExpiringSoon(e.nextDate) ? FontWeight.w600 : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          // Bakım Yapıldı butonu — yaklaşan bakım kaydı için göster
                          if (e.type == 'maintenance' && e.nextDate != null) ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () {
                                final vehicle = ref.read(vehicleDetailProvider(vehicleId));
                                final label = vehicle?.plate ?? '${vehicle?.brand ?? ''} ${vehicle?.model ?? ''}'.trim();
                                showMaintenanceCompleteSheet(
                                  context, ref,
                                  e.rawRecord as MaintenanceRecordModel,
                                  label,
                                );
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 7),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 15),
                                    SizedBox(width: 6),
                                    Text('Bakım Yapıldı', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          if (e.notes != null) ...[
                            const SizedBox(height: 4),
                            Text(e.notes!, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary, fontStyle: FontStyle.italic)),
                          ],
                        ],
                      ),
                    ),
                    // Sil / Düzenle menüsü
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: AppColors.textTertiary, size: 18),
                      onSelected: (action) {
                        if (action == 'delete') {
                          _confirmDelete(context, ref, e);
                        } else if (action == 'edit' && e.type == 'maintenance' && e.rawRecord != null) {
                          _editMaintenance(context, ref, e.rawRecord as MaintenanceRecordModel);
                        } else if (action == 'edit' && e.type == 'fuel' && e.rawRecord != null) {
                          _editFuel(context, ref, e.rawRecord as FuelRecordModel);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Row(children: [
                          Icon(Icons.edit_rounded, size: 16), SizedBox(width: 8), Text('Düzenle'),
                        ])),
                        const PopupMenuItem(value: 'delete', child: Row(children: [
                          Icon(Icons.delete_rounded, size: 16, color: AppColors.error),
                          SizedBox(width: 8),
                          Text('Sil', style: TextStyle(color: AppColors.error)),
                        ])),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, _HistoryEvent e) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kaydı Sil'),
        content: Text('${e.title} kaydı silinecek. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          TextButton(
            onPressed: () {
              if (e.type == 'fuel') {
                ref.read(fuelNotifierProvider.notifier).delete(e.id);
              } else {
                ref.read(maintenanceNotifierProvider.notifier).delete(e.id);
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${e.title} silindi'), backgroundColor: AppColors.error),
              );
            },
            child: const Text('Sil', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _editMaintenance(BuildContext context, WidgetRef ref, MaintenanceRecordModel record) {
    final typeCtrl = TextEditingController(text: record.maintenanceType);
    final costCtrl = TextEditingController(text: record.cost?.toString() ?? '');
    final providerCtrl = TextEditingController(text: record.serviceProvider ?? '');
    final notesCtrl = TextEditingController(text: record.notes ?? '');
    DateTime maintenanceDate = record.maintenanceDate;
    DateTime? nextDate = record.nextMaintenanceDate;

    showModalBottomSheet(
      context: rootNavigatorKey.currentContext ?? context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Bakım Düzenle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: 'Bakım Türü *', prefixIcon: Icon(Icons.build_rounded))),
                const SizedBox(height: 12),
                TextField(controller: costCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Maliyet (₺)', prefixIcon: Icon(Icons.payments_rounded))),
                const SizedBox(height: 12),
                TextField(controller: providerCtrl, decoration: const InputDecoration(labelText: 'Servis / Usta', prefixIcon: Icon(Icons.engineering_rounded))),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_rounded, color: AppColors.textSecondary),
                  title: Text('Bakım Tarihi: ${maintenanceDate.day}.${maintenanceDate.month}.${maintenanceDate.year}'),
                  trailing: const Icon(Icons.edit_calendar_rounded, size: 18, color: AppColors.textTertiary),
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: maintenanceDate, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) setS(() => maintenanceDate = d);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_rounded, color: AppColors.textSecondary),
                  title: Text(nextDate != null ? 'Sonraki: ${nextDate!.day}.${nextDate!.month}.${nextDate!.year}' : 'Sonraki Bakım Tarihi (opsiyonel)'),
                  trailing: nextDate != null
                      ? GestureDetector(onTap: () => setS(() => nextDate = null), child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textTertiary))
                      : const Icon(Icons.add_rounded, size: 18, color: AppColors.textTertiary),
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: nextDate ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2035));
                    if (d != null) setS(() => nextDate = d);
                  },
                ),
                const SizedBox(height: 12),
                TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Not')),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      if (typeCtrl.text.trim().isEmpty) return;
                      final updated = MaintenanceRecordModel(
                        id: record.id,
                        vehicleId: record.vehicleId,
                        maintenanceType: typeCtrl.text.trim(),
                        maintenanceDate: maintenanceDate,
                        nextMaintenanceDate: nextDate,
                        cost: double.tryParse(costCtrl.text),
                        serviceProvider: providerCtrl.text.trim().isEmpty ? null : providerCtrl.text.trim(),
                        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                      );
                      ref.read(maintenanceNotifierProvider.notifier).update(updated);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Bakım kaydı güncellendi'), backgroundColor: AppColors.success),
                      );
                    },
                    child: const Text('Güncelle'),
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

  void _editFuel(BuildContext context, WidgetRef ref, FuelRecordModel record) {
    final litersCtrl = TextEditingController(text: record.liters.toString());
    final priceCtrl  = TextEditingController(text: record.pricePerLiter.toString());
    final kmCtrl     = TextEditingController(text: record.currentKm?.toString() ?? '');
    final notesCtrl  = TextEditingController(text: record.notes ?? '');
    DateTime fuelDate = record.date;

    showModalBottomSheet(
      context: rootNavigatorKey.currentContext ?? context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                const Text('Yakıt Kaydını Düzenle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_rounded, color: AppColors.textSecondary),
                  title: Text('Tarih: ${fuelDate.day}.${fuelDate.month}.${fuelDate.year}'),
                  trailing: const Icon(Icons.edit_calendar_rounded, size: 18, color: AppColors.textTertiary),
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: fuelDate, firstDate: DateTime(2000), lastDate: DateTime.now());
                    if (d != null) setS(() => fuelDate = d);
                  },
                ),
                const SizedBox(height: 4),
                TextField(controller: litersCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Litre *', suffixText: 'L', prefixIcon: Icon(Icons.local_gas_station_rounded))),
                const SizedBox(height: 12),
                TextField(controller: priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Fiyat (₺/L)', prefixIcon: Icon(Icons.payments_rounded))),
                const SizedBox(height: 12),
                TextField(controller: kmCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Kilometre', suffixText: 'km', prefixIcon: Icon(Icons.speed_rounded))),
                const SizedBox(height: 12),
                TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Not', prefixIcon: Icon(Icons.notes_rounded))),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      final liters = double.tryParse(litersCtrl.text);
                      final price  = double.tryParse(priceCtrl.text) ?? record.pricePerLiter;
                      if (liters == null) return;
                      final updated = record.copyWith(
                        date: fuelDate,
                        liters: liters,
                        pricePerLiter: price,
                        totalCost: liters * price,
                        currentKm: kmCtrl.text.trim().isEmpty ? null : double.tryParse(kmCtrl.text),
                        clearCurrentKm: kmCtrl.text.trim().isEmpty,
                        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                        clearNotes: notesCtrl.text.trim().isEmpty,
                      );
                      ref.read(fuelNotifierProvider.notifier).update(updated);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Yakıt kaydı güncellendi'), backgroundColor: AppColors.success),
                      );
                    },
                    child: const Text('Güncelle'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      litersCtrl.dispose();
      priceCtrl.dispose();
      kmCtrl.dispose();
      notesCtrl.dispose();
    });
  }
}

// ── Bakım Tamamlama Sheet (dashboard ve araç detayından çağrılabilir) ─────
void showMaintenanceCompleteSheet(
  BuildContext context,
  WidgetRef ref,
  MaintenanceRecordModel record,
  String vehicleLabel,
) {
  final costCtrl = TextEditingController();
  final providerCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  DateTime completedDate = DateTime.now();
  DateTime? nextDate;

  showModalBottomSheet(
    context: rootNavigatorKey.currentContext ?? context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Başlık bandı ──────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.build_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(record.maintenanceType,
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                              Text(vehicleLabel,
                                style: const TextStyle(fontSize: 13, color: Colors.white70)),
                            ],
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),

                // ── Form alanları ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bakım tarihi
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                        ),
                        title: Text(
                          'Bakım Tarihi: ${completedDate.day}.${completedDate.month}.${completedDate.year}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        trailing: const Icon(Icons.edit_calendar_rounded, size: 18, color: AppColors.textTertiary),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: completedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (d != null) setS(() => completedDate = d);
                        },
                      ),
                      const Divider(height: 1),

                      // Sonraki bakım tarihi — ZORUNLU
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: (nextDate != null ? AppColors.primary : AppColors.warning).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.event_rounded,
                            color: nextDate != null ? AppColors.primary : AppColors.warning,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          nextDate != null
                              ? 'Sonraki Bakım: ${nextDate!.day}.${nextDate!.month}.${nextDate!.year}'
                              : 'Sonraki Bakım Tarihi Seç *',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: nextDate != null ? AppColors.textPrimary : AppColors.warning,
                          ),
                        ),
                        trailing: nextDate != null
                            ? GestureDetector(
                                onTap: () => setS(() => nextDate = null),
                                child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textTertiary),
                              )
                            : const Icon(Icons.add_rounded, size: 18, color: AppColors.warning),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(const Duration(days: 90)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2035),
                          );
                          if (d != null) setS(() => nextDate = d);
                        },
                      ),
                      const Divider(height: 1),
                      const SizedBox(height: 16),

                      TextField(
                        controller: costCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Maliyet (₺)',
                          prefixIcon: Icon(Icons.payments_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: providerCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Servis / Usta',
                          prefixIcon: Icon(Icons.engineering_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Not (opsiyonel)',
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Onay butonu
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_rounded),
                          label: const Text('Bakımı Tamamla', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: nextDate == null ? null : () async {
                            Navigator.pop(ctx);

                            // 1) Eski kaydın nextMaintenanceDate'ini temizle
                            final cleared = MaintenanceRecordModel(
                              id: record.id,
                              vehicleId: record.vehicleId,
                              maintenanceType: record.maintenanceType,
                              maintenanceDate: record.maintenanceDate,
                              nextMaintenanceDate: null, // temizlendi
                              cost: record.cost,
                              serviceProvider: record.serviceProvider,
                              notes: record.notes,
                            );
                            await ref.read(maintenanceNotifierProvider.notifier).update(cleared);

                            // 2) Bugün yapılan bakım için yeni kayıt oluştur
                            final newRecord = createMaintenanceRecord(
                              vehicleId: record.vehicleId,
                              maintenanceType: record.maintenanceType,
                              maintenanceDate: completedDate,
                              nextMaintenanceDate: nextDate,
                              cost: double.tryParse(costCtrl.text),
                              serviceProvider: providerCtrl.text.trim().isEmpty ? null : providerCtrl.text.trim(),
                              notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                            );
                            await ref.read(maintenanceNotifierProvider.notifier).add(newRecord);

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${record.maintenanceType} tamamlandı. Sonraki: ${nextDate!.day}.${nextDate!.month}.${nextDate!.year}',
                                  ),
                                  backgroundColor: AppColors.success,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      // İptal
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Daha Sonra', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  ).whenComplete(() {
    costCtrl.dispose();
    providerCtrl.dispose();
    notesCtrl.dispose();
  });
}

class _HistoryEvent {
  final String id;
  final DateTime date;
  final String type;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? extra;
  final DateTime? nextDate;
  final String? notes;
  final dynamic rawRecord;

  const _HistoryEvent({
    required this.id,
    required this.date, required this.type, required this.title,
    required this.subtitle, required this.icon, required this.color,
    this.extra, this.nextDate, this.notes, this.rawRecord,
  });
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
  );
}

class _InfoRow extends StatelessWidget {
  final String label; final String value; final bool isLast;
  const _InfoRow({required this.label, required this.value, this.isLast = false});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary), textAlign: TextAlign.right)),
          ],
        ),
      ),
      if (!isLast) const Divider(height: 1, color: AppColors.divider),
    ],
  );
}

