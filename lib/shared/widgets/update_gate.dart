import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/services/update_service.dart';
import '../../core/theme/app_colors.dart';

/// Uygulama açılışında OTA güncellemesi olup olmadığına bakar ve varsa
/// kullanıcıya notlarla birlikte sorar.
///
/// `MaterialApp.builder` içine sarıldığı için hangi sayfada olunduğundan
/// bağımsız çalışır. Kontrol açılışı bloklamaz: ilk kare çizildikten sonra
/// arka planda yapılır, hata olursa sessizce vazgeçilir.
class UpdateGate extends ConsumerStatefulWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends ConsumerState<UpdateGate> {
  static const _dismissedKey = 'dismissed_patch_number';
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    if (_started) return;
    _started = true;

    final service = ref.read(updateServiceProvider);
    if (!service.isAvailable) return;

    try {
      if (!await service.hasUpdate()) return;

      final notes = await service.fetchNotes();
      if (notes == null) return;

      // "Daha sonra" denen yamayı her açılışta tekrar sormayalım.
      final prefs = ref.read(sharedPreferencesProvider);
      if (prefs.getInt(_dismissedKey) == notes.patchNumber) return;

      if (!mounted) return;
      await _promptUser(notes);
    } catch (_) {
      // Güncelleme kontrolü uygulamayı engellememeli.
    }
  }

  Future<void> _promptUser(PatchNotes notes) async {
    final shouldUpdate = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.system_update_rounded, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(notes.title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bu sürümde yapılan değişiklikler:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            ...notes.notes.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(line)),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Daha Sonra'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );

    if (shouldUpdate != true) {
      await ref
          .read(sharedPreferencesProvider)
          .setInt(_dismissedKey, notes.patchNumber);
      return;
    }

    await _download();
  }

  Future<void> _download() async {
    if (!mounted) return;

    // İndirme sırasında kapatılamayan bir ilerleme kutusu göster.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: 20),
            Expanded(child: Text('Güncelleme indiriliyor…')),
          ],
        ),
      ),
    );

    String message;
    try {
      await ref.read(updateServiceProvider).download();
      message = 'Güncelleme indirildi. Uygulamayı tamamen kapatıp yeniden '
          'açtığınızda yeni sürüm devreye girecek.';
    } catch (_) {
      message = 'Güncelleme indirilemedi. Bağlantınızı kontrol edip daha '
          'sonra tekrar deneyin.';
    }

    if (!mounted) return;
    Navigator.pop(context); // ilerleme kutusunu kapat

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
