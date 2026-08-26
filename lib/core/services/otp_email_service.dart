import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class OtpEmailService {
  // Brevo API anahtarı derleme sırasında verilir:
  //   flutter run --dart-define=BREVO_API_KEY=xkeysib-...
  static const String _apiKey = String.fromEnvironment('BREVO_API_KEY');
  static const String _fromEmail = 'yonetimciftlik@gmail.com';
  static const String _fromName = 'Çiftlik Yönetimi';

  static bool get isDevMode => false;

  static String generateOtp() {
    final rng = Random.secure();
    return (100000 + rng.nextInt(900000)).toString();
  }

  // Son hata mesajı (debug için)
  static String lastError = '';

  static Future<bool> sendOtp({
    required String toEmail,
    required String toName,
    required String otpCode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.brevo.com/v3/smtp/email'),
        headers: {
          'api-key': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'sender': {'name': _fromName, 'email': _fromEmail},
          'to': [{'email': toEmail, 'name': toName}],
          'subject': 'Kayıt Doğrulama Kodunuz',
          'htmlContent': _buildHtml(toName: toName, otpCode: otpCode),
        }),
      );
      lastError = 'HTTP ${response.statusCode}: ${response.body}';
      return response.statusCode == 201;
    } catch (e) {
      lastError = e.toString();
      return false;
    }
  }

  static String _buildHtml({required String toName, required String otpCode}) => '''
<!DOCTYPE html>
<html>
<body style="font-family:Arial,sans-serif;background:#f5f5f5;margin:0;padding:20px;">
  <div style="max-width:420px;margin:0 auto;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,.08);">
    <div style="background:#2E7D32;padding:24px;text-align:center;">
      <h2 style="color:#fff;margin:0;font-size:22px;">🌾 Çiftlik Yönetim</h2>
    </div>
    <div style="padding:32px 28px;">
      <p style="margin:0 0 8px;color:#333;font-size:15px;">Merhaba <strong>$toName</strong>,</p>
      <p style="color:#555;font-size:14px;line-height:1.6;">
        Hesabınızı doğrulamak için aşağıdaki 6 haneli kodu girin.
      </p>
      <div style="background:#E8F5E9;border-radius:12px;padding:28px;text-align:center;margin:24px 0;">
        <span style="font-size:42px;font-weight:700;letter-spacing:10px;color:#1B5E20;font-family:monospace;">
          $otpCode
        </span>
      </div>
      <p style="color:#888;font-size:12px;margin:0;">
        ⏱ Bu kod <strong>10 dakika</strong> geçerlidir.<br>
        🔒 Kodu kimseyle paylaşmayın.
      </p>
    </div>
  </div>
</body>
</html>
''';
}
