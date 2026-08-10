import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'bundled viewer HTML is locally isolated (CSP present, no external origins)',
    () async {
      final html = await rootBundle.loadString('assets/web/indoor_viewer.html');
      expect(html, contains('Content-Security-Policy'));
      expect(html, contains("default-src 'none'"));
      expect(html, contains("connect-src 'self'"));
      expect(
        RegExp(r'https?://').hasMatch(html),
        isFalse,
        reason: 'viewer HTML must reference no external http(s) origin',
      );
    },
  );
}
