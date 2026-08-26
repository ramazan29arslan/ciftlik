import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../farms/presentation/providers/farm_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/utils/weather_service.dart';
import '../../../../core/di/settings_provider.dart';
import '../../../../core/di/dashboard_layout_provider.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../animals/presentation/providers/animals_provider.dart';
import '../../../animals/domain/entities/animal.dart';
import '../../../vehicles/presentation/providers/vehicles_provider.dart';
import '../../../stock/presentation/providers/stock_provider.dart';
import '../../../notifications/domain/entities/app_notification.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../notifications/presentation/providers/app_announcements_provider.dart';
import '../../../transfers/presentation/providers/sale_transfer_provider.dart';
import '../../../vehicles/presentation/pages/vehicle_detail_page.dart'
    show showMaintenanceCompleteSheet;
import '../../../vehicles/presentation/providers/vehicles_provider.dart'
    show vehiclesNotifierProvider, maintenanceNotifierProvider;

const _demoFarmId = 'demo';

// Hava kodu → Türkçe açıklama (kısa)
String _weatherTr(int code) {
  if (code == 113) return 'Güneşli';
  if (code == 116) return 'Parçalı bulutlu';
  if (code == 119 || code == 122) return 'Bulutlu';
  if ([143, 248, 260].contains(code)) return 'Sisli';
  if ([176, 293, 296].contains(code)) return 'Hafif yağmurlu';
  if ([263, 266, 281, 284].contains(code)) return 'Çisenti';
  if ([299, 302, 305, 308].contains(code)) return 'Yağmurlu';
  if ([353, 356, 359].contains(code)) return 'Sağanak yağış';
  if ([311, 314, 317, 320].contains(code)) return 'Karla karışık yağmur';
  if ([179, 182, 185].contains(code)) return 'Hafif kar';
  if ([323, 326, 329, 332, 335, 338].contains(code)) return 'Kar yağışı';
  if ([350, 368, 371].contains(code)) return 'Kar fırtınası';
  if ([395].contains(code)) return 'Yoğun kar';
  if ([200, 386, 389].contains(code)) return 'Gök gürültülü fırtına';
  if ([392].contains(code)) return 'Karla karışık fırtına';
  if ([362, 365, 374, 377].contains(code)) return 'Dolu yağışı';
  return 'Değişken hava';
}

String _greeting() {
  final h = DateTime.now().hour;
  if (h >= 5 && h < 10) return 'Günaydın';
  if (h >= 10 && h < 18) return 'İyi Günler';
  if (h >= 18 && h < 22) return 'İyi Akşamlar';
  return 'İyi Geceler';
}

