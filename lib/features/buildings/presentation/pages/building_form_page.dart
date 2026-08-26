import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_button.dart';
import '../providers/buildings_provider.dart';

class BuildingFormPage extends ConsumerStatefulWidget {
  final String? buildingId;
  const BuildingFormPage({super.key, this.buildingId});

  @override
  ConsumerState<BuildingFormPage> createState() => _BuildingFormPageState();
}

class _BuildingFormPageState extends ConsumerState<BuildingFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _areaController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedType = 'Ahır';
  XFile? _selectedImage;
  bool _isLoading = false;

  bool get _isEditing => widget.buildingId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final b = ref.read(buildingsNotifierProvider.notifier).getById(widget.buildingId!);
      if (b != null) {
        _nameController.text = b.name;
        _areaController.text = b.area?.toString() ?? '';
        _notesController.text = b.notes ?? '';
        _selectedType = b.type;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _areaController.dispose();
    _notesController.dispose();
    super.dispose();
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      if (_isEditing) {
        final existing = ref.read(buildingsNotifierProvider.notifier).getById(widget.buildingId!);
        if (existing != null) {
          ref.read(buildingsNotifierProvider.notifier).update(
            existing.copyWith(
              name: _nameController.text.trim(),
              type: _selectedType,
              area: double.tryParse(_areaController.text),
              notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
              photoUrl: _selectedImage?.path ?? existing.photoUrl,
            ),
          );
        }
      } else {
        final building = createBuilding(
          name: _nameController.text.trim(),
          type: _selectedType,
          area: double.tryParse(_areaController.text),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          photoUrl: _selectedImage?.path,
        );
        ref.read(buildingsNotifierProvider.notifier).add(building);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Yapı güncellendi' : 'Yapı eklendi'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_isEditing ? 'Yapı Düzenle' : 'Yapı Ekle')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
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
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Yapı Tipi *',
                  prefixIcon: Icon(Icons.home_work_rounded),
                ),
                items: AppConstants.buildingTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedType = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Yapı Adı *',
                  prefixIcon: Icon(Icons.label_rounded),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Ad gerekli' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _areaController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Alan (m²)',
                  prefixIcon: Icon(Icons.square_foot_rounded),
                  suffixText: 'm²',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notlar',
                  alignLabelWithHint: true,
                ),
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
