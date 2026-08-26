import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../domain/entities/app_user.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<AppUser?> get authStateChanges =>
      _auth.authStateChanges().map((u) => u != null ? AppUser.fromFirebase(u) : null);

  AppUser? get currentUser {
    final u = _auth.currentUser;
    return u != null ? AppUser.fromFirebase(u) : null;
  }

  Future<AppUser> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return AppUser.fromFirebase(cred.user!);
  }

  Future<AppUser> signUpWithEmail(
    String email,
    String password, {
    String? displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (displayName != null && displayName.trim().isNotEmpty) {
      await cred.user!.updateDisplayName(displayName.trim());
    }
    // Brevo OTP doğrulaması yapıldığı için Firebase email doğrulaması gönderilmiyor
    return AppUser.fromFirebase(cred.user!);
  }

  Future<AppUser?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final cred = await _auth.signInWithCredential(credential);
    return AppUser.fromFirebase(cred.user!);
  }

  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Kullanıcının hesap durumunu Firestore'dan kontrol et
  Future<String?> getUserAccountStatus(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return doc.data()?['accountStatus'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Kullanıcı hesabını dondur — Firestore'a yaz ve çıkış yap
  Future<void> freezeAccount(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'accountStatus': 'frozen',
      'frozenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await signOut();
  }

  /// Donmuş hesabı aktif et (login sırasında çağrılır)
  Future<void> reactivateAccount(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'accountStatus': 'active',
      'frozenAt': null,
      'reactivatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Login sırasında dondurulmuş hesap kontrolü
  Future<AppUser> signInWithEmailChecked(String email, String password) async {
    final user = await signInWithEmail(email, password);
    final status = await getUserAccountStatus(user.uid);
    if (status == 'frozen') {
      // Donmuş hesap → otomatik aktifleştir (kullanıcı tekrar giriş yaptı)
      await reactivateAccount(user.uid);
    }
    return user;
  }

  String mapError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-posta veya şifre hatalı';
      case 'email-already-in-use':
        return 'Bu e-posta zaten kayıtlı';
      case 'weak-password':
        return 'Şifre en az 6 karakter olmalı';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi';
      case 'too-many-requests':
        return 'Çok fazla deneme. Lütfen bekleyin';
      case 'user-disabled':
        return 'Hesabınız dondurulmuş veya silinmiştir. Destek için iletişime geçin.';
      case 'network-request-failed':
        return 'İnternet bağlantısı yok';
      default:
        return 'Bir hata oluştu. Tekrar deneyin';
    }
  }
}
