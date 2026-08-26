import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../farms/presentation/providers/farm_provider.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/activity_log_widget.dart';
import '../../domain/entities/animal.dart';
import '../../data/models/animal_model.dart';
import '../providers/animals_provider.dart';
import '../../../../core/utils/animal_icon_helper.dart';
import '../../../../core/models/document_model.dart';
import '../../../documents/presentation/widgets/entity_documents_section.dart';

class AnimalDetailPage extends ConsumerWidget {
  final String animalId;
  const AnimalDetailPage({super.key, required this.animalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animal = ref.watch(animalDetailProvider(animalId));
    if (animal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hayvan Detayı')),
        body: const AppEmptyState(icon: Icons.pets_rounded, title: 'Hayvan bulunamadı'),
      );
    }
    return _AnimalDetailView(animal: animal);
  }
}

class _AnimalDetailView extends ConsumerStatefulWidget {
  final dynamic animal;
  const _AnimalDetailView({required this.animal});

  @override
  ConsumerState<_AnimalDetailView> createState() => _AnimalDetailViewState();
}

class _AnimalDetailViewState extends ConsumerState<_AnimalDetailView>
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
    switch (widget.animal.status as AnimalStatus) {
      case AnimalStatus.active: return AppColors.success;
      case AnimalStatus.sold: return AppColors.info;
      case AnimalStatus.dead: return AppColors.error;
      case AnimalStatus.transferred: return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.animal;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.primary,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: Colors.white),
                onPressed: () => context.go('/animals/edit/${a.id}'),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  a.photoUrl != null
                      ? Image.network(a.photoUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryLight])),
                            child: Center(
                              child: Text(
                                AnimalIconHelper.getEmoji(a.type),
                                style: const TextStyle(fontSize: 72),
                              ),
                            ),
                          ))
                      : Container(
                          decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryLight])),
                          child: Center(
                            child: Text(
                              AnimalIconHelper.getEmoji(a.type),
                              style: const TextStyle(fontSize: 72),
                            ),
                          ),
                        ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16, left: 16, right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            AppBadge(label: a.statusLabel, color: _statusColor.withOpacity(0.25), textColor: Colors.white),
                            const SizedBox(width: 8),
                            Text('${a.type}${a.breed != null ? ' • ${a.breed}' : ''}', style: const TextStyle(fontSize: 13, color: Colors.white70)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
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
            _GeneralTab(animal: a),
            _HistoryTab(
              animalId: a.id,
              onEditVaccination: (v) => _showVaccinationSheet(context, existing: v),
              onEditMilk: (r) => _showMilkSheet(context, existing: r),
            ),
            _LogTab(animalId: a.id),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  static const _animalDocs = [
    DocType.veterinerRaporu,
    DocType.saglikSertifikasi,
    DocType.pasaport,
    DocType.diger,
  ];

  void _showAddSheet(BuildContext ctx) {
    final Animal animal = widget.animal;
    final canMilk = animal.gender == AnimalGender.female &&
        ['Sığır', 'Koyun', 'Keçi', 'Manda', 'Deve'].contains(animal.type);
    final canInseminate = animal.isFemaleBreedingMammal;
    final entityName = animal.name ?? animal.tagNumber;

    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Kayıt Ekle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _SheetItem(icon: Icons.vaccines_rounded, label: 'Aşı Kaydı', color: AppColors.warning, onTap: () {
              Navigator.pop(sheetCtx);
              Future.microtask(() => _showVaccinationSheet(ctx));
            }),
            if (canMilk)
              _SheetItem(icon: Icons.water_drop_rounded, label: 'Süt Kaydı', color: AppColors.info, onTap: () {
                Navigator.pop(sheetCtx);
                Future.microtask(() => _showMilkSheet(ctx));
              }),
            if (canInseminate)
              _SheetItem(
                icon: Icons.favorite_rounded,
                label: animal.inseminationType != null ? 'Tohumlama Güncelle' : 'Tohumlama Kaydı',
                color: Colors.purple,
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Future.microtask(() => _showInseminationSheet(ctx));
                },
              ),
            _SheetItem(
              icon: Icons.description_rounded,
              label: 'Belge Ekle',
              color: AppColors.primary,
              onTap: () {
                Navigator.pop(sheetCtx);
                Future.microtask(() => showDocumentAddForm(
                  ctx, ref,
                  entityId: animal.id,
                  entityType: EntityType.animal,
                  entityName: entityName,
                  availableDocTypes: _animalDocs,
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showInseminationSheet(BuildContext ctx) {
    final Animal animal = widget.animal;

    // Mevcut değerlerle başla
    InseminationType selectedType = animal.inseminationType ?? InseminationType.natural;
    DateTime inseminationDate = animal.inseminationDate ?? DateTime.now();
    String? mateId = animal.inseminationMateId;

    // Suni tohumlama controller'ları
    final vetCtrl    = TextEditingController(text: animal.inseminationVet ?? '');
    final semenCtrl  = TextEditingController(text: animal.semenBrand ?? '');

    // Doğal-Diğer controller'ları
    final otherNameCtrl  = TextEditingController(text: animal.otherMateName ?? '');
    final otherAgeCtrl   = TextEditingController(text: animal.otherMateAge ?? '');
    final otherOwnerCtrl = TextEditingController(text: animal.otherMateOwner ?? '');

    // Erkek hayvanları çek (aynı tür)
    final allAnimals  = ref.read(animalsNotifierProvider);
    final maleAnimals = allAnimals
        .where((a) => a.id != animal.id && a.gender == AnimalGender.male && a.type == animal.type)
        .toList();

    // Sürüde erkek yoksa Diğer'i otomatik seç
    if (maleAnimals.isEmpty && (mateId == null || !maleAnimals.any((m) => m.id == mateId))) {
      mateId = animal.inseminationMateId ?? '__other__';
    }

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx2, setS) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx2).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Center(child: Text(
                    animal.inseminationType != null ? 'Tohumlama Güncelle' : 'Tohumlama Kaydı',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  )),
                  const SizedBox(height: 20),

                  // ── Tohumlama Türü ──────────────────────
                  const Text('Tohumlama Türü', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setS(() => selectedType = InseminationType.natural),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: selectedType == InseminationType.natural ? Colors.purple : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedType == InseminationType.natural ? Colors.purple : AppColors.divider,
                              width: selectedType == InseminationType.natural ? 2 : 1,
                            ),
                          ),
                          child: Column(children: [
                            Icon(Icons.pets_rounded, color: selectedType == InseminationType.natural ? Colors.white : AppColors.textSecondary, size: 24),
                            const SizedBox(height: 6),
                            Text('Doğal', style: TextStyle(fontWeight: FontWeight.w600, color: selectedType == InseminationType.natural ? Colors.white : AppColors.textPrimary)),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setS(() {
                          selectedType = InseminationType.artificial;
                          mateId = null;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: selectedType == InseminationType.artificial ? Colors.purple : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedType == InseminationType.artificial ? Colors.purple : AppColors.divider,
                              width: selectedType == InseminationType.artificial ? 2 : 1,
                            ),
                          ),
                          child: Column(children: [
                            Icon(Icons.science_rounded, color: selectedType == InseminationType.artificial ? Colors.white : AppColors.textSecondary, size: 24),
                            const SizedBox(height: 6),
                            Text('Suni', style: TextStyle(fontWeight: FontWeight.w600, color: selectedType == InseminationType.artificial ? Colors.white : AppColors.textPrimary)),
                          ]),
                        ),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // ── Tohumlama Tarihi ────────────────────
                  const Text('Tohumlama Tarihi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: sheetCtx2,
                        initialDate: inseminationDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setS(() => inseminationDate = d);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Text('${inseminationDate.day}.${inseminationDate.month}.${inseminationDate.year}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                        const Spacer(),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                      ]),
                    ),
                  ),

                  // ── Tahmini Doğum (preview) ─────────────
                  Builder(builder: (_) {
                    final gestation = gestationDays(animal.type);
                    if (gestation == 0) return const SizedBox.shrink();
                    final expected = inseminationDate.add(Duration(days: gestation));
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          const Icon(Icons.child_care_rounded, color: Colors.purple, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Tahmini doğum: ${expected.day}.${expected.month}.${expected.year}  ($gestation gün)',
                            style: const TextStyle(fontSize: 12, color: Colors.purple, fontWeight: FontWeight.w500),
                          ),
                        ]),
                      ),
                    );
                  }),

                  // ── Suni tohumlama ek alanları ──────────
                  if (selectedType == InseminationType.artificial) ...[
                    const SizedBox(height: 20),
                    const Text('Suni Tohumlama Bilgileri', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: semenCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tohumun Markası / Kodu',
                        prefixIcon: Icon(Icons.science_rounded),
                        hintText: 'Örn: ABS, Semex, Alta...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: vetCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Veteriner Adı',
                        prefixIcon: Icon(Icons.medical_services_rounded),
                        hintText: 'Tohumlamayı yapan veteriner',
                      ),
                    ),
                  ],

                  // ── Erkek Hayvan (sadece doğal) ─────────
                  if (selectedType == InseminationType.natural) ...[
                    const SizedBox(height: 20),
                    const Text('Erkek Hayvan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    // Liste (boşsa hiçbir şey gösterilmez)
                    ...maleAnimals.map((m) {
                      final isSelected = mateId == m.id;
                      return GestureDetector(
                        onTap: () => setS(() => mateId = isSelected ? null : m.id),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.purple.withValues(alpha: 0.08) : AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? Colors.purple : AppColors.divider,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(children: [
                            Text(AnimalIconHelper.getEmoji(m.type), style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(m.name ?? m.tagNumber, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                if (m.name != null)
                                  Text(m.tagNumber, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ]),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded, color: Colors.purple, size: 20),
                          ]),
                        ),
                      );
                    }),
                    // Diğer seçeneği — her zaman göster
                    GestureDetector(
                      onTap: () => setS(() => mateId = '__other__'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: mateId == '__other__' ? Colors.purple.withValues(alpha: 0.08) : AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: mateId == '__other__' ? Colors.purple : AppColors.divider,
                            width: mateId == '__other__' ? 1.5 : 1,
                          ),
                        ),
                        child: Row(children: [
                          const Icon(Icons.more_horiz_rounded, color: AppColors.textSecondary, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(child: Text('Diğer (listede yok)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                          if (mateId == '__other__')
                            const Icon(Icons.check_circle_rounded, color: Colors.purple, size: 20),
                        ]),
                      ),
                    ),

                    // Diğer seçiliyse ek bilgi alanları
                    if (mateId == '__other__') ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
                        ),
                        child: Column(children: [
                          TextField(
                            controller: otherNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Erkek Hayvanın Adı',
                              prefixIcon: Icon(Icons.label_rounded),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: otherAgeCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Yaşı',
                              prefixIcon: Icon(Icons.cake_rounded),
                              isDense: true,
                              hintText: 'Örn: 3 yaşında',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: otherOwnerCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Sahibi',
                              prefixIcon: Icon(Icons.person_rounded),
                              isDense: true,
                              hintText: 'Hayvan sahibinin adı',
                            ),
                          ),
                        ]),
                      ),
                    ],
                  ],

                  const SizedBox(height: 24),

                  // ── Kaydet butonu ───────────────────────
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final effectiveMateId = selectedType == InseminationType.natural
                            ? (mateId ?? '__other__')
                            : null;
                        final updated = (animal as AnimalModel).copyWith(
                          inseminationType: selectedType,
                          inseminationDate: inseminationDate,
                          inseminationMateId: effectiveMateId,
                          // Suni alanları
                          inseminationVet: selectedType == InseminationType.artificial
                              ? (vetCtrl.text.trim().isEmpty ? null : vetCtrl.text.trim())
                              : null,
                          semenBrand: selectedType == InseminationType.artificial
                              ? (semenCtrl.text.trim().isEmpty ? null : semenCtrl.text.trim())
                              : null,
                          // Doğal-Diğer alanları
                          otherMateName: (selectedType == InseminationType.natural && mateId == '__other__')
                              ? (otherNameCtrl.text.trim().isEmpty ? null : otherNameCtrl.text.trim())
                              : null,
                          otherMateAge: (selectedType == InseminationType.natural && mateId == '__other__')
                              ? (otherAgeCtrl.text.trim().isEmpty ? null : otherAgeCtrl.text.trim())
                              : null,
                          otherMateOwner: (selectedType == InseminationType.natural && mateId == '__other__')
                              ? (otherOwnerCtrl.text.trim().isEmpty ? null : otherOwnerCtrl.text.trim())
                              : null,
                        );
                        await ref.read(animalsNotifierProvider.notifier).update(updated);
                        if (mounted) {
                          Navigator.pop(sheetCtx);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Tohumlama kaydı güncellendi'),
                              backgroundColor: Colors.purple,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check_rounded, color: Colors.white),
                      label: const Text('Kaydet', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),

                  // ── Kaydı Sil (mevcut varsa) ────────────
                  if (animal.inseminationType != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () async {
                          final updated = (animal as AnimalModel).copyWith(clearInsemination: true);
                          await ref.read(animalsNotifierProvider.notifier).update(updated);
                          if (mounted) {
                            Navigator.pop(sheetCtx);
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Tohumlama kaydı silindi')),
                            );
                          }
                        },
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                        label: const Text('Kaydı Sil', style: TextStyle(color: AppColors.error)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      vetCtrl.dispose();
      semenCtrl.dispose();
      otherNameCtrl.dispose();
      otherAgeCtrl.dispose();
      otherOwnerCtrl.dispose();
    });
  }

  void _showVaccinationSheet(BuildContext ctx, {AnimalVaccinationModel? existing}) {
    final nameCtrl = TextEditingController(text: existing?.vaccineName ?? '');
    final vetCtrl  = TextEditingController(text: existing?.veterinarian ?? '');
    final costCtrl = TextEditingController(text: existing?.cost?.toString() ?? '');
    DateTime vacDate  = existing?.vaccinationDate ?? DateTime.now();
    DateTime? nextDate = existing?.nextVaccinationDate;
    final isEdit = existing != null;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx2, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx2).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text(isEdit ? 'Aşı Kaydını Düzenle' : 'Aşı Kaydı',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Aşı Adı *', prefixIcon: Icon(Icons.vaccines_rounded))),
                const SizedBox(height: 12),
                TextField(controller: vetCtrl, decoration: const InputDecoration(labelText: 'Veteriner', prefixIcon: Icon(Icons.medical_services_rounded))),
                const SizedBox(height: 12),
                TextField(controller: costCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Maliyet (₺)', prefixIcon: Icon(Icons.payments_rounded))),
                const SizedBox(height: 4),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_rounded, color: AppColors.textSecondary),
                  title: Text('Aşı Tarihi: ${vacDate.day}.${vacDate.month}.${vacDate.year}'),
                  onTap: () async {
                    final d = await showDatePicker(context: sheetCtx2, initialDate: vacDate, firstDate: DateTime(2000), lastDate: DateTime(2030));
                    if (d != null) setS(() => vacDate = d);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_rounded, color: AppColors.textSecondary),
                  title: Text(nextDate != null ? 'Sonraki: ${nextDate!.day}.${nextDate!.month}.${nextDate!.year}' : 'Sonraki Aşı Tarihi (opsiyonel)'),
                  trailing: nextDate != null ? GestureDetector(onTap: () => setS(() => nextDate = null), child: const Icon(Icons.close_rounded, size: 18)) : null,
                  onTap: () async {
                    final d = await showDatePicker(context: sheetCtx2, initialDate: nextDate ?? DateTime.now().add(const Duration(days: 30)), firstDate: DateTime.now(), lastDate: DateTime(2035));
                    if (d != null) setS(() => nextDate = d);
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      if (nameCtrl.text.trim().isEmpty) return;
                      if (isEdit) {
                        final updated = existing.copyWith(
                          vaccineName: nameCtrl.text.trim(),
                          vaccinationDate: vacDate,
                          nextVaccinationDate: nextDate,
                          clearNextDate: nextDate == null,
                          veterinarian: vetCtrl.text.trim().isEmpty ? null : vetCtrl.text.trim(),
                          clearVeterinarian: vetCtrl.text.trim().isEmpty,
                          cost: double.tryParse(costCtrl.text),
                          clearCost: costCtrl.text.trim().isEmpty,
                        );
                        ref.read(vaccinationsNotifierProvider.notifier).update(updated);
                      } else {
                        final v = AnimalVaccinationModel(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          animalId: widget.animal.id,
                          vaccineName: nameCtrl.text.trim(),
                          vaccinationDate: vacDate,
                          nextVaccinationDate: nextDate,
                          veterinarian: vetCtrl.text.trim().isEmpty ? null : vetCtrl.text.trim(),
                          cost: double.tryParse(costCtrl.text),
                        );
                        ref.read(vaccinationsNotifierProvider.notifier).add(v);
                      }
                      Navigator.pop(sheetCtx);
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text(isEdit ? 'Aşı kaydı güncellendi' : 'Aşı kaydı eklendi'),
                        backgroundColor: AppColors.success,
                      ));
                    },
                    child: Text(isEdit ? 'Güncelle' : 'Kaydet'),
                  ),
                ),
                if (isEdit) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () async {
                        Navigator.pop(sheetCtx);
                        await ref.read(vaccinationsNotifierProvider.notifier).delete(existing.id);
                        if (mounted) ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Aşı kaydı silindi')),
                        );
                      },
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                      label: const Text('Kaydı Sil', style: TextStyle(color: AppColors.error)),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      nameCtrl.dispose();
      vetCtrl.dispose();
      costCtrl.dispose();
    });
  }

  void _showMilkSheet(BuildContext ctx, {MilkRecordModel? existing}) {
    final isEdit = existing != null;
    final morningCtrl = TextEditingController(text: existing?.morningAmount.toString() ?? '');
    final eveningCtrl = TextEditingController(text: existing?.eveningAmount.toString() ?? '');
    final notesCtrl   = TextEditingController(text: existing?.notes ?? '');
    DateTime milkDate = existing?.date ?? DateTime.now();

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx2, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx2).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text(isEdit ? 'Süt Kaydını Düzenle' : 'Süt Kaydı',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                // Tarih seçici
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_rounded, color: AppColors.textSecondary),
                  title: Text('Tarih: ${milkDate.day}.${milkDate.month}.${milkDate.year}'),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: sheetCtx2,
                      initialDate: milkDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setS(() => milkDate = d);
                  },
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: morningCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Sabah (L)', prefixIcon: Icon(Icons.wb_sunny_rounded)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: eveningCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Akşam (L)', prefixIcon: Icon(Icons.nights_stay_rounded)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Not (opsiyonel)', prefixIcon: Icon(Icons.notes_rounded)),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      final morning = double.tryParse(morningCtrl.text) ?? 0;
                      final evening = double.tryParse(eveningCtrl.text) ?? 0;
                      if (isEdit) {
                        final updated = existing.copyWith(
                          date: milkDate,
                          morningAmount: morning,
                          eveningAmount: evening,
                          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                        );
                        ref.read(milkRecordsNotifierProvider.notifier).update(updated);
                      } else {
                        final r = MilkRecordModel(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          animalId: widget.animal.id,
                          date: milkDate,
                          morningAmount: morning,
                          eveningAmount: evening,
                          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                        );
                        ref.read(milkRecordsNotifierProvider.notifier).add(r);
                      }
                      Navigator.pop(sheetCtx);
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text(isEdit
                            ? 'Süt kaydı güncellendi'
                            : 'Süt kaydı: ${(morning + evening).toStringAsFixed(1)} L'),
                        backgroundColor: AppColors.success,
                      ));
                    },
                    child: Text(isEdit ? 'Güncelle' : 'Kaydet'),
                  ),
                ),
                if (isEdit) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () async {
                        Navigator.pop(sheetCtx);
                        await ref.read(milkRecordsNotifierProvider.notifier).delete(existing.id);
                        if (mounted) ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Süt kaydı silindi')),
                        );
                      },
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                      label: const Text('Kaydı Sil', style: TextStyle(color: AppColors.error)),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      morningCtrl.dispose();
      eveningCtrl.dispose();
      notesCtrl.dispose();
    });
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
  final String animalId;
  const _LogTab({required this.animalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logService = ref.read(activityLogServiceProvider);
    return ActivityLogWidget(logService: logService, entityId: animalId);
  }
}

