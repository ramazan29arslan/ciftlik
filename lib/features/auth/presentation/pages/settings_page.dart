import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/di/settings_provider.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/services/update_service.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../data/repositories/auth_repository.dart';
import '../providers/auth_provider.dart';
import 'farm_activity_log_page.dart';
import 'feedback_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late TextEditingController _dieselCtrl;
  late TextEditingController _benzinCtrl;
  late TextEditingController _milkCtrl;
  late TextEditingController _elecCtrl;
  late TextEditingController _farmNameCtrl;
  late TextEditingController _ownerCtrl;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _dieselCtrl = TextEditingController(text: s.dieselPricePerLiter.toString());
    _benzinCtrl = TextEditingController(text: s.benzinPricePerLiter.toString());
    _milkCtrl = TextEditingController(text: s.milkPricePerLiter.toString());
    _elecCtrl = TextEditingController(text: s.electricityRate.toString());
    _farmNameCtrl = TextEditingController(text: s.farmName);
    _ownerCtrl = TextEditingController(text: s.ownerName);
  }

  @override
  void dispose() {
    _dieselCtrl.dispose();
    _benzinCtrl.dispose();
    _milkCtrl.dispose();
    _elecCtrl.dispose();
    _farmNameCtrl.dispose();
    _ownerCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref.read(settingsProvider.notifier).update(
          dieselPricePerLiter: double.tryParse(_dieselCtrl.text) ?? 42.5,
          benzinPricePerLiter: double.tryParse(_benzinCtrl.text) ?? 45.0,
          milkPricePerLiter: double.tryParse(_milkCtrl.text) ?? 18.0,
          electricityRate: double.tryParse(_elecCtrl.text) ?? 3.5,
          farmName: _farmNameCtrl.text.trim().isEmpty ? 'Çiftliğim' : _farmNameCtrl.text.trim(),
          ownerName: _ownerCtrl.text.trim(),
        );
    if (mounted) {
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ayarlar kaydedildi'), backgroundColor: AppColors.success),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _saved = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ayarlar'),
        leading: BackButton(onPressed: () => context.go(AppRoutes.dashboard)),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: Icon(_saved ? Icons.check_rounded : Icons.save_rounded, size: 18),
            label: Text(_saved ? 'Kaydedildi' : 'Kaydet'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Çiftlik Bilgileri
            _SectionTitle('Çiftlik Bilgileri'),
            const SizedBox(height: 10),
            AppCard(
              child: Column(
                children: [
                  _SettingField(
                    controller: _farmNameCtrl,
                    label: 'Çiftlik Adı',
                    icon: Icons.agriculture_rounded,
                    hint: 'Çiftliğimin Adı',
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  _SettingField(
                    controller: _ownerCtrl,
                    label: 'Yetkili Adı',
                    icon: Icons.person_rounded,
                    hint: 'Ad Soyad',
                    isLast: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Birim Fiyatlar
            _SectionTitle('Birim Fiyatlar'),
            const SizedBox(height: 4),
            const Text(
              'Bu fiyatlar gider hesaplamalarında ve raporlarda kullanılır.',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 10),
            AppCard(
              child: Column(
                children: [
                  _PriceField(
                    controller: _dieselCtrl,
                    label: 'Motorin Fiyatı',
                    icon: Icons.local_gas_station_rounded,
                    iconColor: AppColors.vehicleColor,
                    unit: '₺/litre',
                    hint: '42.50',
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  _PriceField(
                    controller: _benzinCtrl,
                    label: 'Benzin Fiyatı',
                    icon: Icons.local_gas_station_rounded,
                    iconColor: Colors.orange,
                    unit: '₺/litre',
                    hint: '45.00',
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  _PriceField(
                    controller: _milkCtrl,
                    label: 'Süt Fiyatı',
                    icon: Icons.water_drop_rounded,
                    iconColor: AppColors.info,
                    unit: '₺/litre',
                    hint: '18.00',
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  _PriceField(
                    controller: _elecCtrl,
                    label: 'Elektrik Fiyatı',
                    icon: Icons.bolt_rounded,
                    iconColor: AppColors.energyColor,
                    unit: '₺/kWh',
                    hint: '3.50',
                    isLast: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Güncel fiyat özeti
            _SectionTitle('Güncel Değerler'),
            const SizedBox(height: 10),
            Consumer(
              builder: (context, ref, _) {
                final s = ref.watch(settingsProvider);
                return AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _SummaryRow(
                        icon: Icons.local_gas_station_rounded,
                        color: AppColors.vehicleColor,
                        label: 'Motorin',
                        value: '₺${s.dieselPricePerLiter}/L',
                      ),
                      const SizedBox(height: 10),
                      _SummaryRow(
                        icon: Icons.local_gas_station_rounded,
                        color: Colors.orange,
                        label: 'Benzin',
                        value: '₺${s.benzinPricePerLiter}/L',
                      ),
                      const SizedBox(height: 10),
                      _SummaryRow(
                        icon: Icons.water_drop_rounded,
                        color: AppColors.info,
                        label: 'Süt',
                        value: '₺${s.milkPricePerLiter}/L',
                      ),
                      const SizedBox(height: 10),
                      _SummaryRow(
                        icon: Icons.bolt_rounded,
                        color: AppColors.energyColor,
                        label: 'Elektrik',
                        value: '₺${s.electricityRate}/kWh',
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: Icon(_saved ? Icons.check_rounded : Icons.save_rounded),
                label: Text(_saved ? 'Kaydedildi ✓' : 'Kaydet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _saved ? AppColors.success : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Log Kayıtları
            _SectionTitle('Aktivite'),
            const SizedBox(height: 10),
            AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.history_rounded, color: AppColors.primary, size: 18),
                ),
                title: const Text('Log Kayıtları', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: const Text('Çiftlikte yapılan tüm değişiklikler', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FarmActivityLogPage())),
              ),
            ),
            const SizedBox(height: 16),

            // Şikayet & Öneriler
            AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.feedback_rounded, color: AppColors.warning, size: 18),
                ),
                title: const Text('Şikayet & Öneriler', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: const Text('Görüş ve önerilerinizi bildirin', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackPage())),
              ),
            ),
            const SizedBox(height: 16),

            // Hesap Yönetimi
            _SectionTitle('Hesap'),
            const SizedBox(height: 10),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.pause_circle_outline_rounded, color: AppColors.warning, size: 18),
                    ),
                    title: const Text('Hesabı Dondur', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: const Text('Tekrar giriş yaptığınızda hesabınız aktif olur', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                    onTap: () => _showFreezeAccountDialog(context),
                  ),
                  const Divider(height: 1, indent: 52),
                  ListTile(
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
                    ),
                    title: const Text('Çıkış Yap', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.error)),
                    onTap: () async {
                      await ref.read(authRepositoryProvider).signOut();
                      if (context.mounted) context.go(AppRoutes.login);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _PatchFooter(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showFreezeAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hesabı Dondur'),
        content: const Text(
          'Hesabınız dondurulacak ve çıkış yapılacak.\n\nTekrar giriş yaptığınızda hesabınız otomatik olarak aktifleşecektir.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final uid = ref.read(currentUserIdProvider);
              if (uid == null) return;
              await AuthRepository().freezeAccount(uid);
              if (context.mounted) context.go(AppRoutes.login);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Dondur', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) => Text(
        title,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
      );
}

class _SettingField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String hint;
  final bool isLast;

  const _SettingField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.hint,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
        ),
      ),
    );
  }
}

class _PriceField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color iconColor;
  final String unit;
  final String hint;
  final bool isLast;

  const _PriceField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.unit,
    required this.hint,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                suffixText: unit,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _SummaryRow(
      {required this.icon,
      required this.color,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration:
              BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ],
    );
  }
}

/// Ayarlar sayfasinin altinda o an calisan OTA yamasini gosterir.
class _PatchFooter extends ConsumerWidget {
  const _PatchFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<int?>(
      future: ref.read(updateServiceProvider).currentPatchNumber(),
      builder: (context, snapshot) {
        final number = snapshot.data;
        final label = number == null
            ? 'Güncelleme: yama yüklü değil'
            : 'Güncelleme: yama #$number yüklü';
        return Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
        );
      },
    );
  }
}
