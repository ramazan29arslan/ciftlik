import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_search_bar.dart';
import '../../domain/entities/animal.dart';
import '../providers/animals_provider.dart';
import '../../../../core/utils/animal_icon_helper.dart';

extension on AnimalGender {
  String get label => this == AnimalGender.male ? 'Erkek' : 'Dişi';
}

const _demoFarmId = 'demo';

class AnimalsListPage extends ConsumerStatefulWidget {
  const AnimalsListPage({super.key});

  @override
  ConsumerState<AnimalsListPage> createState() => _AnimalsListPageState();
}

class _AnimalsListPageState extends ConsumerState<AnimalsListPage> {
  @override
  Widget build(BuildContext context) {
    final animals = ref.watch(filteredAnimalsProvider(_demoFarmId));
    final filter = ref.watch(animalsFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hayvanlar'),
        actions: [
          Consumer(builder: (_, ref, __) {
            final active = ref.watch(animalsFilterProvider).hasActiveFilters;
            return Stack(
              alignment: Alignment.center,
              children: [
                IconButton(icon: const Icon(Icons.tune_rounded), onPressed: _showFilterSheet),
                if (active)
                  Positioned(
                    top: 10, right: 10,
                    child: Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/animals/add'),
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: AppSearchBar(
              hint: 'Küpe no, isim veya tür ara...',
              onChanged: (q) {
                ref.read(animalsFilterProvider.notifier).state =
                    filter.copyWith(searchQuery: q);
              },
            ),
          ),
          if (filter.hasActiveFilters)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (filter.type != null) ...[
                      _FilterChip(label: filter.type!, onRemove: () {
                        ref.read(animalsFilterProvider.notifier).update((f) => AnimalsFilter(status: f.status, gender: f.gender, ageRange: f.ageRange, searchQuery: f.searchQuery));
                      }),
                      const SizedBox(width: 8),
                    ],
                    if (filter.status != null) ...[
                      _FilterChip(label: filter.status!.statusLabel, onRemove: () {
                        ref.read(animalsFilterProvider.notifier).update((f) => AnimalsFilter(type: f.type, gender: f.gender, ageRange: f.ageRange, searchQuery: f.searchQuery));
                      }),
                      const SizedBox(width: 8),
                    ],
                    if (filter.gender != null) ...[
                      _FilterChip(label: filter.gender!.label, onRemove: () {
                        ref.read(animalsFilterProvider.notifier).update((f) => AnimalsFilter(type: f.type, status: f.status, ageRange: f.ageRange, searchQuery: f.searchQuery));
                      }),
                      const SizedBox(width: 8),
                    ],
                    if (filter.ageRange != null)
                      _FilterChip(label: '${filter.ageRange} yaş', onRemove: () {
                        ref.read(animalsFilterProvider.notifier).update((f) => AnimalsFilter(type: f.type, status: f.status, gender: f.gender, searchQuery: f.searchQuery));
                      }),
                  ],
                ),
              ),
            ),
          Expanded(
            child: animals.isEmpty
                ? AppEmptyState(
                    icon: Icons.pets_rounded,
                    title: 'Hayvan bulunamadı',
                    subtitle: 'Yeni hayvan eklemek için + butonuna dokunun',
                    actionLabel: 'Hayvan Ekle',
                    onAction: () => context.go('/animals/add'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: animals.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final animal = animals[index];
                      return _AnimalCard(
                        animal: animal,
                        onTap: () => context.go('/animals/detail/${animal.id}'),
                        onDelete: () => _confirmDelete(animal.id, animal.displayName),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hayvanı Sil'),
        content: Text('$name silinecek. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          TextButton(
            onPressed: () {
              // Hayvanı sil
              ref.read(animalsNotifierProvider.notifier).delete(id);
              // İlgili aşı kayıtlarını sil
              ref.read(vaccinationsNotifierProvider.notifier).deleteByAnimal(id);
              // İlgili süt kayıtlarını sil
              ref.read(milkRecordsNotifierProvider.notifier).deleteByAnimal(id);
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

  void _showFilterSheet() {
    final current = ref.read(animalsFilterProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AnimalFilterSheet(
        initialFilter: current,
        onApply: (filter) {
          ref.read(animalsFilterProvider.notifier).state = filter.copyWith(searchQuery: current.searchQuery);
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

class _AnimalCard extends StatelessWidget {
  final dynamic animal;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AnimalCard({required this.animal, required this.onTap, required this.onDelete});

  Color get _statusColor {
    switch (animal.status as AnimalStatus) {
      case AnimalStatus.active: return AppColors.success;
      case AnimalStatus.sold: return AppColors.info;
      case AnimalStatus.dead: return AppColors.error;
      case AnimalStatus.transferred: return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 52, height: 52,
              color: animal.photoUrl != null
                  ? AppColors.primarySurface
                  : AnimalIconHelper.getColor(animal.type as String).withOpacity(0.15),
              child: animal.photoUrl != null
                  ? _AnimalPhoto(photoUrl: animal.photoUrl!)
                  : Center(
                      child: Text(
                        AnimalIconHelper.getEmoji(animal.type as String),
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(animal.displayName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                    AppBadge(label: animal.statusLabel, color: _statusColor.withOpacity(0.12), textColor: _statusColor),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${animal.type}${animal.breed != null ? ' • ${animal.breed}' : ''}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.tag_rounded, size: 12, color: AppColors.textTertiary),
                    const SizedBox(width: 3),
                    Text(animal.tagNumber, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                    if (animal.birthDate != null) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.cake_rounded, size: 12, color: AppColors.textTertiary),
                      const SizedBox(width: 3),
                      Text(AppDateUtils.formatAge(animal.birthDate!), style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textTertiary, size: 20),
            onSelected: (v) {
              if (v == 'edit') context.go('/animals/edit/${animal.id}');
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 18), SizedBox(width: 8), Text('Düzenle')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, size: 18, color: AppColors.error), SizedBox(width: 8), Text('Sil', style: TextStyle(color: AppColors.error))])),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnimalPhoto extends StatelessWidget {
  final String photoUrl;
  const _AnimalPhoto({required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final isLocal = photoUrl.startsWith('/') || photoUrl.startsWith('file://');
    if (isLocal) {
      return Image.file(
        File(photoUrl.replaceFirst('file://', '')),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.pets_rounded, color: AppColors.primaryMedium, size: 26),
      );
    }
    return Image.network(
      photoUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Icon(Icons.pets_rounded, color: AppColors.primaryMedium, size: 26),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _FilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.primaryPale)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary)),
          const SizedBox(width: 6),
          GestureDetector(onTap: onRemove, child: const Icon(Icons.close_rounded, size: 14, color: AppColors.primary)),
        ],
      ),
    );
  }
}

class _AnimalFilterSheet extends StatefulWidget {
  final AnimalsFilter initialFilter;
  final Function(AnimalsFilter) onApply;
  const _AnimalFilterSheet({required this.initialFilter, required this.onApply});

  @override
  State<_AnimalFilterSheet> createState() => _AnimalFilterSheetState();
}

class _AnimalFilterSheetState extends State<_AnimalFilterSheet> {
  late String? _selectedType;
  late AnimalStatus? _selectedStatus;
  late AnimalGender? _selectedGender;
  late String? _selectedAge;

  static const _types = ['Sığır', 'Koyun', 'Keçi', 'At', 'Tavuk', 'Diğer'];
  static const _ageRanges = ['0-1', '1-3', '3-7', '7+'];
  static const _ageLabels = ['0–1 yaş', '1–3 yaş', '3–7 yaş', '7+ yaş'];

  @override
  void initState() {
    super.initState();
    _selectedType   = widget.initialFilter.type;
    _selectedStatus = widget.initialFilter.status;
    _selectedGender = widget.initialFilter.gender;
    _selectedAge    = widget.initialFilter.ageRange;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('Filtrele', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() { _selectedType = null; _selectedStatus = null; _selectedGender = null; _selectedAge = null; }),
                child: const Text('Temizle'),
              ),
            ]),
            const SizedBox(height: 16),

            // Tür
            _SectionLabel('Tür'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: _types.map((t) => _Chip(
              label: t,
              selected: _selectedType == t,
              onTap: () => setState(() => _selectedType = _selectedType == t ? null : t),
            )).toList()),
            const SizedBox(height: 16),

            // Cinsiyet
            _SectionLabel('Cinsiyet'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: AnimalGender.values.map((g) => _Chip(
              label: g.label,
              selected: _selectedGender == g,
              onTap: () => setState(() => _selectedGender = _selectedGender == g ? null : g),
            )).toList()),
            const SizedBox(height: 16),

            // Yaş
            _SectionLabel('Yaş'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: List.generate(_ageRanges.length, (i) => _Chip(
              label: _ageLabels[i],
              selected: _selectedAge == _ageRanges[i],
              onTap: () => setState(() => _selectedAge = _selectedAge == _ageRanges[i] ? null : _ageRanges[i]),
            ))),
            const SizedBox(height: 16),

            // Durum
            _SectionLabel('Durum'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: AnimalStatus.values.map((s) => _Chip(
              label: s.statusLabel,
              selected: _selectedStatus == s,
              onTap: () => setState(() => _selectedStatus = _selectedStatus == s ? null : s),
            )).toList()),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: () => widget.onApply(AnimalsFilter(
                  type: _selectedType,
                  status: _selectedStatus,
                  gender: _selectedGender,
                  ageRange: _selectedAge,
                )),
                child: const Text('Uygula'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected ? [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2))] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, size: 14, color: Colors.white),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on AnimalStatus {
  String get statusLabel {
    switch (this) {
      case AnimalStatus.active: return 'Aktif';
      case AnimalStatus.sold: return 'Satıldı';
      case AnimalStatus.dead: return 'Öldü';
      case AnimalStatus.transferred: return 'Satıldı';
    }
  }
}
