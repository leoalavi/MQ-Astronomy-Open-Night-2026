import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:aon2026/models/viewer_url_policy.dart';

/// Builds + starts the real localhost server. Constructs `InAppLocalhostServer`
/// only when CALLED (never at import) — keeping the module import-safe in tests.
Future<void> _defaultStart() =>
    InAppLocalhostServer(documentRoot: 'assets', port: kPanoramaServerPort).start();

/// Single, process-lifetime owner of the localhost asset server serving the
/// bundled viewer + panoramas. Never closed between routes. Start is idempotent
/// (runs at most once) and retryable (a failure clears the memo). [start] is
/// injectable for unit tests; the default builds + starts the real server.
class PanoramaServer {
  PanoramaServer({Future<void> Function()? start}) : _start = start ?? _defaultStart;
  final Future<void> Function() _start;
  Future<void>? _starting;
  bool _running = false;

  String get baseUrl => 'http://localhost:$kPanoramaServerPort';
  bool get isRunning => _running;

  Future<void> ensureStarted() {
    if (kIsWeb) return Future.value(); // web serves assets same-origin; no server
    if (_running) return Future.value();
    // async closure + try/catch (NOT .then(...).catchError): a `.then` arrow
    // returning `_running = true` would type the future Future<bool> and break
    // the rethrow. This form is Future<void>, idempotent, and retryable.
    return _starting ??= () async {
      try {
        await _start();
        _running = true;
      } catch (_) {
        _starting = null; // retryable — do not permanently disable the session
        rethrow;
      }
    }();
  }
}

/// Import-safe: the constructor only stores the (default) start function; the
/// real server is built lazily inside `_defaultStart` on first non-web start.
final panoramaServer = PanoramaServer();