// ── Ana Sayfa ─────────────────────────────────────────────
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _editMode = false;
  Set<String>? _layoutSnapshot; // İptal için önceki düzen

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadAnnouncementsLastSeen(ref);
      // Her açılışta veri yoksa yükle; veri varsa arka planda sessizce yenile
      final weather = ref.read(weatherProvider);
      weather.whenData((data) {
        if (data == null) {
          // İlk kez: hem kayıtlı şehir hem GPS dene
          ref.read(weatherProvider.notifier).loadWeather();
        }
        // Veri varsa güncellemeye gerek yok, eski veri gösterilmeye devam eder
      });
      // Hata veya loading durumunda da dene
      if (weather is AsyncError || weather is AsyncLoading) {
        ref.read(weatherProvider.notifier).loadWeather();
      }
    });
  }

  void _toggleEditMode() {
    if (!_editMode) {
      _layoutSnapshot = ref.read(dashboardLayoutProvider).toSet();
    }
    setState(() => _editMode = !_editMode);
  }

  void _exitEditMode() {
    setState(() => _editMode = false);
    _layoutSnapshot = null;
  }

  void _cancelEditMode() {
    if (_layoutSnapshot != null) {
      ref.read(dashboardLayoutProvider.notifier).restoreFrom(_layoutSnapshot!);
    }
    setState(() => _editMode = false);
    _layoutSnapshot = null;
  }

  @override
  Widget build(BuildContext context) {
    try {
    final animalCount = ref.watch(animalCountProvider(_demoFarmId));
    final upcomingVaccinations = ref.watch(upcomingVaccinationsProvider(_demoFarmId));
    final monthlyFuel = ref.watch(monthlyFuelCostProvider(_demoFarmId));
    final lowStockCount = ref.watch(lowStockCountProvider(_demoFarmId));
    final weather = ref.watch(weatherProvider);
    final announcementCount = ref.watch(unreadAnnouncementsCountProvider);
    final pendingTransfers = ref.watch(pendingIncomingCountProvider);
    final totalNotifications = announcementCount + pendingTransfers;
    final settings = ref.watch(settingsProvider);
    final visible = ref.watch(dashboardLayoutProvider);
    final layout = ref.read(dashboardLayoutProvider.notifier);

    final double statusBarH = MediaQuery.paddingOf(context).top;
    final double stripHeight = weather.maybeWhen(
      data: (d) => d != null ? 132.0 : 44.0,
      orElse: () => 0.0,
    );

    // İki stat kartı görünür mü?
    final showHayvan = visible.contains('stat_hayvan');
    final showAsi = visible.contains('stat_asi');
    final showYakit = visible.contains('stat_yakit');
    final showStok = visible.contains('stat_stok');
    final showQuick = visible.contains('quick_actions');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GestureDetector(
              onLongPress: _toggleEditMode,
              child: CustomScrollView(
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _DashboardHeaderDelegate(
                    statusBarHeight: statusBarH,
                    stripHeight: stripHeight,
                    weather: weather,
                    ref: ref,
                    totalNotifications: totalNotifications,
                    settings: settings,
                    editMode: _editMode,
                    onEditToggle: _toggleEditMode,
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Düzenleme modu ipucu
                        if (_editMode) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.warning.withOpacity(0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.edit_rounded, color: AppColors.warning, size: 16),
                                const SizedBox(width: 8),
                                const Expanded(child: Text('Görmek istediklerinizi seçin', style: TextStyle(fontSize: 13, color: AppColors.warning, fontWeight: FontWeight.w500))),
                                GestureDetector(
                                  onTap: () => ref.read(dashboardLayoutProvider.notifier).resetToDefault(),
                                  child: const Text('Sıfırla', style: TextStyle(fontSize: 12, color: AppColors.warning, decoration: TextDecoration.underline)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── Bildirimler (stat kartların üstünde) ─────────
                        if (!_editMode)
                          Builder(builder: (ctx) {
                            final farmNotifs = ref.watch(notificationsProvider);
                            final shown = farmNotifs.take(7).toList();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text('Bildirimler', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: () => context.push(AppRoutes.notifications),
                                      child: const Text('Tümünü Gör', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (shown.isEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: AppColors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.textTertiary.withOpacity(0.15)),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 20),
                                        SizedBox(width: 10),
                                        Text('Yaklaşan bildirim yok', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  )
                                else
                                  ...shown.map((n) => _DashboardNotifCard(notification: n, onTap: () {
                                    if (n.id.startsWith('birth_') && n.entityId != null) {
                                      final allAnimals = ref.read(animalsNotifierProvider);
                                      final mother = allAnimals.where((a) => a.id == n.entityId).firstOrNull;
                                      String route = '${AppRoutes.animals}/add?motherId=${n.entityId}';
                                      if (mother != null) {
                                        if (mother.inseminationMateId != null && mother.inseminationMateId != '__other__') {
                                          route += '&fatherId=${mother.inseminationMateId}';
                                        } else if (mother.inseminationMateId == '__other__') {
                                          final parts = <String>[];
                                          if (mother.otherMateName?.isNotEmpty == true) parts.add('Baba: ${mother.otherMateName}');
                                          if (mother.otherMateAge?.isNotEmpty == true) parts.add('Yaş: ${mother.otherMateAge}');
                                          if (mother.otherMateOwner?.isNotEmpty == true) parts.add('Sahibi: ${mother.otherMateOwner}');
                                          if (parts.isNotEmpty) route += '&notes=${Uri.encodeQueryComponent(parts.join(', '))}';
                                        } else if (mother.inseminationType == InseminationType.artificial) {
                                          final parts = <String>['Suni tohumlama'];
                                          if (mother.semenBrand?.isNotEmpty == true) parts.add('Marka: ${mother.semenBrand}');
                                          if (mother.inseminationVet?.isNotEmpty == true) parts.add('Veteriner: ${mother.inseminationVet}');
                                          route += '&notes=${Uri.encodeQueryComponent(parts.join(', '))}';
                                        }
                                      }
                                      context.push(route);
                                    } else if (n.entityType == 'maintenance' && n.entityId != null) {
                                      // Bakım bildirimine tıklandı → tamamlama sheet'ini aç
                                      final records = ref.read(maintenanceNotifierProvider);
                                      final record = records.where((m) => m.id == n.entityId).firstOrNull;
                                      if (record != null) {
                                        final vehicles = ref.read(vehiclesNotifierProvider);
                                        final vehicle = vehicles.where((v) => v.id == record.vehicleId).firstOrNull;
                                        final label = vehicle?.plate ?? '${vehicle?.brand ?? ''} ${vehicle?.model ?? ''}'.trim();
                                        if (context.mounted) {
                                          showMaintenanceCompleteSheet(context, ref, record, label);
                                        }
                                      } else if (n.farmId != null) {
                                        // Kayıt bulunamazsa araç detayına git
                                        context.push('${AppRoutes.vehicles}/detail/${n.farmId}');
                                      }
                                    } else if (n.entityType == 'animal' && n.entityId != null) {
                                      context.push('${AppRoutes.animals}/detail/${n.entityId}');
                                    } else if (n.entityType == 'vehicle' && n.entityId != null) {
                                      context.push('${AppRoutes.vehicles}/detail/${n.entityId}');
                                    } else if (n.entityType == 'stock' && n.entityId != null) {
                                      context.push('${AppRoutes.stock}/detail/${n.entityId}');
                                    } else {
                                      context.push(AppRoutes.notifications);
                                    }
                                  })),
                                const SizedBox(height: 20),
                              ],
                            );
                          }),

                        // ── Bekleyen Transfer Talepleri ─────────────────
                        if (!_editMode && pendingTransfers > 0)
                          GestureDetector(
                            onTap: () => context.push(AppRoutes.saleTransfers),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.swap_horiz_rounded, color: AppColors.primary, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text('$pendingTransfers bekleyen transfer talebi var', style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600))),
                                  const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 18),
                                ],
                              ),
                            ),
                          ),

                        // ── İstatistik Kartları ─────────────────────────
                        if (showHayvan || showAsi || _editMode) ...[
                          Row(children: [
                            if (showHayvan || _editMode)
                              Expanded(child: _EditableWidget(
                                id: 'stat_hayvan',
                                editMode: _editMode,
                                visible: showHayvan,
                                onToggle: () => layout.toggle('stat_hayvan'),
                                child: AppStatCard(
                                  title: 'Toplam Hayvan',
                                  value: animalCount.toString(),
                                  icon: Icons.pets_rounded,
                                  color: AppColors.animalColor,
                                  onTap: _editMode ? null : () => context.go(AppRoutes.animals),
                                ),
                              )),
                            if ((showHayvan || _editMode) && (showAsi || _editMode))
                              const SizedBox(width: 12),
                            if (showAsi || _editMode)
                              Expanded(child: _EditableWidget(
                                id: 'stat_asi',
                                editMode: _editMode,
                                visible: showAsi,
                                onToggle: () => layout.toggle('stat_asi'),
                                child: AppStatCard(
                                  title: 'Yaklaşan Aşı',
                                  value: upcomingVaccinations.length.toString(),
                                  subtitle: upcomingVaccinations.isEmpty ? 'Yaklaşan yok' : '30 gün içinde',
                                  icon: Icons.vaccines_rounded,
                                  color: upcomingVaccinations.isNotEmpty ? AppColors.warning : AppColors.success,
                                  onTap: _editMode ? null : () => context.go(AppRoutes.animals),
                                ),
                              )),
                          ]),
                          const SizedBox(height: 12),
                        ],

                        if (showYakit || showStok || _editMode) ...[
                          Row(children: [
                            if (showYakit || _editMode)
                              Expanded(child: _EditableWidget(
                                id: 'stat_yakit',
                                editMode: _editMode,
                                visible: showYakit,
                                onToggle: () => layout.toggle('stat_yakit'),
                                child: AppStatCard(
                                  title: 'Aylık Yakıt',
                                  value: CurrencyUtils.formatCompact(monthlyFuel),
                                  icon: Icons.local_gas_station_rounded,
                                  color: AppColors.vehicleColor,
                                  onTap: _editMode ? null : () => context.go(AppRoutes.vehicles),
                                ),
                              )),
                            if ((showYakit || _editMode) && (showStok || _editMode))
                              const SizedBox(width: 12),
                            if (showStok || _editMode)
                              Expanded(child: _EditableWidget(
                                id: 'stat_stok',
                                editMode: _editMode,
                                visible: showStok,
                                onToggle: () => layout.toggle('stat_stok'),
                                child: AppStatCard(
                                  title: 'Düşük Stok',
                                  value: lowStockCount.toString(),
                                  subtitle: 'Ürün',
                                  icon: Icons.inventory_2_rounded,
                                  color: AppColors.error,
                                  onTap: _editMode ? null : () => context.go(AppRoutes.stock),
                                ),
                              )),
                          ]),
                          const SizedBox(height: 24),
                        ],

                        // ── Hızlı İşlemler ──────────────────────────────
                        if (showQuick || _editMode) ...[
                          _EditableWidget(
                            id: 'quick_actions',
                            editMode: _editMode,
                            visible: showQuick,
                            onToggle: () => layout.toggle('quick_actions'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Hızlı İşlemler', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                const SizedBox(height: 12),
                                Row(children: [
                                  _QuickAction(icon: Icons.add_circle_rounded, label: 'Hayvan Ekle', color: AppColors.animalColor, onTap: _editMode ? null : () => context.go('${AppRoutes.animals}/add')),
                                  const SizedBox(width: 10),
                                  _QuickAction(icon: Icons.local_gas_station_rounded, label: 'Yakıt Gir', color: AppColors.vehicleColor, onTap: _editMode ? null : () => context.go(AppRoutes.vehicles)),
                                  const SizedBox(width: 10),
                                  _QuickAction(icon: Icons.inventory_rounded, label: 'Stok Gir', color: AppColors.stockColor, onTap: _editMode ? null : () => context.go(AppRoutes.stock)),
                                  const SizedBox(width: 10),
                                  _QuickAction(icon: Icons.description_rounded, label: 'Belge', color: AppColors.documentColor, onTap: _editMode ? null : () => context.go(AppRoutes.documents)),
                                ]),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // ── Modüller ────────────────────────────────────
                        if (_editMode || kAllDashboardItems.where((id) => id.startsWith('module_') && visible.contains(id)).isNotEmpty) ...[
                          const Text('Modüller', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          const SizedBox(height: 12),
                        ],

                        _ModuleItem(id: 'module_hayvan', editMode: _editMode, visible: visible, layout: layout,
                          child: _ModuleCard(icon: Icons.pets_rounded, title: 'Hayvan Yönetimi', subtitle: 'Sürü takibi, aşı, süt verimi', color: AppColors.animalColor, onTap: _editMode ? null : () => context.go(AppRoutes.animals))),
                        _ModuleItem(id: 'module_arac', editMode: _editMode, visible: visible, layout: layout,
                          child: _ModuleCard(icon: Icons.agriculture_rounded, title: 'Araç & Makineler', subtitle: 'Yakıt, bakım, evrak takibi', color: AppColors.vehicleColor, onTap: _editMode ? null : () => context.go(AppRoutes.vehicles))),
                        _ModuleItem(id: 'module_yapi', editMode: _editMode, visible: visible, layout: layout,
                          child: _ModuleCard(icon: Icons.home_work_rounded, title: 'Yapılar & Enerji', subtitle: 'Ahır, depo, enerji tüketimi', color: AppColors.buildingColor, onTap: _editMode ? null : () => context.go(AppRoutes.buildings))),
                        _ModuleItem(id: 'module_stok', editMode: _editMode, visible: visible, layout: layout,
                          child: _ModuleCard(icon: Icons.inventory_2_rounded, title: 'Stok Yönetimi', subtitle: 'Yem, ilaç, ekipman takibi', color: AppColors.stockColor, onTap: _editMode ? null : () => context.go(AppRoutes.stock))),
                        _ModuleItem(id: 'module_raporlar', editMode: _editMode, visible: visible, layout: layout,
                          child: _ModuleCard(icon: Icons.bar_chart_rounded, title: 'Raporlar', subtitle: 'Gider, enerji, sağlık raporları', color: AppColors.info, onTap: _editMode ? null : () => context.go(AppRoutes.reports))),

                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),

          // ── Edit mode overlay banner ──────────────────────────────
          if (_editMode)
            ColoredBox(
              color: AppColors.primary,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20, right: 20, top: 12,
                  bottom: 12 + MediaQuery.of(context).padding.bottom,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app_rounded, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Kartlara dokunarak göster/gizle',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: _cancelEditMode,
                      child: const Text('İptal', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _exitEditMode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Tamam', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    } catch (_, __) {
      // Provider hatası olursa boş scaffold döndür, uygulama çökmez
      return const Scaffold(backgroundColor: AppColors.background);
    }
  }
}

// ── Header yardımcıları ───────────────────────────────────
class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  const _HeaderBtn({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  final int count;
  const _NotificationButton({required this.count});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.announcements),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _HeaderBtn(icon: Icons.notifications_outlined),
          if (count > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                    color: AppColors.error, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Header Delegate (pinned header + collapsing strip) ────
class _DashboardHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double statusBarHeight;
  final double stripHeight;
  final AsyncValue<WeatherData?> weather;
  final WidgetRef ref;
  final int totalNotifications;
  final AppSettings settings;
  final bool editMode;
  final VoidCallback onEditToggle;

  static const double _headerH = 116.0;

  const _DashboardHeaderDelegate({
    required this.statusBarHeight,
    required this.stripHeight,
    required this.weather,
    required this.ref,
    required this.totalNotifications,
    required this.settings,
    required this.editMode,
    required this.onEditToggle,
  });

  @override
  double get minExtent => statusBarHeight + _headerH;

  @override
  double get maxExtent => statusBarHeight + _headerH + stripHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final double visible = (stripHeight - shrinkOffset).clamp(0.0, stripHeight);
    final double opacity = stripHeight > 0 ? visible / stripHeight : 0.0;

    return Stack(
      clipBehavior: Clip.hardEdge,
      fit: StackFit.expand,
      children: [
        // Gradient arka plan — tüm alanı kaplar
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryLight],
            ),
          ),
        ),
        // Sabit başlık — her zaman görünür
        Positioned(
          top: statusBarHeight,
          left: 0,
          right: 0,
          height: _headerH,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  const Text('Çiftlik Yönetim',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                  const Spacer(),
                  _NotificationButton(count: totalNotifications),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.reports),
                    child: _HeaderBtn(icon: Icons.bar_chart_rounded),
                  ),
                  const SizedBox(width: 8),
                  _ProfileMenuButton(settings: settings),
                ]),
                const SizedBox(height: 4),
                Text('${_greeting()} 👋',
                    style: const TextStyle(fontSize: 13, color: Colors.white70)),
                const SizedBox(height: 2),
                weather.maybeWhen(
                  data: (d) => d != null
                      ? Text('Bugün Hava ${_weatherTr(d.weatherCode)} ${d.iconEmoji}',
                          style: const TextStyle(fontSize: 13, color: Colors.white70))
                      : const SizedBox.shrink(),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
        // Hava şeridi — scroll edince yukarı kaybolur
        if (stripHeight > 0 && visible > 0)
          Positioned(
            top: statusBarHeight + _headerH,
            left: 0,
            right: 0,
            height: stripHeight,
            child: Opacity(
              opacity: opacity,
              child: _WeatherForecastStrip(weather: weather, ref: ref),
            ),
          ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _DashboardHeaderDelegate oldDelegate) =>
      oldDelegate.statusBarHeight != statusBarHeight ||
      oldDelegate.stripHeight != stripHeight ||
      oldDelegate.totalNotifications != totalNotifications ||
      oldDelegate.weather != weather ||
      oldDelegate.settings != settings ||
      oldDelegate.editMode != editMode;
}

