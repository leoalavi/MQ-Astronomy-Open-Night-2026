import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/services/panorama_server.dart';
import 'package:aon2026/models/viewer_url_policy.dart';

void main() {
  test('import-safe: baseUrl works without constructing the real server', () {
    expect(panoramaServer.baseUrl, 'http://localhost:$kPanoramaServerPort');
    expect(panoramaServer.isRunning, isFalse);
  });

  test(
    'idempotent: real start runs once across many/concurrent calls',
    () async {
      var starts = 0;
      final s = PanoramaServer(start: () async => starts++);
      await Future.wait([
        s.ensureStarted(),
        s.ensureStarted(),
        s.ensureStarted(),
      ]);
      await s.ensureStarted();
      expect(starts, 1);
      expect(s.isRunning, isTrue);
    },
  );

  test(
    'retryable: a failed start clears the memo so a later call retries',
    () async {
      var starts = 0;
      final s = PanoramaServer(
        start: () async {
          starts++;
          if (starts == 1) throw StateError('boom');
        },
      );
      await s.ensureStarted().catchError((_) {});
      expect(s.isRunning, isFalse);
      await s.ensureStarted();
      expect(starts, 2);
      expect(s.isRunning, isTrue);
    },
  );
}
