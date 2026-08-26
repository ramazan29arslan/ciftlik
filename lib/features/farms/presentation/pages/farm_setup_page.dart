import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/farm_models.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/router/app_router.dart';
import '../providers/farm_provider.dart';

class FarmSetupPage extends ConsumerStatefulWidget {
  const FarmSetupPage({super.key});

  @override
  ConsumerState<FarmSetupPage> createState() => _FarmSetupPageState();
}

class _FarmSetupPageState extends ConsumerState<FarmSetupPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _createCtrl = TextEditingController();
  final _joinCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _createCtrl.dispose();
    _joinCtrl.dispose();
    super.dispose();
  }

  Future<void> _createFarm() async {
    final name = _createCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final user = ref.read(currentUserProvider)!;
      await ref.read(farmServiceProvider).createFarm(
        name: name,
        ownerId: user.uid,
        ownerEmail: user.email ?? '',
        ownerName: user.displayName ?? user.email ?? 'Kullanıcı',
      );
      // Profil stream'ini yenile — çiftlik hemen görünsün
      ref.invalidate(userProfileStreamProvider);
      if (mounted) context.go(AppRoutes.dashboard);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinFarm() async {
    final code = _joinCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final user = ref.read(currentUserProvider)!;
      await ref.read(farmServiceProvider).joinWithCode(
        code: code,
        userId: user.uid,
        userEmail: user.email ?? '',
        displayName: user.displayName ?? user.email ?? 'Kullanıcı',
      );
      ref.invalidate(userProfileStreamProvider);
      if (mounted) context.go(AppRoutes.dashboard);
    } on MultiFarmRequestedException catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showPendingDialog(e.message);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showPendingDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Onay Bekleniyor'),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.agriculture_rounded,
                    color: AppColors.primary, size: 34),
              ),
              const SizedBox(height: 20),
              const Text('Çiftliğinize Katılın',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              const Text('Yeni bir çiftlik oluşturun veya davet koduyla mevcut çiftliğe katılın.',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 28),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tab,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          blurRadius: 4)
                    ],
                  ),
                  tabs: const [
                    Tab(text: 'Çiftlik Oluştur'),
                    Tab(text: 'Koda Katıl'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    // ── Oluştur ──────────────────────────────
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _createCtrl,
                          autofocus: false,
                          decoration: const InputDecoration(
                            labelText: 'Çiftlik Adı',
                            hintText: 'Örn: Yılmaz Çiftliği',
                            prefixIcon: Icon(Icons.home_work_rounded),
                          ),
                          textCapitalization: TextCapitalization.words,
                          onSubmitted: (_) => _createFarm(),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity, height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _loading ? null : _createFarm,
                            icon: _loading
                                ? const SizedBox(
                                    width: 18, height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.add_rounded),
                            label: const Text('Çiftlik Oluştur'),
                          ),
                        ),
                      ],
                    ),
                    // ── Katıl ────────────────────────────────
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _joinCtrl,
                          autofocus: false,
                          decoration: const InputDecoration(
                            labelText: 'Davet Kodu',
                            hintText: 'Örn: AB3X7KPQ',
                            prefixIcon: Icon(Icons.key_rounded),
                          ),
                          textCapitalization: TextCapitalization.characters,
                          onSubmitted: (_) => _joinFarm(),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity, height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _loading ? null : _joinFarm,
                            icon: _loading
                                ? const SizedBox(
                                    width: 18, height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.login_rounded),
                            label: const Text('Çiftliğe Katıl'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!,
                        style: const TextStyle(fontSize: 13, color: AppColors.error))),
                  ]),
                ),
              const SizedBox(height: 12),
              // Çıkış
              Center(
                child: TextButton(
                  onPressed: () async {
                    await ref.read(authRepositoryProvider).signOut();
                  },
                  child: const Text('Çıkış Yap',
                      style: TextStyle(color: AppColors.textTertiary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
