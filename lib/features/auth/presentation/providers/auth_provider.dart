import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/entities/app_user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authStateProvider).value;
});

final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider)?.uid;
});

// ── OTP kayıt akışı için geçici durum ────────────────────────────────────────

class OtpPendingData {
  final String email;
  final String name;
  final String password;
  final String code;
  final DateTime expiresAt;

  OtpPendingData({
    required this.email,
    required this.name,
    required this.password,
    required this.code,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

final otpPendingProvider = StateProvider<OtpPendingData?>((ref) => null);
