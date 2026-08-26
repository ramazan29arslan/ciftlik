import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/di/providers.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/entities/animal.dart';
import '../../data/models/animal_model.dart';
import '../providers/animals_provider.dart';
import '../../../farms/presentation/providers/farm_provider.dart';
import '../../../transfers/data/services/sale_transfer_service.dart';

class AnimalFormPage extends ConsumerStatefulWidget {
  final String? animalId;
  final String? presetMotherId;
  final String? presetFatherId;
  final String? presetNotes;
  const AnimalFormPage({super.key, this.animalId, this.presetMotherId, this.presetFatherId, this.presetNotes});

  @override
  ConsumerState<AnimalFormPage> createState() => _AnimalFormPageState();
}

class _AnimalFormPageState extends ConsumerState<AnimalFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _tagController = TextEditingController();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();
  final _buyerEmailController = TextEditingController();

  String _selectedType = 'Sığır';
  AnimalGender? _selectedGender;
  AnimalStatus _selectedStatus = AnimalStatus.active;
  DateTime? _birthDate;
  XFile? _selectedImage;
  String? _existingPhotoUrl;
  bool _isLoading = false;

  // Aile ağacı
  String? _selectedMotherId;
  String? _selectedFatherId;

  // Tohumlama
  InseminationType? _inseminationType;
  DateTime? _inseminationDate;
  String? _inseminationMateId;

  bool get _isEditing => widget.animalId != null;

  bool get _isFemaleBreedingMammal =>
      _selectedGender == AnimalGender.female &&
      ['Sığır', 'Koyun', 'Keçi', 'At', 'Domuz', 'Manda', 'Deve'].contains(_selectedType);

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final animal = ref.read(animalDetailProvider(widget.animalId!));
      if (animal != null) {
        _tagController.text = animal.tagNumber;
        _nameController.text = animal.name ?? '';
        _breedController.text = animal.breed ?? '';
        _weightController.text = animal.weight?.toString() ?? '';
        _notesController.text = animal.notes ?? '';
        _buyerEmailController.text = animal.buyerEmail ?? '';
        _selectedType = animal.type;
        _selectedGender = animal.gender;
        _selectedStatus = animal.status;
        _birthDate = animal.birthDate;
        _existingPhotoUrl = animal.photoUrl;
        _selectedMotherId = animal.motherId;
        _selectedFatherId = animal.fatherId;
        _inseminationType = animal.inseminationType;
        _inseminationDate = animal.inseminationDate;
        _inseminationMateId = animal.inseminationMateId;
      }
    }
    if (!_isEditing) {
      _selectedMotherId = widget.presetMotherId;
      _selectedFatherId = widget.presetFatherId;
      if (widget.presetNotes != null && widget.presetNotes!.isNotEmpty) {
        _notesController.text = widget.presetNotes!;
      }
    }
  }

  @override
  void dispose() {
    _tagController.dispose();
    _nameController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    _buyerEmailController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => _birthDate = date);
  }

  Future<void> _pickInseminationDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _inseminationDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date != null) setState(() => _inseminationDate = date);
  }

  Future<void> _pickImage(BuildContext context) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await picker.pickImage(source: source, imageQuality: 80);
    if (file != null && mounted) setState(() => _selectedImage = file);
  }

  Future<String?> _uploadPhotoIfNeeded(String animalId) async {
    if (_selectedImage == null) return null;
    final farmId = ref.read(activeFarmIdProvider) ?? ref.read(currentUserIdProvider) ?? '';
    return ref.read(storageServiceProvider).uploadAnimalPhoto(
      farmId: farmId,
      animalId: animalId,
      imageFile: File(_selectedImage!.path),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        final existing = ref.read(animalDetailProvider(widget.animalId!));
        if (existing != null) {
          String? newPhotoUrl = existing.photoUrl;
          if (_selectedImage != null) {
            newPhotoUrl = await _uploadPhotoIfNeeded(existing.id);
          }
          final updated = existing.copyWith(
            tagNumber: _tagController.text.trim(),
            name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
            type: _selectedType,
            breed: _breedController.text.trim().isEmpty ? null : _breedController.text.trim(),
            birthDate: _birthDate,
            gender: _selectedGender,
            status: _selectedStatus,
            weight: double.tryParse(_weightController.text),
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            clearNotes: _notesController.text.trim().isEmpty,
            buyerEmail: _buyerEmailController.text.trim().isEmpty ? null : _buyerEmailController.text.trim(),
            clearBuyerEmail: _buyerEmailController.text.trim().isEmpty,
            photoUrl: newPhotoUrl,
            motherId: _selectedMotherId,
            fatherId: _selectedFatherId,
            clearMotherId: _selectedMotherId == null,
            clearFatherId: _selectedFatherId == null,
            inseminationType: _inseminationType,
            inseminationDate: _inseminationDate,
            inseminationMateId: _inseminationMateId,
            clearInsemination: _inseminationType == null,
            updatedAt: DateTime.now(),
          );
          await ref.read(animalsNotifierProvider.notifier).update(updated);
          // Satış transferi oluştur
          if (updated.buyerEmail != null && updated.buyerEmail!.isNotEmpty) {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              final userId = ref.read(currentUserIdProvider) ?? user.uid;
              final farmId = ref.read(activeFarmIdProvider) ?? userId;
              try {
                await SaleTransferService().createAnimalTransfer(
                  animal: updated,
                  sellerUserId: userId,
                  sellerFarmId: farmId,
                  sellerDisplayName: user.displayName ?? user.email ?? userId,
                  sellerEmail: user.email ?? '',
                );
              } catch (_) {}
            }
          }
        }
      } else {
        final userId = ref.read(currentUserIdProvider) ?? '';
        final farmId = ref.read(activeFarmIdProvider) ?? userId;
        final animalId = const Uuid().v4();
        String? photoUrl;
        if (_selectedImage != null) {
          photoUrl = await ref.read(storageServiceProvider).uploadAnimalPhoto(
            farmId: farmId,
            animalId: animalId,
            imageFile: File(_selectedImage!.path),
          );
        }
        final animal = createAnimal(
          tagNumber: _tagController.text.trim(),
          name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
          type: _selectedType,
          breed: _breedController.text.trim().isEmpty ? null : _breedController.text.trim(),
          birthDate: _birthDate,
          gender: _selectedGender,
          status: _selectedStatus,
          weight: double.tryParse(_weightController.text),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          buyerEmail: _buyerEmailController.text.trim().isEmpty ? null : _buyerEmailController.text.trim(),
          photoUrl: photoUrl,
          motherId: _selectedMotherId,
          fatherId: _selectedFatherId,
          inseminationType: _inseminationType,
          inseminationDate: _inseminationDate,
          inseminationMateId: _inseminationMateId,
          userId: userId,
          animalId: animalId,
        );
        await ref.read(animalsNotifierProvider.notifier).add(animal);
        // Satış transferi oluştur
        if (animal.buyerEmail != null && animal.buyerEmail!.isNotEmpty) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            try {
              await SaleTransferService().createAnimalTransfer(
                animal: animal,
                sellerUserId: userId,
                sellerFarmId: farmId,
                sellerDisplayName: user.displayName ?? user.email ?? userId,
                sellerEmail: user.email ?? '',
              );
            } catch (_) {}
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Hayvan güncellendi' : 'Hayvan eklendi'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allAnimals = ref.watch(animalsNotifierProvider);
    final females = allAnimals.where((a) =>
      a.gender == AnimalGender.female &&
      a.type == _selectedType &&
      (_isEditing ? a.id != widget.animalId : true)
    ).toList();
    final males = allAnimals.where((a) =>
      a.gender == AnimalGender.male &&
      a.type == _selectedType &&
      (_isEditing ? a.id != widget.animalId : true)
    ).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Hayvan Düzenle' : 'Hayvan Ekle'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo picker
              Center(
                child: GestureDetector(
                  onTap: () => _pickImage(context),
                  child: Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primaryPale, width: 2),
                      image: _selectedImage != null
                          ? DecorationImage(image: FileImage(File(_selectedImage!.path)), fit: BoxFit.cover)
                          : (_existingPhotoUrl != null
                              ? DecorationImage(image: NetworkImage(_existingPhotoUrl!), fit: BoxFit.cover)
                              : null),
                    ),
                    child: (_selectedImage == null && _existingPhotoUrl == null)
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_rounded, color: AppColors.primaryMedium, size: 28),
                              SizedBox(height: 4),
                              Text('Fotoğraf', style: TextStyle(fontSize: 11, color: AppColors.primaryMedium)),
                            ],
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              _SectionLabel('Temel Bilgiler'),
              const SizedBox(height: 12),

              TextFormField(
                controller: _tagController,
                decoration: const InputDecoration(labelText: 'Küpe Numarası *', prefixIcon: Icon(Icons.tag_rounded)),
                validator: (v) => v == null || v.isEmpty ? 'Küpe numarası gerekli' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'İsim (opsiyonel)', prefixIcon: Icon(Icons.label_rounded)),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(labelText: 'Tür *', prefixIcon: Icon(Icons.category_rounded)),
                items: AppConstants.animalTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedType = v!;
                    // Tür değişince anne/baba/eş seçimini temizle
                    _selectedMotherId = null;
                    _selectedFatherId = null;
                    _inseminationMateId = null;
                  });
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _breedController,
                decoration: const InputDecoration(labelText: 'Cins', prefixIcon: Icon(Icons.pets_rounded)),
              ),
              const SizedBox(height: 12),

              // Gender
              Row(
                children: [
                  Expanded(child: _GenderButton(label: 'Erkek', icon: Icons.male_rounded, isSelected: _selectedGender == AnimalGender.male, onTap: () => setState(() { _selectedGender = AnimalGender.male; _inseminationType = null; _inseminationDate = null; _inseminationMateId = null; }))),
                  const SizedBox(width: 12),
                  Expanded(child: _GenderButton(label: 'Dişi', icon: Icons.female_rounded, isSelected: _selectedGender == AnimalGender.female, onTap: () => setState(() => _selectedGender = AnimalGender.female))),
                ],
              ),
              const SizedBox(height: 12),

              // Birth date
              GestureDetector(
                onTap: _pickBirthDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Row(
                    children: [
                      const Icon(Icons.cake_rounded, color: AppColors.textSecondary, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        _birthDate != null ? '${_birthDate!.day}.${_birthDate!.month}.${_birthDate!.year}' : 'Doğum Tarihi',
                        style: TextStyle(fontSize: 14, color: _birthDate != null ? AppColors.textPrimary : AppColors.textTertiary),
                      ),
                      if (_birthDate != null) ...[
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _birthDate = null),
                          child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textTertiary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Ağırlık (kg)', prefixIcon: Icon(Icons.monitor_weight_rounded), suffixText: 'kg'),
              ),
              const SizedBox(height: 24),

              // ── Aile Ağacı ───────────────────────────────────────
              _SectionLabel('Aile Bağlantısı (Opsiyonel)'),
              const SizedBox(height: 12),

              // Anne seçimi
              _AnimalPickerField(
                label: 'Anne',
                icon: Icons.female_rounded,
                iconColor: Colors.pink,
                selectedId: _selectedMotherId,
                animals: females,
                onChanged: (id) => setState(() => _selectedMotherId = id),
                onClear: () => setState(() => _selectedMotherId = null),
              ),
              const SizedBox(height: 12),

              // Baba seçimi
              _AnimalPickerField(
                label: 'Baba',
                icon: Icons.male_rounded,
                iconColor: Colors.blue,
                selectedId: _selectedFatherId,
                animals: males,
                onChanged: (id) => setState(() => _selectedFatherId = id),
                onClear: () => setState(() => _selectedFatherId = null),
              ),
              const SizedBox(height: 24),

              // ── Tohumlama (sadece dişi memeliler) ────────────────
              if (_isFemaleBreedingMammal) ...[
                _SectionLabel('Tohumlama'),
                const SizedBox(height: 12),

                // Tohumlama türü seçimi
                Row(
                  children: [
                    Expanded(
                      child: _SelectionButton(
                        label: 'Suni Tohumlama',
                        icon: Icons.science_rounded,
                        isSelected: _inseminationType == InseminationType.artificial,
                        onTap: () => setState(() {
                          _inseminationType = _inseminationType == InseminationType.artificial ? null : InseminationType.artificial;
                          _inseminationMateId = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SelectionButton(
                        label: 'Doğal Tohumlama',
                        icon: Icons.favorite_rounded,
                        isSelected: _inseminationType == InseminationType.natural,
                        onTap: () => setState(() {
                          _inseminationType = _inseminationType == InseminationType.natural ? null : InseminationType.natural;
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Tohumlama tarihi
                if (_inseminationType != null) ...[
                  GestureDetector(
                    onTap: _pickInseminationDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: _inseminationDate != null ? AppColors.primarySurface : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _inseminationDate != null ? AppColors.primary : AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.event_rounded, color: _inseminationDate != null ? AppColors.primary : AppColors.textSecondary, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            _inseminationDate != null
                                ? 'Tohumlama: ${_inseminationDate!.day}.${_inseminationDate!.month}.${_inseminationDate!.year}'
                                : 'Tohumlama Tarihi Seç',
                            style: TextStyle(
                              fontSize: 14,
                              color: _inseminationDate != null ? AppColors.primary : AppColors.textTertiary,
                              fontWeight: _inseminationDate != null ? FontWeight.w500 : FontWeight.w400,
                            ),
                          ),
                          if (_inseminationDate != null) ...[
                            const Spacer(),
                            GestureDetector(
                              onTap: () => setState(() => _inseminationDate = null),
                              child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textTertiary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Tahmini doğum tarihi göster
                  if (_inseminationDate != null) Builder(
                    builder: (_) {
                      final days = gestationDays(_selectedType);
                      final expected = _inseminationDate!.add(Duration(days: days));
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.child_care_rounded, color: AppColors.success, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Tahmini doğum: ${expected.day}.${expected.month}.${expected.year} ($days gün)',
                              style: const TextStyle(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Doğal tohumlama: erkek hayvan seçimi
                  if (_inseminationType == InseminationType.natural) ...[
                    _AnimalPickerField(
                      label: 'Tohumlayan Erkek Hayvan',
                      icon: Icons.male_rounded,
                      iconColor: Colors.blue,
                      selectedId: _inseminationMateId,
                      animals: males,
                      extraOption: 'Diğer',
                      onChanged: (id) => setState(() => _inseminationMateId = id),
                      onClear: () => setState(() => _inseminationMateId = null),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ],

              _SectionLabel('Durum'),
              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                children: AnimalStatus.values.map((status) {
                  final selected = _selectedStatus == status;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedStatus = status),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primarySurface : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: selected ? AppColors.primary : AppColors.border),
                      ),
                      child: Text(status.statusLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: selected ? AppColors.primary : AppColors.textSecondary)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              if (_selectedStatus == AnimalStatus.sold || _selectedStatus == AnimalStatus.transferred) ...[
                _SectionLabel('Satış Bilgileri'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _buyerEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Alıcı E-posta (opsiyonel)',
                    prefixIcon: Icon(Icons.email_rounded),
                    hintText: 'ornek@mail.com',
                  ),
                ),
                const SizedBox(height: 24),
              ],
              _SectionLabel('Notlar'),
              const SizedBox(height: 12),

              TextFormField(
                controller: _notesController,
                maxLines: 4,
                minLines: 1,
                decoration: const InputDecoration(
                  labelText: 'Notlar (opsiyonel)',
                  alignLabelWithHint: true,
                  hintText: 'Hayvan hakkında notlar...',
                ),
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 32),

              AppButton(
                label: _isEditing ? 'Güncelle' : 'Kaydet',
                onPressed: _save,
                isLoading: _isLoading,
                icon: Icons.save_rounded,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hayvan seçici widget ──────────────────────────────────────
class _AnimalPickerField extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final String? selectedId;
  final List<AnimalModel> animals;
  final String? extraOption; // örn: 'Diğer'
  final ValueChanged<String?> onChanged;
  final VoidCallback onClear;

  const _AnimalPickerField({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.selectedId,
    required this.animals,
    this.extraOption,
    required this.onChanged,
    required this.onClear,
  });

  String _displayName(String id) {
    if (extraOption != null && id == '__other__') return extraOption!;
    try {
      final a = animals.firstWhere((a) => a.id == id);
      return a.name != null ? '${a.name} (${a.tagNumber})' : a.tagNumber;
    } catch (_) {
      return id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedId != null;

    return GestureDetector(
      onTap: () {
        if (animals.isEmpty && extraOption == null) return;
        showModalBottomSheet(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                if (animals.isEmpty && extraOption == null)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Sürüde uygun hayvan bulunamadı', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ...animals.map((a) => ListTile(
                  leading: Icon(icon, color: iconColor),
                  title: Text(a.name ?? a.tagNumber),
                  subtitle: a.name != null ? Text(a.tagNumber) : null,
                  trailing: selectedId == a.id ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    onChanged(a.id);
                  },
                )),
                if (extraOption != null)
                  ListTile(
                    leading: Icon(icon, color: iconColor.withOpacity(0.6)),
                    title: Text(extraOption!),
                    trailing: selectedId == '__other__' ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      onChanged('__other__');
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: hasSelection ? AppColors.primarySurface : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hasSelection ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: hasSelection ? iconColor : AppColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasSelection ? _displayName(selectedId!) : '$label Seç (Opsiyonel)',
                style: TextStyle(
                  fontSize: 14,
                  color: hasSelection ? AppColors.textPrimary : AppColors.textTertiary,
                  fontWeight: hasSelection ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
            if (hasSelection)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textTertiary),
              )
            else
              const Icon(Icons.expand_more_rounded, color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SelectionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  const _SelectionButton({required this.label, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySurface : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.textSecondary, size: 18),
            const SizedBox(width: 6),
            Flexible(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isSelected ? AppColors.primary : AppColors.textSecondary), textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel(this.title);
  @override
  Widget build(BuildContext context) => Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary));
}

class _GenderButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  const _GenderButton({required this.label, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySurface : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.textSecondary, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isSelected ? AppColors.primary : AppColors.textSecondary)),
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
