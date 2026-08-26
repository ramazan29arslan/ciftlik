import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/di/settings_provider.dart';
import '../../../../shared/widgets/app_card.dart';

const _profilePhotoKey = 'profile_photo_path';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_profilePhotoKey);
    if (path != null && File(path).existsSync() && mounted) {
      setState(() => _photoPath = path);
    }
  }

  Future<void> _pickPhoto() async {
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
    if (file == null || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profilePhotoKey, file.path);
    setState(() => _photoPath = file.path);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profilim'),
        leading: BackButton(onPressed: () => context.go(AppRoutes.dashboard)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Stack(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primaryPale, width: 3),
                        image: _photoPath != null
                            ? DecorationImage(image: FileImage(File(_photoPath!)), fit: BoxFit.cover)
                            : null,
                      ),
                      child: _photoPath == null
                          ? const Icon(Icons.person_rounded, size: 48, color: AppColors.primaryMedium)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                            color: AppColors.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              settings.ownerName.isNotEmpty ? settings.ownerName : 'Kullanıcı',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              settings.farmName,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),

            AppCard(
              child: Column(
                children: [
                  _InfoRow(
                      icon: Icons.agriculture_rounded,
                      label: 'Çiftlik Adı',
                      value: settings.farmName),
                  const Divider(height: 1, color: AppColors.divider),
                  _InfoRow(
                      icon: Icons.person_rounded,
                      label: 'Yetkili',
                      value: settings.ownerName.isNotEmpty ? settings.ownerName : '-'),
                  const Divider(height: 1, color: AppColors.divider),
                  _InfoRow(
                      icon: Icons.shield_rounded,
                      label: 'Rol',
                      value: 'Admin',
                      isLast: true),
                ],
              ),
            ),
            const SizedBox(height: 16),

            AppCard(
              child: Column(
                children: [
                  _InfoRow(
                      icon: Icons.local_gas_station_rounded,
                      label: 'Motorin',
                      value: '₺${settings.dieselPricePerLiter}/L'),
                  const Divider(height: 1, color: AppColors.divider),
                  _InfoRow(
                      icon: Icons.local_gas_station_rounded,
                      label: 'Benzin',
                      value: '₺${settings.benzinPricePerLiter}/L'),
                  const Divider(height: 1, color: AppColors.divider),
                  _InfoRow(
                      icon: Icons.water_drop_rounded,
                      label: 'Süt Fiyatı',
                      value: '₺${settings.milkPricePerLiter}/L'),
                  const Divider(height: 1, color: AppColors.divider),
                  _InfoRow(
                      icon: Icons.bolt_rounded,
                      label: 'Elektrik',
                      value: '₺${settings.electricityRate}/kWh',
                      isLast: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow(
      {required this.icon, required this.label, required this.value, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