// ── Kaydırınca kaybolan hava tahmin şeridi ────────────────
class _WeatherForecastStrip extends StatelessWidget {
  final AsyncValue<WeatherData?> weather;
  final WidgetRef ref;
  const _WeatherForecastStrip({required this.weather, required this.ref});

  @override
  Widget build(BuildContext context) {
    return weather.maybeWhen(
      data: (data) => data == null ? _buildEmpty(context) : _buildLoaded(context, data),
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final error = await ref.read(weatherProvider.notifier).loadByGPS();
                if (error != null && context.mounted) {
                  // GPS başarısız → şehir seç
                  _openCitySheet(context);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(children: [
                  Icon(Icons.my_location_rounded, size: 13, color: Colors.white70),
                  SizedBox(width: 6),
                  Text('Konum ile hava durumunu getir',
                      style: TextStyle(fontSize: 12, color: Colors.white70)),
                  Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.white38),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _openCitySheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.search_rounded, size: 14, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoaded(BuildContext context, WeatherData data) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _openCitySheet(context),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.place_rounded, size: 11, color: Colors.white70),
                      const SizedBox(width: 2),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 90),
                        child: Text(data.city,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.edit_rounded, size: 9, color: Colors.white38),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Text(data.iconEmoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text('${data.temp.round()}°',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(_weatherTr(data.weatherCode),
                        style: const TextStyle(fontSize: 11, color: Colors.white60),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  _StatChip(icon: Icons.water_drop_rounded, label: '${data.humidity}%', iconColor: const Color(0xFF90CAF9)),
                  const SizedBox(width: 8),
                  _StatChip(icon: Icons.air_rounded, label: '${data.windSpeed.round()}km/s', iconColor: Colors.white60),
                ],
              ),
            ),
            Container(height: 0.5, color: Colors.white.withValues(alpha: 0.15)),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ...List.generate(data.forecast.length.clamp(0, 5), (i) => Expanded(
                    child: _MiniDayCell(day: data.forecast[i], isToday: i == 0),
                  )),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => _WeatherDetailSheet(data: data),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCitySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CitySearchSheet(ref: ref),
    );
  }
}