// ── Genel Tab ─────────────────────────────────────────────
class _GeneralTab extends ConsumerWidget {
  final dynamic animal;
  const _GeneralTab({required this.animal});

  static const _animalDocs = [
    DocType.veterinerRaporu,
    DocType.saglikSertifikasi,
    DocType.pasaport,
    DocType.diger,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAnimals = ref.watch(animalsNotifierProvider);
    final Animal a = animal;

    // Aile ağacı
    AnimalModel? mother;
    AnimalModel? father;
    if (a.motherId != null && a.motherId!.isNotEmpty) {
      try { mother = allAnimals.firstWhere((x) => x.id == a.motherId); } catch (_) {}
    }
    if (a.fatherId != null && a.fatherId!.isNotEmpty) {
      try { father = allAnimals.firstWhere((x) => x.id == a.fatherId); } catch (_) {}
    }
    final offspring = allAnimals.where((x) => x.motherId == a.id || x.fatherId == a.id).toList();

    // Tohumlayan erkek
    AnimalModel? mate;
    if (a.inseminationMateId != null && a.inseminationMateId != '__other__' && a.inseminationMateId!.isNotEmpty) {
      try { mate = allAnimals.firstWhere((x) => x.id == a.inseminationMateId); } catch (_) {}
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader('Kimlik Bilgileri'),
                _InfoRow(label: 'Küpe No', value: a.tagNumber),
                _InfoRow(label: 'İsim', value: a.name ?? '-'),
                _InfoRow(label: 'Tür', value: a.type),
                _InfoRow(label: 'Cins', value: a.breed ?? '-'),
                _InfoRow(label: 'Cinsiyet', value: a.genderLabel),
                _InfoRow(label: 'Durum', value: a.statusLabel, isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader('Fiziksel Bilgiler'),
                _InfoRow(label: 'Doğum Tarihi', value: AppDateUtils.formatDate(a.birthDate)),
                _InfoRow(label: 'Yaş', value: a.birthDate != null ? AppDateUtils.formatAge(a.birthDate!) : '-'),
                _InfoRow(label: 'Ağırlık', value: a.weight != null ? '${a.weight} kg' : '-', isLast: true),
              ],
            ),
          ),

