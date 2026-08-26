import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/otp_email_service.dart';
import '../providers/auth_provider.dart';

class EmailOtpPage extends ConsumerStatefulWidget {
  const EmailOtpPage({super.key});

  @override
  ConsumerState<EmailOtpPage> createState() => _EmailOtpPageState();
}

class _EmailOtpPageState extends ConsumerState<EmailOtpPage> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;

  // Geri sayım
  Timer? _countdownTimer;
  int _secondsLeft = 600; // 10 dakika

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _secondsLeft = 600;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        if (mounted) {
          setState(() => _errorMessage = 'Kod süresi doldu. Yeni kod isteyin.');
        }
      }
    });
  }

  String get _timeLabel {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get _enteredCode =>
      _controllers.map((c) => c.text).join();

  void _onDigitEntered(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.length == 6) {
      // Pano yapıştırma — 6 haneyi dağıt
      for (var i = 0; i < 6 && i < value.length; i++) {
        _controllers[i].text = value[i];
      }
      _focusNodes[5].requestFocus();
      _verify();
      return;
    }
    if (_enteredCode.length == 6) _verify();
  }

  void _onKeyEvent(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verify() async {
    final pending = ref.read(otpPendingProvider);
    if (pending == null) {
      context.go(AppRoutes.login);
      return;
    }

    final entered = _enteredCode;
    if (entered.length < 6) {
      setState(() => _errorMessage = '6 haneli kodu eksiksiz girin');
      return;
    }

    if (pending.isExpired) {
      setState(() => _errorMessage = 'Kod süresi doldu. Yeni kod isteyin.');
      return;
    }

    if (entered != pending.code) {
      setState(() => _errorMessage = 'Hatalı kod. Tekrar deneyin.');
      for (final c in _controllers) c.clear();
      _focusNodes[0].requestFocus();
      return;
    }

    setState(() { _isVerifying = true; _errorMessage = null; });
    try {
      // Kod doğru → Firebase hesabı oluştur
      final repo = ref.read(authRepositoryProvider);
      await repo.signUpWithEmail(
        pending.email,
        pending.password,
        displayName: pending.name,
      );
      // OTP state'ini temizle
      ref.read(otpPendingProvider.notifier).state = null;
      if (mounted) context.go(AppRoutes.dashboard);
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage =
          ref.read(authRepositoryProvider).mapError(e));
    } catch (_) {
      setState(() => _errorMessage = 'Hesap oluşturulamadı. Tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    final pending = ref.read(otpPendingProvider);
    if (pending == null) return;

    setState(() { _isResending = true; _errorMessage = null; });
    try {
      final newCode = OtpEmailService.generateOtp();
      final sent = await OtpEmailService.sendOtp(
        toEmail: pending.email,
        toName: pending.name,
        otpCode: newCode,
      );

      if (!sent) throw Exception('Gönderim başarısız');

      // Yeni kodu state'e yaz
      ref.read(otpPendingProvider.notifier).state = OtpPendingData(
        email: pending.email,
        name: pending.name,
        password: pending.password,
        code: newCode,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      );

      for (final c in _controllers) c.clear();
      _focusNodes[0].requestFocus();
      _startCountdown();

      // Geliştirici modunda kodu göster
      if (OtpEmailService.isDevMode && mounted) {
        _showDevCode(newCode);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yeni kod e-postanıza gönderildi')),
        );
      }
    } catch (_) {
      setState(() => _errorMessage = 'Kod gönderilemedi. Tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _showDevCode(String code) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🛠 Geliştirici Modu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Resend API anahtarı girilmediği için kod e-posta yerine burada gösteriliyor.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Text(
              code,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                letterSpacing: 8,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Kodu otomatik doldur
              for (var i = 0; i < 6; i++) {
                _controllers[i].text = code[i];
              }
              setState(() {});
            },
            child: const Text('Kodu Doldur'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(otpPendingProvider);
    final email = pending?.email ?? '';
    final expired = _secondsLeft <= 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            ref.read(otpPendingProvider.notifier).state = null;
            context.go(AppRoutes.login);
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.mark_email_read_outlined,
                    size: 38, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              const Text(
                'E-posta Doğrulama',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                OtpEmailService.isDevMode
                    ? 'Geliştirici modu: Kodu almak için "Yeni Kod Gönder" butonuna basın.'
                    : '$email adresine 6 haneli doğrulama kodu gönderildi.',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                textAlign: TextAlign.center,
              ),
              if (OtpEmailService.isDevMode) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.developer_mode,
                          size: 14, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Text(
                        'Geliştirici Modu',
                        style: TextStyle(
                            fontSize: 12, color: Colors.orange.shade700),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),

              // ── OTP Kutuları ──────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) => _buildBox(i)),
              ),

              const SizedBox(height: 20),

              // ── Hata mesajı ───────────────────────────────────────────
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMessage!,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.error)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Geri sayım ────────────────────────────────────────────
              if (!expired) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timer_outlined,
                        size: 16,
                        color: _secondsLeft < 60
                            ? AppColors.error
                            : AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Kod $_timeLabel sonra geçersiz',
                      style: TextStyle(
                        fontSize: 13,
                        color: _secondsLeft < 60
                            ? AppColors.error
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ] else ...[
                const SizedBox(height: 24),
              ],

              // ── Doğrula butonu ────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_isVerifying || expired) ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Doğrula ve Kayıt Ol',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Tekrar gönder ─────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 46,
                child: TextButton(
                  onPressed: _isResending ? null : _resend,
                  child: _isResending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Yeni Kod Gönder',
                          style: TextStyle(color: AppColors.primary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBox(int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: SizedBox(
        width: 46,
        height: 56,
        child: RawKeyboardListener(
          focusNode: FocusNode(),
          onKey: (e) => _onKeyEvent(index, e),
          child: TextFormField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: index == 0 ? 6 : 1, // İlk kutuya yapıştırma için 6
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: _controllers[index].text.isEmpty
                      ? AppColors.border
                      : AppColors.primary,
                  width: _controllers[index].text.isEmpty ? 1.5 : 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 2),
              ),
              filled: true,
              fillColor: _controllers[index].text.isNotEmpty
                  ? AppColors.primarySurface
                  : AppColors.surface,
            ),
            onChanged: (v) {
              setState(() {});
              _onDigitEntered(index, v);
            },
          ),
        ),
      ),
    );
  }
}