class _MiniDayCell extends StatelessWidget {
  final DayForecast day;
  final bool isToday;
  const _MiniDayCell({required this.day, required this.isToday});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(day.dayName,
            style: TextStyle(
              fontSize: 8,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              color: isToday ? Colors.white : Colors.white60,
            )),
        const SizedBox(height: 2),
        Text(day.emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 1),
        Text('${day.maxTemp.round()}°',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isToday ? Colors.white : Colors.white70,
            )),
        if (day.chanceOfRain > 0)
          Text('💧${day.chanceOfRain.round()}%',
              style: const TextStyle(fontSize: 8, color: Colors.white54)),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  const _StatChip(
      {required this.icon, required this.label, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: iconColor),
      const SizedBox(width: 3),
      Text(label,
          style: const TextStyle(fontSize: 12, color: Colors.white70)),
    ]);
  }
}


// ── Detaylı Hava Durumu Sheet ─────────────────────────────
class _WeatherDetailSheet extends StatefulWidget {
  final WeatherData data;
  const _WeatherDetailSheet({required this.data});

  @override
  State<_WeatherDetailSheet> createState() => _WeatherDetailSheetState();
}

class _WeatherDetailSheetState extends State<_WeatherDetailSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedDayIndex = 0;

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

  void _openHourlyForDay(int index) {
    setState(() => _selectedDayIndex = index);
    _tabController.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.87,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Tutma çubuğu
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Mevcut koşullar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Text(data.iconEmoji, style: const TextStyle(fontSize: 48)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data.city,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      if (data.description.isNotEmpty)
                        Text(data.description,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(data.tempStr,
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.water_drop_rounded,
                          size: 12, color: AppColors.info),
                      const SizedBox(width: 2),
                      Text('${data.humidity}%',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(width: 8),
                      const Icon(Icons.air_rounded,
                          size: 12, color: AppColors.textTertiary),
                      const SizedBox(width: 2),
                      Text('${data.windSpeed.round()} km/s',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ]),
                  ],
                ),
              ],
            ),
          ),
          // Tab bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 4)
                ],
              ),
              tabs: const [
                Tab(text: 'Haftalık'),
                Tab(text: 'Saatlik'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _WeeklyView(
                    forecast: data.forecast,
                    onDayTap: _openHourlyForDay),
                _HourlyView(
                  forecast: data.forecast,
                  selectedDayIndex: _selectedDayIndex,
                  onDayChanged: (i) =>
                      setState(() => _selectedDayIndex = i),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyView extends StatelessWidget {
  final List<DayForecast> forecast;
  final void Function(int) onDayTap;
  const _WeeklyView({required this.forecast, required this.onDayTap});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: forecast.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => GestureDetector(
        onTap: () => onDayTap(i),
        child: _WeeklyDayRow(day: forecast[i], isToday: i == 0),
      ),
    );
  }
}

class _WeeklyDayRow extends StatelessWidget {
  final DayForecast day;
  final bool isToday;
  const _WeeklyDayRow({required this.day, required this.isToday});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(children: [
        SizedBox(
          width: 50,
          child: Text(
            day.dayName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              color: isToday ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ),
        Text(day.emoji, style: const TextStyle(fontSize: 22)),
        const Spacer(),
        if (day.chanceOfRain > 0) ...[
          const Icon(Icons.water_drop_rounded, size: 12, color: AppColors.info),
          const SizedBox(width: 2),
          Text('${day.chanceOfRain.round()}%',
              style: const TextStyle(fontSize: 12, color: AppColors.info)),
          const SizedBox(width: 8),
        ],
        const Icon(Icons.air_rounded, size: 12, color: AppColors.textTertiary),
        const SizedBox(width: 2),
        Text('${day.windSpeedKmph.round()} km/s',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(width: 12),
        Text('${day.minTemp.round()}°',
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('–',
                style: TextStyle(color: AppColors.textTertiary))),
        Text('${day.maxTemp.round()}°',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(width: 6),
        const Icon(Icons.chevron_right_rounded,
            size: 14, color: AppColors.textTertiary),
      ]),
    );
  }
}

class _HourlyView extends StatelessWidget {
  final List<DayForecast> forecast;
  final int selectedDayIndex;
  final void Function(int) onDayChanged;
  const _HourlyView({
    required this.forecast,
    required this.selectedDayIndex,
    required this.onDayChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedDay = forecast[selectedDayIndex];
    return Column(
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: forecast.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final isSelected = i == selectedDayIndex;
              return GestureDetector(
                onTap: () => onDayChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    forecast[i].dayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        if (selectedDay.hourly.isEmpty)
          const Expanded(
            child: Center(
              child: Text('Saatlik veri yok',
                  style: TextStyle(color: AppColors.textTertiary)),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: selectedDay.hourly.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) =>
                  _HourlyRow(hourly: selectedDay.hourly[i]),
            ),
          ),
      ],
    );
  }
}

class _HourlyRow extends StatelessWidget {
  final HourlyForecast hourly;
  const _HourlyRow({required this.hourly});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        SizedBox(
          width: 44,
          child: Text(hourly.timeLabel,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ),
        Text(hourly.emoji, style: const TextStyle(fontSize: 22)),
        const Spacer(),
        if (hourly.chanceOfRain > 0) ...[
          const Icon(Icons.water_drop_rounded,
              size: 12, color: AppColors.info),
          const SizedBox(width: 2),
          Text('${hourly.chanceOfRain.round()}%',
              style: const TextStyle(fontSize: 12, color: AppColors.info)),
          const SizedBox(width: 8),
        ],
        const Icon(Icons.air_rounded,
            size: 12, color: AppColors.textTertiary),
        const SizedBox(width: 2),
        Text('${hourly.windSpeedKmph.round()} km/s',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(width: 12),
        Text('${hourly.temp.round()}°',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
      ]),
    );
  }
}

// ── Şehir Arama Sheet ─────────────────────────────────────
class _CitySearchSheet extends StatefulWidget {
  final WidgetRef ref;
  const _CitySearchSheet({required this.ref});

  @override
  State<_CitySearchSheet> createState() => _CitySearchSheetState();
}

class _CitySearchSheetState extends State<_CitySearchSheet> {
  final _ctrl = TextEditingController();
  List<CitySuggestion> _suggestions = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await fetchCitySuggestions(value);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _loading = false;
        });
      }
    });
  }

  void _select(String cityName) {
    Navigator.pop(context);
    widget.ref.read(weatherProvider.notifier).setCity(cityName);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Konum',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Konum girin...',
                prefixIcon: const Icon(Icons.location_city_rounded),
                suffixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2)),
                      )
                    : null,
              ),
              textCapitalization: TextCapitalization.words,
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) _select(v.trim());
              },
            ),
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.textTertiary.withValues(alpha: 0.2)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final s = _suggestions[i];
                      return ListTile(
                        leading: const Icon(Icons.place_rounded,
                            size: 18, color: AppColors.primary),
                        title: Text(s.displayName,
                            style: const TextStyle(fontSize: 13)),
                        dense: true,
                        onTap: () => _select(s.name),
                      );
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final error = await widget.ref
                        .read(weatherProvider.notifier)
                        .loadByGPS();
                    if (error != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(error),
                          backgroundColor: AppColors.warning,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.my_location_rounded, size: 16),
                  label: const Text('Konumum'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (_ctrl.text.trim().isNotEmpty) {
                      _select(_ctrl.text.trim());
                    }
                  },
                  child: const Text('Tamam'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Profil Dropdown ───────────────────────────────────────
class _ProfileMenuButton extends ConsumerWidget {
  final AppSettings settings;
  const _ProfileMenuButton({required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: AppColors.white,
      elevation: 8,
      onSelected: (value) {
        switch (value) {
          case 'profile':
            context.push(AppRoutes.profile);
            break;
          case 'settings':
            context.push(AppRoutes.settings);
            break;
          case 'farmMembers':
            context.push(AppRoutes.farmMembers);
            break;
          case 'saleTransfers':
            context.push(AppRoutes.saleTransfers);
            break;
          case 'superAdmin':
            context.push(AppRoutes.superAdmin);
            break;
          case 'logout':
            _showLogoutDialog(context, ref);
            break;
        }
      },
      itemBuilder: (_) {
        final isSuperAdmin = ref.read(isSuperAdminProvider);
        final farmAsync = ref.read(activeFarmProvider);
        final farmName = farmAsync.value?.name ?? settings.farmName;
        return [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                settings.ownerName.isNotEmpty
                    ? settings.ownerName
                    : 'Kullanıcı',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              Text(farmName,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              const Divider(height: 1),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'profile',
          child: Row(children: [
            Icon(Icons.person_rounded, size: 18, color: AppColors.primary),
            SizedBox(width: 10),
            Text('Profilim'),
          ]),
        ),
        const PopupMenuItem(
          value: 'settings',
          child: Row(children: [
            Icon(Icons.settings_rounded,
                size: 18, color: AppColors.textSecondary),
            SizedBox(width: 10),
            Text('Ayarlar'),
          ]),
        ),
        const PopupMenuItem(
          value: 'farmMembers',
          child: Row(children: [
            Icon(Icons.group_rounded, size: 18, color: AppColors.primary),
            SizedBox(width: 10),
            Text('Çiftlik Üyeleri'),
          ]),
        ),
        const PopupMenuItem(
          value: 'saleTransfers',
          child: Row(children: [
            Icon(Icons.swap_horiz_rounded, size: 18, color: AppColors.secondary),
            SizedBox(width: 10),
            Text('Transfer Talepleri'),
          ]),
        ),
        if (isSuperAdmin)
          const PopupMenuItem(
            value: 'superAdmin',
            child: Row(children: [
              Icon(Icons.admin_panel_settings_rounded, size: 18, color: AppColors.warning),
              SizedBox(width: 10),
              Text('Süper Admin'),
            ]),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: Row(children: [
            Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
            SizedBox(width: 10),
            Text('Çıkış Yap', style: TextStyle(color: AppColors.error)),
          ]),
        ),
      ];},
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.account_circle_rounded,
            color: Colors.white, size: 22),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Uygulamadan çıkmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authRepositoryProvider).signOut();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
  }
}

