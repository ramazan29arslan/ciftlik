import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/document_model.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../farms/presentation/providers/farm_provider.dart';
import '../../../documents/presentation/widgets/entity_documents_section.dart';
import '../providers/fields_provider.dart';

enum _AreaUnit { m2, donum, hektar }

extension _AreaUnitLabel on _AreaUnit {
  String get label {
    switch (this) {
      case _AreaUnit.m2:
        return 'm²';
      case _AreaUnit.donum:
        return 'Dönüm';
      case _AreaUnit.hektar:
        return 'Hektar';
    }
  }
}

class FieldFormPage extends ConsumerStatefulWidget {
  final String? fieldId;
  const FieldFormPage({super.key, this.fieldId});

  @override
  ConsumerState<FieldFormPage> createState() => _FieldFormPageState();
}

class _FieldFormPageState extends ConsumerState<FieldFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _areaController = TextEditingController();
  final _tapuController = TextEditingController();
  final _notesController = TextEditingController();

  _AreaUnit _selectedUnit = _AreaUnit.donum;
  bool _isLoading = false;

  bool get _isEditing => widget.fieldId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final f =
          ref.read(fieldsNotifierProvider.notifier).getById(widget.fieldId!);
      if (f != null) {
        _nameController.text = f.name;
        _locationController.text = f.location ?? '';
        _tapuController.text = f.tapuNo ?? '';
        _notesController.text = f.notes ?? '';
        if (f.areaM2 != null) {
          _selectedUnit = _AreaUnit.donum;
          final donum = f.areaM2! / 1000;
          _areaController.text = donum.toStringAsFixed(3);
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _areaController.dispose();
    _tapuController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double? _computeAreaM2() {
    final input = double.tryParse(_areaController.text.trim());
    if (input == null) return null;
    switch (_selectedUnit) {
      case _AreaUnit.m2:
        return input;
      case _AreaUnit.donum:
        return input * 1000;
      case _AreaUnit.hektar:
        return input * 10000;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final areaM2 = _computeAreaM2();
      final name = _nameController.text.trim();
      final location = _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim();
      final tapuNo = _tapuController.text.trim().isEmpty
          ? null
          : _tapuController.text.trim();
      final notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();

      if (_isEditing) {
        final existing =
            ref.read(fieldsNotifierProvider.notifier).getById(widget.fieldId!);
        if (existing != null) {
          await ref.read(fieldsNotifierProvider.notifier).update(
                existing.copyWith(
                  name: name,
                  location: location,
                  clearLocation: location == null,
                  areaM2: areaM2,
                  clearAreaM2: areaM2 == null,
                  tapuNo: tapuNo,
                  clearTapuNo: tapuNo == null,
                  notes: notes,
                  clearNotes: notes == null,
                ),
              );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tarla güncellendi'), backgroundColor: AppColors.success),
            );
            context.pop();
          }
        }
      } else {
        final farmId = ref.read(activeFarmIdProvider) ?? '';
        final field = createField(
          farmId: farmId,
          name: name,
          location: location,
          areaM2: areaM2,
          tapuNo: tapuNo,
          notes: notes,
        );
        await ref.read(fieldsNotifierProvider.notifier).add(field);

        if (mounted) {
          // Tapu belgesi eklemek ister misiniz? (opsiyonel)
          // Sayfa kapanınca form sayfasından da çıkılır.
          showDocumentAddForm(
            context, ref,
            entityId: field.id,
            entityType: EntityType.field,
            entityName: name,
            availableDocTypes: const [
              DocType.tapu,
              DocType.vekaletname,
              DocType.sozlesme,
              DocType.diger,
            ],
            onDismissed: () {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tarla eklendi'), backgroundColor: AppColors.success),
                );
                context.pop();
              }
            },
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_isEditing ? 'Tarla Düzenle' : 'Tarla Ekle')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tarla Adı *',
                  prefixIcon: Icon(Icons.crop_landscape_rounded),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Tarla adı gerekli' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Konum / Köy Adı',
                  prefixIcon: Icon(Icons.location_on_rounded),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Alan Bilgisi',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Birim seçin:',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: _AreaUnit.values.map((unit) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () =>
                                  setState(() => _selectedUnit = unit),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10),
                                decoration: BoxDecoration(
                                  color: _selectedUnit == unit
                                      ? AppColors.primarySurface
                                      : AppColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _selectedUnit == unit
                                        ? AppColors.primary
                                        : AppColors.borderLight,
                                    width: _selectedUnit == unit ? 2 : 1,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  unit.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedUnit == unit
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _areaController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Alan',
                        prefixIcon: const Icon(Icons.square_foot_rounded),
                        suffixText: _selectedUnit.label,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _AreaConversionHint(
                        areaText: _areaController.text,
                        unit: _selectedUnit),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tapuController,
                decoration: const InputDecoration(
                  labelText: 'Tapu Parsel Numarası',
                  prefixIcon: Icon(Icons.description_rounded),
                  hintText: 'Örn: 124/5',
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

class _AreaConversionHint extends StatelessWidget {
  final String areaText;
  final _AreaUnit unit;

  const _AreaConversionHint({required this.areaText, required this.unit});

  @override
  Widget build(BuildContext context) {
    final input = double.tryParse(areaText.trim());
    if (input == null || input <= 0) return const SizedBox.shrink();

    double m2;
    switch (unit) {
      case _AreaUnit.m2:
        m2 = input;
        break;
      case _AreaUnit.donum:
        m2 = input * 1000;
        break;
      case _AreaUnit.hektar:
        m2 = input * 10000;
        break;
    }

    final parts = <String>[];
    if (unit != _AreaUnit.m2) {
      parts.add('${m2.toStringAsFixed(0)} m²');
    }
    if (unit != _AreaUnit.donum) {
      parts.add('${(m2 / 1000).toStringAsFixed(3)} dönüm');
    }
    if (unit != _AreaUnit.hektar) {
      parts.add('${(m2 / 10000).toStringAsFixed(4)} ha');
    }

    if (parts.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        const Icon(Icons.swap_horiz_rounded,
            size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 6),
        Text(
          parts.join('  •  '),
          style: const TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
              fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}
