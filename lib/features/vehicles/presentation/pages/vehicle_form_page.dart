import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/vehicle_brands.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/entities/vehicle.dart';
import '../../data/models/vehicle_model.dart';
import '../providers/vehicles_provider.dart';
import '../../../../core/di/providers.dart';

class VehicleFormPage extends ConsumerStatefulWidget {
  final String? vehicleId;
  const VehicleFormPage({super.key, this.vehicleId});

  @override
  ConsumerState<VehicleFormPage> createState() => _VehicleFormPageState();
}

class _VehicleFormPageState extends ConsumerState<VehicleFormPage> {
  final _formKey = GlobalKey<FormState>();

  // Temel
  String _selectedType = 'Traktör';
  String? _selectedBrand;
  String? _selectedModel;
  int? _selectedYear;
  VehicleStatus _selectedStatus = VehicleStatus.active;
  String? _selectedFuelType;

  // Controllers
  final _plateCtrl = TextEditingController();
  final _chassisCtrl = TextEditingController();
  final _engineNoCtrl = TextEditingController();
  final _enginePowerCtrl = TextEditingController();
  final _engineCCCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  XFile? _selectedImage;
  bool _isLoading = false;
  bool get _isEditing => widget.vehicleId != null;

  List<String> get _brands => VehicleBrands.getBrands(_selectedType);
  List<String> get _models =>
      (_selectedBrand != null) ? VehicleBrands.getModels(_selectedType, _selectedBrand!) : [];
  List<int> get _yearList {
    final range = VehicleBrands.getYearRange(_selectedModel);
    final end = range[1];
    final start = range[0];
    return List.generate(end - start + 1, (i) => end - i);
  }

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final v = ref.read(vehiclesNotifierProvider).where((v) => v.id == widget.vehicleId).firstOrNull;
      if (v != null) {
        _selectedType = v.type;
        _selectedBrand = v.brand;
        _selectedModel = v.model;
        _selectedYear = v.year;
        _selectedStatus = v.status;
        _selectedFuelType = v.fuelType;
        _plateCtrl.text = v.plate ?? '';
        _chassisCtrl.text = v.chassisNo ?? '';
        _engineNoCtrl.text = v.engineNo ?? '';
        _enginePowerCtrl.text = v.enginePower?.toString() ?? '';
        _engineCCCtrl.text = v.engineCC?.toString() ?? '';
        _kmCtrl.text = v.currentKm?.toStringAsFixed(0) ?? '';
        _hoursCtrl.text = v.workingHours?.toStringAsFixed(0) ?? '';
        _notesCtrl.text = v.notes ?? '';
      }
    }
  }

  @override
  void dispose() {
    _plateCtrl.dispose(); _chassisCtrl.dispose(); _engineNoCtrl.dispose();
    _enginePowerCtrl.dispose(); _engineCCCtrl.dispose();
    _kmCtrl.dispose(); _hoursCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBrand == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marka seçin'), backgroundColor: AppColors.error));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final userId = ref.read(currentUserIdProvider) ?? 'anonymous';
      final vehicle = VehicleModel(
        id: _isEditing ? widget.vehicleId! : const String.fromEnvironment(''),
        farmId: userId,
        type: _selectedType,
        brand: _selectedBrand!,
        model: _selectedModel ?? _selectedBrand!,
        year: _selectedYear,
        plate: _plateCtrl.text.trim().isEmpty ? null : _plateCtrl.text.trim(),
        chassisNo: _chassisCtrl.text.trim().isEmpty ? null : _chassisCtrl.text.trim(),
        engineNo: _engineNoCtrl.text.trim().isEmpty ? null : _engineNoCtrl.text.trim(),
        enginePower: int.tryParse(_enginePowerCtrl.text),
        engineCC: int.tryParse(_engineCCCtrl.text),
        fuelType: _selectedFuelType,
        currentKm: double.tryParse(_kmCtrl.text),
        workingHours: double.tryParse(_hoursCtrl.text),
        status: _selectedStatus,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        photoUrl: _selectedImage?.path,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (_isEditing) {
        await ref.read(vehiclesNotifierProvider.notifier).update(vehicle);
      } else {
        final newVehicle = createVehicle(
          userId: userId,
          type: _selectedType, brand: _selectedBrand!,
          model: _selectedModel ?? _selectedBrand!,
          year: _selectedYear,
          plate: _plateCtrl.text.trim().isEmpty ? null : _plateCtrl.text.trim(),
          chassisNo: _chassisCtrl.text.trim().isEmpty ? null : _chassisCtrl.text.trim(),
          engineNo: _engineNoCtrl.text.trim().isEmpty ? null : _engineNoCtrl.text.trim(),
          enginePower: int.tryParse(_enginePowerCtrl.text),
          engineCC: int.tryParse(_engineCCCtrl.text),
          fuelType: _selectedFuelType,
          currentKm: double.tryParse(_kmCtrl.text),
          workingHours: double.tryParse(_hoursCtrl.text),
          status: _selectedStatus,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          photoUrl: _selectedImage?.path,
        );
        await ref.read(vehiclesNotifierProvider.notifier).add(newVehicle);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? 'Araç güncellendi' : 'Araç eklendi'), backgroundColor: AppColors.success),
        );
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_isEditing ? 'Araç Düzenle' : 'Araç Ekle')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fotoğraf
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
                          : null,
                    ),
                    child: _selectedImage == null
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

              _SectionLabel('Araç Tipi'),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(labelText: 'Araç Tipi *', prefixIcon: Icon(Icons.agriculture_rounded)),
                items: VehicleBrands.getTypes().map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() {
                  _selectedType = v!;
                  _selectedBrand = null;
                  _selectedModel = null;
                  _selectedYear = null;
                }),
              ),
              const SizedBox(height: 20),

              _SectionLabel('Marka & Model'),
              const SizedBox(height: 10),

              // Marka dropdown
              DropdownButtonFormField<String>(
                value: _selectedBrand,
                decoration: const InputDecoration(labelText: 'Marka *', prefixIcon: Icon(Icons.branding_watermark_rounded)),
                items: _brands.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                onChanged: (v) => setState(() { _selectedBrand = v; _selectedModel = null; }),
                validator: (v) => v == null ? 'Marka seçin' : null,
              ),
              const SizedBox(height: 12),

              // Model dropdown
              DropdownButtonFormField<String>(
                value: _selectedModel,
                decoration: const InputDecoration(labelText: 'Model *', prefixIcon: Icon(Icons.directions_car_rounded)),
                items: _models.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: _selectedBrand == null ? null : (v) => setState(() {
                  _selectedModel = v;
                  _selectedYear = null;
                }),
                validator: (v) => v == null ? 'Model seçin' : null,
              ),
              const SizedBox(height: 12),

              // Yıl — model seçilince o modelin üretim yılları gösterilir
              DropdownButtonFormField<int>(
                value: _yearList.contains(_selectedYear) ? _selectedYear : null,
                decoration: const InputDecoration(labelText: 'Yıl', prefixIcon: Icon(Icons.calendar_today_rounded)),
                items: _yearList.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                onChanged: (v) => setState(() => _selectedYear = v),
              ),
              const SizedBox(height: 20),

              _SectionLabel('Teknik Bilgiler'),
              const SizedBox(height: 10),

              // Yakıt tipi
              DropdownButtonFormField<String>(
                value: _selectedFuelType,
                decoration: const InputDecoration(labelText: 'Yakıt Tipi', prefixIcon: Icon(Icons.local_gas_station_rounded)),
                items: kFuelTypes.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                onChanged: (v) => setState(() => _selectedFuelType = v),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _enginePowerCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Motor Gücü', suffixText: 'HP'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _engineCCCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Motor Hacmi', suffixText: 'cc'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _engineNoCtrl,
                decoration: const InputDecoration(labelText: 'Motor No', prefixIcon: Icon(Icons.settings_rounded)),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _chassisCtrl,
                decoration: const InputDecoration(labelText: 'Şase No', prefixIcon: Icon(Icons.confirmation_number_rounded)),
              ),
              const SizedBox(height: 20),

              _SectionLabel('Kullanım Bilgileri'),
              const SizedBox(height: 10),

              TextFormField(
                controller: _plateCtrl,
                decoration: const InputDecoration(labelText: 'Plaka', prefixIcon: Icon(Icons.credit_card_rounded)),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _kmCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Kilometre', suffixText: 'km'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _hoursCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Çalışma Saati', suffixText: 'saat'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _SectionLabel('Durum'),
              const SizedBox(height: 10),

              Wrap(
                spacing: 8,
                children: VehicleStatus.values.map((s) {
                  final selected = _selectedStatus == s;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedStatus = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primarySurface : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: selected ? AppColors.primary : AppColors.border),
                      ),
                      child: Text(s.statusLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: selected ? AppColors.primary : AppColors.textSecondary)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notlar', alignLabelWithHint: true),
              ),
              const SizedBox(height: 32),

              AppButton(label: _isEditing ? 'Güncelle' : 'Kaydet', onPressed: _save, isLoading: _isLoading, icon: Icons.save_rounded),
              const SizedBox(height: 32),
            ],
          ),
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

extension on VehicleStatus {
  String get statusLabel {
    switch (this) {
      case VehicleStatus.active: return 'Aktif';
      case VehicleStatus.maintenance: return 'Bakımda';
      case VehicleStatus.broken: return 'Arızalı';
      case VehicleStatus.sold: return 'Satıldı';
    }
  }
}
