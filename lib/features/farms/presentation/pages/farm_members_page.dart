import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/farm_models.dart';
import '../../../../core/di/providers.dart';
import '../providers/farm_provider.dart';
import '../../../../shared/widgets/app_card.dart';

class FarmMembersPage extends ConsumerStatefulWidget {
  const FarmMembersPage({super.key});

  @override
  ConsumerState<FarmMembersPage> createState() => _FarmMembersPageState();
}

class _FarmMembersPageState extends ConsumerState<FarmMembersPage> {
  bool _generatingCode = false;
  final _createCtrl = TextEditingController();
  final _joinCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
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

  Future<void> _generateInvite(String farmId, String farmName, FarmRole role) async {
    setState(() => _generatingCode = true);
    try {
      final userId = ref.read(currentUserIdProvider)!;
      final code = await ref.read(farmServiceProvider).createInviteCode(
        farmId: farmId,
        farmName: farmName,
        createdBy: userId,
        role: role,
        maxUses: 10,
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );
      if (mounted) _showCodeDialog(code);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingCode = false);
    }
  }

  void _showCodeDialog(String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Davet Kodu Oluşturuldu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(code,
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                      color: AppColors.primary)),
            ),
            const SizedBox(height: 12),
            const Text('7 gün geçerli, 10 kullanım hakkı var.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kod kopyalandı')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Kopyala'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangeRoleDialog(String farmId, FarmMember member) async {
    FarmRole? selected = member.role;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('${member.displayName} — Rol'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: FarmRole.values
                .where((r) => r != FarmRole.owner)
                .map((r) => RadioListTile<FarmRole>(
                      title: Text(r.label),
                      value: r,
                      groupValue: selected,
                      onChanged: member.role == FarmRole.owner
                          ? null
                          : (v) => setS(() => selected = v),
                    ))
                .toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                if (selected != null && selected != member.role) {
                  await ref.read(farmServiceProvider).updateMemberRole(farmId, member.userId, selected!);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${member.displayName} rolü güncellendi')),
                    );
                  }
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _leaveFarm(String farmId, String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çiftlikten Ayrıl'),
        content: const Text('Bu çiftlikten ayrılmak istediğinizden emin misiniz? Yeniden katılmak için davet kodu gerekecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ayrıl'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ref.read(farmServiceProvider).leaveFarm(userId, farmId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Çiftlikten ayrıldınız'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  Future<void> _renameFarm(String farmId, String currentName) async {
    final ctrl = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Çiftlik Adını Değiştir'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Yeni Çiftlik Adı',
              prefixIcon: Icon(Icons.home_work_rounded),
            ),
            onChanged: (_) => setS(() {}),
            onSubmitted: (v) {
              final trimmed = v.trim();
              if (trimmed.isNotEmpty && trimmed != currentName) {
                Navigator.pop(ctx, trimmed);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                final trimmed = ctrl.text.trim();
                if (trimmed.isNotEmpty && trimmed != currentName) {
                  Navigator.pop(ctx, trimmed);
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (newName == null || newName.isEmpty) return;

    try {
      await ref.read(farmServiceProvider).renameFarm(farmId, newName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Çiftlik adı güncellendi'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteFarm(String farmId, String farmName) async {
    // İlk onay
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çiftliği Sil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                children: [
                  const TextSpan(text: '"'),
                  TextSpan(
                    text: farmName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: '" çiftliğini kalıcı olarak silmek istediğinizden emin misiniz?'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 16),
                    SizedBox(width: 6),
                    Text('Bu işlem geri alınamaz!',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.error, fontSize: 13)),
                  ]),
                  SizedBox(height: 4),
                  Text('• Tüm üyeler çiftlikten çıkarılır\n• Tüm davet kodları silinir\n• Bu veriler kurtarılamaz',
                      style: TextStyle(fontSize: 12, color: AppColors.error)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Devam Et'),
          ),
        ],
      ),
    );
    if (confirm1 != true) return;

    // İkinci onay — çiftlik adını yaz
    final nameCtrl = TextEditingController();
    final confirm2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Son Onay'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Onaylamak için çiftlik adını yazın:',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Text('"$farmName"',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Çiftlik adını buraya yazın',
                  isDense: true,
                ),
                onChanged: (_) => setS(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: nameCtrl.text.trim() == farmName.trim()
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('Çiftliği Sil'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    if (confirm2 != true) return;

    setState(() => _loading = true);
    try {
      final userId = ref.read(currentUserIdProvider)!;
      await ref.read(farmServiceProvider).deleteFarm(farmId, userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Çiftlik başarıyla silindi'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeMember(String farmId, FarmMember member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Üyeyi Çıkar'),
        content: Text('${member.displayName} çiftlikten çıkarılacak. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Çıkar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(farmServiceProvider).removeMember(farmId, member.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmAsync = ref.watch(activeFarmProvider);
    final membersAsync = ref.watch(farmMembersProvider);
    final invitesAsync = ref.watch(farmInvitesProvider);
    final myRole = ref.watch(myFarmRoleProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    final canManage = myRole?.canManageMembers ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Çiftlik Üyeleri'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: farmAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
                const SizedBox(height: 12),
                Text('Hata: $e', textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.error)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(activeFarmProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Yenile'),
                ),
              ],
            ),
          ),
        ),
        data: (farm) {
          if (farm == null) return _buildNoFarmView();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Çiftlik Bilgisi ────────────────────────
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.agriculture_rounded, color: AppColors.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(farm.name,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                              ),
                              if (myRole == FarmRole.owner)
                                GestureDetector(
                                  onTap: () => _renameFarm(farm.id, farm.name),
                                  child: const Padding(
                                    padding: EdgeInsets.only(left: 6),
                                    child: Icon(Icons.edit_rounded,
                                        size: 16, color: AppColors.textSecondary),
                                  ),
                                ),
                            ],
                          ),
                          Text('ID: ${farm.id.substring(0, 8)}...',
                              style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                        ]),
                      ),
                      if (myRole != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(myRole.label,
                              style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                        ),
                    ]),
                    // Sahip ise çiftliği sil butonu
                    if (myRole == FarmRole.owner) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : () => _deleteFarm(farm.id, farm.name),
                          icon: const Icon(Icons.delete_forever_rounded, size: 18, color: AppColors.error),
                          label: const Text('Çiftliği Sil',
                              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Üyeler ────────────────────────────────
              Row(children: [
                const Text('Üyeler',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (canManage)
                  TextButton.icon(
                    onPressed: _generatingCode
                        ? null
                        : () => _showInviteOptions(farm.id, farm.name),
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: const Text('Davet Et'),
                  ),
              ]),
              const SizedBox(height: 8),
              membersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Hata: $e', style: const TextStyle(color: AppColors.error)),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => ref.invalidate(farmMembersProvider),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Yenile'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (members) => Column(
                  children: members.map((m) => _MemberTile(
                    member: m,
                    isMe: m.userId == currentUserId,
                    canManage: canManage && m.role != FarmRole.owner,
                    onChangeRole: () => _showChangeRoleDialog(farm.id, m),
                    onRemove: () => _removeMember(farm.id, m),
                    onLeave: (m.userId == currentUserId && m.role != FarmRole.owner)
                        ? () => _leaveFarm(farm.id, m.userId)
                        : null,
                  )).toList(),
                ),
              ),

              const SizedBox(height: 20),

              // ── Aktif Davet Kodları ────────────────────
              if (canManage) ...[
                const Text('Aktif Davet Kodları',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                invitesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (invites) => invites.isEmpty
                      ? const Text('Aktif davet kodu yok.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
                      : Column(
                          children: invites.map((inv) => _InviteTile(
                            invite: inv,
                            onDeactivate: () async {
                              await ref.read(farmServiceProvider).deactivateInvite(inv.code);
                            },
                          )).toList(),
                        ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildNoFarmView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Icon(Icons.person_rounded, color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Kişisel Mod', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  Text('Şu an verileriniz yalnızca size özel.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 28),
          const Text('Grup Çiftliği Oluştur', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Diğer kullanıcıları davet edeceğiniz bir çiftlik grubu oluşturun.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextField(
            controller: _createCtrl,
            decoration: const InputDecoration(
              labelText: 'Çiftlik Adı',
              hintText: 'Örn: Yılmaz Çiftliği',
              prefixIcon: Icon(Icons.home_work_rounded),
            ),
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _createFarm(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _createFarm,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add_rounded),
              label: const Text('Çiftlik Oluştur'),
            ),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 24),
          const Text('Mevcut Çiftliğe Katıl', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Davet kodunuz varsa buraya girin.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextField(
            controller: _joinCtrl,
            decoration: const InputDecoration(
              labelText: 'Davet Kodu',
              hintText: 'Örn: AB3X7KPQ',
              prefixIcon: Icon(Icons.key_rounded),
            ),
            textCapitalization: TextCapitalization.characters,
            onSubmitted: (_) => _joinFarm(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _joinFarm,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.login_rounded),
              label: const Text('Çiftliğe Katıl'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.error))),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  void _showInviteOptions(String farmId, String farmName) {
    FarmRole selectedRole = FarmRole.member;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Davet Kodu Oluştur',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              const Text('Rol:', style: TextStyle(fontWeight: FontWeight.w600)),
              ...FarmRole.values
                  .where((r) => r != FarmRole.owner)
                  .map((r) => RadioListTile<FarmRole>(
                        title: Text(r.label),
                        subtitle: Text(_roleDesc(r),
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        value: r,
                        groupValue: selectedRole,
                        onChanged: (v) => setS(() => selectedRole = v!),
                        dense: true,
                      )),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _generateInvite(farmId, farmName, selectedRole);
                  },
                  icon: const Icon(Icons.key_rounded, size: 18),
                  label: const Text('Kod Oluştur'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _roleDesc(FarmRole r) {
    switch (r) {
      case FarmRole.admin: return 'Tüm verilere erişim + üye yönetimi';
      case FarmRole.member: return 'Tüm verileri okuyabilir ve yazabilir';
      case FarmRole.viewer: return 'Yalnızca görüntüleyebilir';
      default: return '';
    }
  }
}

class _MemberTile extends StatelessWidget {
  final FarmMember member;
  final bool isMe;
  final bool canManage;
  final VoidCallback onChangeRole;
  final VoidCallback onRemove;
  final VoidCallback? onLeave;

  const _MemberTile({
    required this.member,
    required this.isMe,
    required this.canManage,
    required this.onChangeRole,
    required this.onRemove,
    this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.primarySurface,
          child: Text(
            (member.displayName.isNotEmpty ? member.displayName[0] : '?').toUpperCase(),
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(member.displayName.isNotEmpty ? member.displayName : member.email,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              if (isMe) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Ben', style: TextStyle(fontSize: 10, color: AppColors.primary)),
                ),
              ],
            ]),
            Text(member.email,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _roleColor(member.role).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(member.role.label,
              style: TextStyle(fontSize: 11, color: _roleColor(member.role), fontWeight: FontWeight.w600)),
        ),
        if (onLeave != null) ...[
          const SizedBox(width: 4),
          TextButton(
            onPressed: onLeave,
            style: TextButton.styleFrom(foregroundColor: AppColors.error, padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: const Text('Ayrıl', style: TextStyle(fontSize: 13)),
          ),
        ] else if (canManage) ...[
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textTertiary),
            onSelected: (v) {
              if (v == 'role') onChangeRole();
              if (v == 'remove') onRemove();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'role', child: Text('Rolü Değiştir')),
              const PopupMenuItem(
                value: 'remove',
                child: Text('Çıkar', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        ],
      ]),
    );
  }

  Color _roleColor(FarmRole r) {
    switch (r) {
      case FarmRole.owner: return AppColors.primary;
      case FarmRole.admin: return AppColors.warning;
      case FarmRole.member: return AppColors.success;
      case FarmRole.viewer: return AppColors.textSecondary;
    }
  }
}

class _InviteTile extends StatelessWidget {
  final FarmInvite invite;
  final VoidCallback onDeactivate;
  const _InviteTile({required this.invite, required this.onDeactivate});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        const Icon(Icons.key_rounded, color: AppColors.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(invite.code,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 2)),
            Text('${invite.role.label} · ${invite.usedCount}/${invite.maxUses ?? '∞'} kullanım',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.copy_rounded, size: 18),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: invite.code));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Kod kopyalandı')),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
          onPressed: onDeactivate,
        ),
      ]),
    );
  }
}
