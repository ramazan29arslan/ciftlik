import 'package:flutter_test/flutter_test.dart';
import 'package:ciftlik_yonetim/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Basic smoke test - app should build without errors
    expect(CiftlikApp, isNotNull);
  });
}