          // ── Tohumlama Bilgisi ──────────────────────────────
          if (a.inseminationType != null) ...[
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader('Tohumlama'),
                  _InfoRow(
                    label: 'Tür',
                    value: a.inseminationType == InseminationType.artificial ? 'Suni Tohumlama' : 'Doğal Tohumlama',
                  ),
                  if (a.inseminationDate != null)
                    _InfoRow(label: 'Tarih', value: AppDateUtils.formatDate(a.inseminationDate)),
                  // Suni tohumlama ek bilgileri
                  if (a.inseminationType == InseminationType.artificial) ...[
                    if (a.semenBrand != null && a.semenBrand!.isNotEmpty)
                      _InfoRow(label: 'Tohumun Markası', value: a.semenBrand!),
                    if (a.inseminationVet != null && a.inseminationVet!.isNotEmpty)
                      _InfoRow(label: 'Veteriner', value: a.inseminationVet!),
                  ],
                  // Doğal tohumlama erkek hayvan bilgileri
                  if (a.inseminationType == InseminationType.natural) ...[
                    if (mate != null)
                      _InfoRow(label: 'Erkek Hayvan', value: mate.name != null ? '${mate.name} (${mate.tagNumber})' : mate.tagNumber)
                    else if (a.inseminationMateId == '__other__') ...[
                      if (a.otherMateName != null && a.otherMateName!.isNotEmpty)
                        _InfoRow(label: 'Erkek Hayvan', value: a.otherMateName!),
                      if (a.otherMateAge != null && a.otherMateAge!.isNotEmpty)
                        _InfoRow(label: 'Yaşı', value: a.otherMateAge!),
                      if (a.otherMateOwner != null && a.otherMateOwner!.isNotEmpty)
                        _InfoRow(label: 'Sahibi', value: a.otherMateOwner!),
                      if (a.otherMateName == null && a.otherMateAge == null && a.otherMateOwner == null)
                        const _InfoRow(label: 'Erkek Hayvan', value: 'Diğer'),
                    ],
                  ],
                  if (a.expectedBirthDate != null) ...[
                    _InfoRow(
                      label: 'Tahmini Doğum',
                      value: AppDateUtils.formatDate(a.expectedBirthDate),
                    ),
                    Builder(builder: (_) {
                      final today = DateTime.now();
                      final exp = a.expectedBirthDate!;
                      final diff = DateTime(exp.year, exp.month, exp.day)
                          .difference(DateTime(today.year, today.month, today.day))
                          .inDays;
                      if (diff < 0) {
                        return const _InfoRow(label: 'Durum', value: 'Doğum gerçekleşti', isLast: true);
                      }
                      return _InfoRow(
                        label: 'Kalan Süre',
                        value: diff == 0 ? 'Bugün!' : '$diff gün kaldı',
                        isLast: true,
                        highlight: diff <= 15,
                      );
                    }),
                  ] else
                    const _InfoRow(label: 'Tarih', value: '-', isLast: true),
                ],
              ),
            ),
          ],

          // ── Aile Ağacı ─────────────────────────────────────
          if (mother != null || father != null || offspring.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader('Aile Ağacı'),
                  if (mother != null)
                    _FamilyTile(label: 'Anne', animal: mother, color: Colors.pink),
                  if (father != null)
                    _FamilyTile(label: 'Baba', animal: father, color: Colors.blue),
                  if (offspring.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Yavrular', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    ),
                    ...offspring.map((o) => _FamilyTile(
                      label: o.motherId == a.id ? 'Yavru (dişiden)' : 'Yavru (babadan)',
                      animal: o,
                      color: AppColors.primaryMedium,
                    )),
                  ],
                ],
              ),
            ),
          ],

          if ((a.status == AnimalStatus.sold || a.status == AnimalStatus.transferred) && a.buyerEmail != null) ...[
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Satış Bilgisi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.email_rounded, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(a.buyerEmail!, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (a.notes != null) ...[
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Notlar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Text(
                    a.notes!,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4, fontStyle: FontStyle.italic),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          AppCard(
            child: EntityDocumentsSection(
              entityId: a.id,
              entityType: EntityType.animal,
              entityName: a.name ?? a.tagNumber,
              availableDocTypes: _animalDocs,
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _FamilyTile extends StatelessWidget {
  final String label;
  final AnimalModel animal;
  final Color color;
  const _FamilyTile({required this.label, required this.animal, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            clipBehavior: Clip.hardEdge,
            child: animal.photoUrl != null
                ? Image.network(
                    animal.photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.pets_rounded, color: color, size: 18),
                  )
                : Icon(Icons.pets_rounded, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text(
                animal.name != null ? '${animal.name} (${animal.tagNumber})' : animal.tagNumber,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => context.go('/animals/${animal.id}'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Detay', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Geçmiş Tab ────────────────────────────────────────────
class _HistoryTab extends ConsumerWidget {
  final String animalId;
  final void Function(AnimalVaccinationModel) onEditVaccination;
  final void Function(MilkRecordModel) onEditMilk;

  const _HistoryTab({
    required this.animalId,
    required this.onEditVaccination,
    required this.onEditMilk,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaccinations = ref.watch(animalVaccinationsProvider(animalId));
    final milkRecords = ref.watch(milkRecordsProvider(animalId));

    final allEvents = <_HistoryEvent>[];

    for (final v in vaccinations) {
      allEvents.add(_HistoryEvent(
        date: v.vaccinationDate,
        title: v.vaccineName,
        subtitle: v.veterinarian ?? 'Aşı yapıldı',
        icon: Icons.vaccines_rounded,
        color: AppColors.warning,
        extra: v.cost != null ? CurrencyUtils.format(v.cost!) : null,
        nextDate: v.nextVaccinationDate,
        vaccination: v,
      ));
    }

    for (final m in milkRecords) {
      allEvents.add(_HistoryEvent(
        date: m.date,
        title: 'Süt Kaydı',
        subtitle: 'Sabah: ${m.morningAmount}L  Akşam: ${m.eveningAmount}L',
        icon: Icons.water_drop_rounded,
        color: AppColors.info,
        extra: '${m.totalAmount.toStringAsFixed(1)} L',
        milkRecord: m,
      ));
    }

    allEvents.sort((a, b) => b.date.compareTo(a.date));

    if (allEvents.isEmpty) {
      return const AppEmptyState(
        icon: Icons.history_rounded,
        title: 'Geçmiş kaydı yok',
        subtitle: 'Aşı ve süt kayıtları burada görünür',
      );
    }

    return ListView.separated(
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
                        const SizedBox(width: 4),
                        // Edit/Delete popup
                        PopupMenuButton<String>(
                          iconSize: 18,
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.more_vert_rounded, color: AppColors.textTertiary, size: 18),
                          onSelected: (action) {
                            if (action == 'edit') {
                              if (e.vaccination != null) onEditVaccination(e.vaccination!);
                              if (e.milkRecord != null) onEditMilk(e.milkRecord!);
                            } else if (action == 'delete') {
                              if (e.vaccination != null) {
                                ref.read(vaccinationsNotifierProvider.notifier).delete(e.vaccination!.id);
                              }
                              if (e.milkRecord != null) {
                                ref.read(milkRecordsNotifierProvider.notifier).delete(e.milkRecord!.id);
                              }
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 16), SizedBox(width: 8), Text('Düzenle')])),
                            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error), SizedBox(width: 8), Text('Sil', style: TextStyle(color: AppColors.error))])),
                          ],
                        ),
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
                          Text(
                            'Sonraki: ${AppDateUtils.formatDate(e.nextDate)} • ${AppDateUtils.formatDaysUntil(e.nextDate)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppDateUtils.isExpiringSoon(e.nextDate) ? AppColors.warning : AppColors.textTertiary,
                              fontWeight: AppDateUtils.isExpiringSoon(e.nextDate) ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryEvent {
  final DateTime date;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? extra;
  final DateTime? nextDate;
  final AnimalVaccinationModel? vaccination;
  final MilkRecordModel? milkRecord;

  const _HistoryEvent({
    required this.date, required this.title, required this.subtitle,
    required this.icon, required this.color, this.extra, this.nextDate,
    this.vaccination, this.milkRecord,
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
  final String label; final String value; final bool isLast; final bool highlight;
  const _InfoRow({required this.label, required this.value, this.isLast = false, this.highlight = false});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
            Expanded(child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: highlight ? AppColors.warning : AppColors.textPrimary), textAlign: TextAlign.right)),
          ],
        ),
      ),
      if (!isLast) const Divider(height: 1, color: AppColors.divider),
    ],
  );
}
