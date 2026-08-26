import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/otp_email_service.dart';
import '../../../../shared/widgets/app_button.dart';
import '../providers/auth_provider.dart';

// ── Şifre doğrulama kuralları (merkezi) ───────────────────────────────────────
String? validatePassword(String? v) {
  if (v == null || v.isEmpty) return 'Şifre gerekli';
  if (v.length < 6) return 'En az 6 karakter olmalı';
  if (!v.contains(RegExp(r'[A-Z]'))) return 'En az bir büyük harf içermeli';
  if (!v.contains(RegExp(r'[0-9]'))) return 'En az bir rakam içermeli';
  return null;
}

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _registerNameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerPasswordConfirmController = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  bool _obscureRegisterPassword = true;
  bool _obscureRegisterConfirm = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() => _errorMessage = null));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _registerNameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerPasswordConfirmController.dispose();
    super.dispose();
  }

  // ── Giriş Yap ─────────────────────────────────────────────────────────────
  Future<void> _login() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await ref
          .read(authRepositoryProvider)
          .signInWithEmailChecked(_emailController.text, _passwordController.text);
      if (mounted) context.go(AppRoutes.dashboard);
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage =
          ref.read(authRepositoryProvider).mapError(e));
    } catch (_) {
      setState(() => _errorMessage = 'Bir hata oluştu. Tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Kayıt Ol → OTP akışı ──────────────────────────────────────────────────
  Future<void> _register() async {
    if (!_registerFormKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final code = OtpEmailService.generateOtp();
      final email = _registerEmailController.text.trim();
      final name = _registerNameController.text.trim();

      final sent = await OtpEmailService.sendOtp(
        toEmail: email,
        toName: name,
        otpCode: code,
      );
      if (!sent) throw Exception('E-posta gönderilemedi: ${OtpEmailService.lastError}');

      // OTP verisini Riverpod state'ine kaydet
      ref.read(otpPendingProvider.notifier).state = OtpPendingData(
        email: email,
        name: name,
        password: _registerPasswordController.text,
        code: code,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      );

      if (!mounted) return;

      // Geliştirici modunda kodu dialog ile göster
      if (OtpEmailService.isDevMode) {
        await showDialog(
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
                const SizedBox(height: 8),
                const Text(
                  'Sonraki ekranda bu kodu girin.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tamam'),
              ),
            ],
          ),
        );
      }

      if (mounted) context.go(AppRoutes.registerOtp);
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage =
          ref.read(authRepositoryProvider).mapError(e));
    } catch (e) {
      setState(() => _errorMessage = e.toString()
          .replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Google ile giriş/kayıt ─────────────────────────────────────────────────
  Future<void> _loginWithGoogle() async {
    setState(() { _isGoogleLoading = true; _errorMessage = null; });
    try {
      final user = await ref.read(authRepositoryProvider).signInWithGoogle();
      if (user != null && mounted) context.go(AppRoutes.dashboard);
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage =
          ref.read(authRepositoryProvider).mapError(e));
    } catch (_) {
      setState(() => _errorMessage = 'Google ile giriş başarısız.');
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isLoginTab = _tabController.index == 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.agriculture_rounded,
                    size: 40, color: AppColors.white),
              ),
              const SizedBox(height: 32),
              const Text(
                'Çiftlik Yönetim',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),

              // ── Tab Bar ──────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: AppColors.white,
                  unselectedLabelColor: AppColors.textSecondary,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Giriş Yap'),
                    Tab(text: 'Kayıt Ol'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Hata banner ──────────────────────────────────────────
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

              // ── Tab içerikleri ───────────────────────────────────────
              SizedBox(
                height: 480,
                child: TabBarView(
                  controller: _tabController,
                  children: [_buildLoginForm(), _buildRegisterForm()],
                ),
              ),
              const SizedBox(height: 16),

              // ── Ayraç ────────────────────────────────────────────────
              Row(children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('veya',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ),
                const Expanded(child: Divider()),
              ]),
              const SizedBox(height: 16),

              // ── Google butonu — tab'a göre label değişir ─────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _isGoogleLoading ? null : _loginWithGoogle,
                  icon: _isGoogleLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Image.asset(
                          'assets/icons/google_logo.png',
                          width: 20,
                          height: 20,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.g_mobiledata_rounded, size: 24),
                        ),
                  label: Text(isLoginTab
                      ? 'Google ile Giriş Yap'
                      : 'Google ile Kayıt Ol'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Giriş Yap Formu ───────────────────────────────────────────────────────
  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'E-posta',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'E-posta gerekli';
              if (!v.contains('@')) return 'Geçerli e-posta girin';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _login(),
            decoration: InputDecoration(
              labelText: 'Şifre',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: GestureDetector(
                onTap: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                child: Icon(_obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Şifre gerekli';
              return null;
            },
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Giriş Yap',
            onPressed: _login,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  // ── Kayıt Ol Formu ────────────────────────────────────────────────────────
  Widget _buildRegisterForm() {
    return Form(
      key: _registerFormKey,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            TextFormField(
              controller: _registerNameController,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Ad Soyad',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ad soyad gerekli';
                if (v.trim().length < 2) return 'En az 2 karakter';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _registerEmailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'E-posta',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'E-posta gerekli';
                if (!v.contains('@') || !v.contains('.')) {
                  return 'Geçerli e-posta girin';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _registerPasswordController,
              obscureText: _obscureRegisterPassword,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Şifre',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: GestureDetector(
                  onTap: () => setState(() =>
                      _obscureRegisterPassword = !_obscureRegisterPassword),
                  child: Icon(_obscureRegisterPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                ),
                helperText: 'En az 6 karakter, 1 büyük harf ve 1 rakam',
                helperMaxLines: 2,
              ),
              validator: validatePassword,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _registerPasswordConfirmController,
              obscureText: _obscureRegisterConfirm,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _register(),
              decoration: InputDecoration(
                labelText: 'Şifre Tekrar',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: GestureDetector(
                  onTap: () => setState(() =>
                      _obscureRegisterConfirm = !_obscureRegisterConfirm),
                  child: Icon(_obscureRegisterConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Şifreyi tekrar girin';
                if (v != _registerPasswordController.text) {
                  return 'Şifreler eşleşmiyor';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Doğrulama Kodu Gönder',
              onPressed: _register,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
}
