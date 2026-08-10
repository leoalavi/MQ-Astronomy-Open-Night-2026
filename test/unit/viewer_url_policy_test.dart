import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/models/viewer_url_policy.dart';

void main() {
  test(
    'main-frame policy: only about:blank and the exact viewer HTML path',
    () {
      expect(
        isAllowedViewerUrl(
          Uri.parse('http://localhost:8459/web/indoor_viewer.html'),
        ),
        isTrue,
      );
      expect(
        isAllowedViewerUrl(
          Uri.parse('http://localhost:8459/web/indoor_viewer.html?x=1#s'),
        ),
        isTrue,
      );
      expect(isAllowedViewerUrl(Uri.parse('about:blank')), isTrue);
    },
  );
  test('rejects everything else, by parsed parts not prefix', () {
    for (final u in [
      'http://localhost:8459/data/indoor/x.jpg',
      'http://localhost:8459/',
      'about:srcdoc',
      'https://localhost:8459/web/indoor_viewer.html',
      'http://localhost:8460/web/indoor_viewer.html',
      'http://localhost.evil.example/web/indoor_viewer.html',
      'http://127.0.0.1:8459/web/indoor_viewer.html',
      'http://localhost:8459@evil.com/web/indoor_viewer.html',
      'file:///etc/passwd',
      'data:text/html,x',
      'javascript:alert(1)',
    ]) {
      expect(isAllowedViewerUrl(Uri.parse(u)), isFalse, reason: u);
    }
    expect(isAllowedViewerUrl(null), isFalse);
  });
}