// ── Yardımcı Widget'lar ───────────────────────────────────
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _QuickAction(
      {required this.icon,
      required this.label,
      required this.color,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color),
                textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;
  const _ModuleCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.color,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ]),
        ),
        const Icon(Icons.chevron_right_rounded,
            color: AppColors.textTertiary, size: 20),
      ]),
    );
  }
}

// ── Düzenlenebilir widget sarmalayıcı ─────────────────────
class _EditableWidget extends StatelessWidget {
  final String id;
  final bool editMode;
  final bool visible;
  final VoidCallback onToggle;
  final Widget child;

  const _EditableWidget({
    required this.id,
    required this.editMode,
    required this.visible,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!editMode) return child;

    return GestureDetector(
      onTap: onToggle,
      child: Stack(
        children: [
          AnimatedOpacity(
            opacity: visible ? 1.0 : 0.35,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(child: child),
          ),
          Positioned(
            top: 6, right: 6,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26, height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: visible ? AppColors.primary : Colors.grey.shade400,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
              ),
              child: Icon(
                visible ? Icons.check_rounded : Icons.add_rounded,
                color: Colors.white, size: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Modül item sarmalayıcı ────────────────────────────────
class _ModuleItem extends StatelessWidget {
  final String id;
  final bool editMode;
  final Set<String> visible;
  final DashboardLayoutNotifier layout;
  final Widget child;

  const _ModuleItem({
    required this.id,
    required this.editMode,
    required this.visible,
    required this.layout,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isVisible = visible.contains(id);
    if (!editMode && !isVisible) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _EditableWidget(
        id: id,
        editMode: editMode,
        visible: isVisible,
        onToggle: () => layout.toggle(id),
        child: child,
      ),
    );
  }
}

class _DashboardNotifCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  const _DashboardNotifCard({required this.notification, required this.onTap});

  Color get _color {
    switch (notification.type) {
      case NotificationType.vaccination: return AppColors.warning;
      case NotificationType.pregnancy: return AppColors.animalColor;
      case NotificationType.maintenance: return AppColors.secondary;
      case NotificationType.lowStock: return AppColors.error;
      case NotificationType.insurance: return AppColors.info;
      default: return AppColors.textSecondary;
    }
  }

  IconData get _icon {
    switch (notification.type) {
      case NotificationType.vaccination: return Icons.vaccines_rounded;
      case NotificationType.pregnancy: return Icons.child_care_rounded;
      case NotificationType.maintenance: return Icons.build_rounded;
      case NotificationType.lowStock: return Icons.inventory_2_rounded;
      case NotificationType.insurance: return Icons.security_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _color.withOpacity(0.25)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: _color.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
              child: Icon(_icon, color: _color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  Text(notification.body, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: _color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
              child: Text(
                notification.priority == NotificationPriority.critical ? 'Kritik' :
                notification.priority == NotificationPriority.high ? 'Yüksek' : 'Orta',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
